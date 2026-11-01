import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/widgets/lazy_section_list.dart';
import 'package:mysold/widgets/month_page_header.dart';
import 'package:mysold/widgets/month_year_picker.dart';
import 'package:mysold/widgets/analytics/monthly_analytics_sections.dart';
import 'package:mysold/widgets/analytics/monthly_analysis_chart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with WidgetsBindingObserver {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final _cache = <DateTime, Future<_MonthlySource>>{};
  bool _sameDay = true;
  int? _financialVersion;
  _MonthlySource? _derivedSource;
  MonthlyAnalytics? _derived;
  String? _derivedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    setState(() {
      if (_month == _calendarMonth) _month = current;
      _calendarMonth = current;
      _cache.clear();
      _derived = null;
    });
  }

  Future<_MonthlySource> _load(DateTime month) {
    return _cache.putIfAbsent(month, () async {
      final uid = LocalAuth.instance.currentUser?.uid;
      if (uid == null) return const _MonthlySource([]);
      // One bounded query, including M-1 even when it belongs to the prior year.
      final query = DocumentStore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime(month.year, month.month - 1),
            ),
          )
          .where(
            'date',
            isLessThan: Timestamp.fromDate(
              DateTime(month.year, month.month + 1),
            ),
          )
          .orderBy('date')
          .get();
      final snapshot = await query;
      return _MonthlySource(
        snapshot.docs.map((doc) {
          final data = doc.data();
          return MonthlyOperation(
            id: doc.id,
            type: data['type'] as String? ?? '',
            amount: (data['amount'] as num).toDouble(),
            date: (data['date'] as Timestamp).toDate(),
          );
        }).toList(),
      );
    });
  }

  void _selectMonth(DateTime value) {
    final month = DateTime(value.year, value.month);
    if (month == _month) return;
    setState(() {
      _month = month;
      _derived = null;
      if (_cache.length >= 6 && !_cache.containsKey(month))
        _cache.remove(_cache.keys.first);
    });
  }

  Future<void> _chooseMonth() async {
    final value = await showMonthYearPicker(context, _month);
    if (mounted && value != null) _selectMonth(value);
  }

  Future<void> _refresh() async {
    DocumentStore.instance.clear();
    setState(() {
      _cache.clear();
      _derived = null;
    });
    await _load(_month);
  }

  MonthlyAnalytics _derive(_MonthlySource source) {
    final now = DateTime.now();
    final day = '${now.year}-${now.month}-${now.day}';
    if (_derived == null ||
        !identical(source, _derivedSource) ||
        _derivedDay != day) {
      _derived = MonthlyAnalytics.build(
        month: _month,
        now: now,
        transactions: source.transactions,
        sameDayComparison: _sameDay,
      );
      _derivedSource = source;
      _derivedDay = day;
    }
    return _derived!;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserDataProvider>();
    final privacy = context.watch<PrivacyProvider>();
    final currency = context.watch<CurrencyProvider>().currency;
    if (_financialVersion != user.financialDataVersion) {
      _financialVersion = user.financialDataVersion;
      _cache.clear();
      _derived = null;
    }
    final locale = Localizations.localeOf(context).toString();
    Widget header() => MonthPageHeader(
      title: context.tr('Stats mensuelles'),
      eyebrow: context.tr('ANALYSE'),
      subtitle: context.tr('Votre mois, comparé et expliqué.'),
      monthLabel: DateFormat.yMMMM(locale).format(_month),
      compactMonthLabel: DateFormat.yMMM(locale).format(_month),
      previousLabel: context.tr('Mois précédent'),
      nextLabel: context.tr('Mois suivant'),
      onPrevious: () => _selectMonth(DateTime(_month.year, _month.month - 1)),
      onNext: () => _selectMonth(DateTime(_month.year, _month.month + 1)),
      onChoose: _chooseMonth,
    );
    return FutureBuilder<_MonthlySource>(
      future: _load(_month),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData)
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              header(),
              if (snapshot.hasError) ...[
                Text('${context.tr('Erreur')} : ${snapshot.error}'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _refresh,
                  child: Text(context.tr('Réessayer')),
                ),
              ] else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        final data = _derive(snapshot.data!);
        final sections = <WidgetBuilder>[
          (_) => header(),
          if (data.isFuture)
            (_) => MonthlyStatsPanel(
              title: 'Mois à venir',
              icon: Icons.event_outlined,
              child: Text(
                context.tr(
                  'Les statistiques seront disponibles lorsque ce mois aura commencé.',
                ),
              ),
            )
          else ...[
            (_) => MonthlyOverview(
              data: data,
              currency: currency,
              hidden: privacy.hideAmounts,
            ),
            (_) => MonthlyProjection(
              data: data,
              currency: currency,
              hidden: privacy.hideAmounts,
            ),
            (_) => MonthlyAnalysisChart(
              data: data,
              currency: currency,
              hidden: privacy.hideAmounts,
              onSameDay: (value) => setState(() {
                _sameDay = value;
                _derived = null;
              }),
            ),
          ],
        ];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: LazySectionList(
            gaps: List.filled(sections.length - 1, 16),
            sections: sections,
          ),
        );
      },
    );
  }
}

class _MonthlySource {
  final List<MonthlyOperation> transactions;
  const _MonthlySource(this.transactions);
}
