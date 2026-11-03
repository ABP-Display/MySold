import 'package:flutter/material.dart';
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
import 'package:mysold/widgets/stats_year_picker.dart';
import 'package:mysold/models/stats_year.dart';
import 'package:mysold/widgets/analytics/monthly_analytics_sections.dart';
import 'package:mysold/widgets/analytics/monthly_analysis_chart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with WidgetsBindingObserver {
  int _year = DateTime.now().year, _calendarYear = DateTime.now().year;
  final _cache = <int, Future<_MonthlySource>>{};
  bool _sameDay = true;
  int? _financialVersion;
  _MonthlySource? _derivedSource;
  StatsYear? _derived;
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
    final current = now.year;
    setState(() {
      if (_year == _calendarYear) _year = current;
      _calendarYear = current;
      _cache.clear();
      _derived = null;
    });
  }

  Future<_MonthlySource> _load(int year) {
    return _cache.putIfAbsent(year, () async {
      final uid = LocalAuth.instance.currentUser?.uid;
      if (uid == null) return const _MonthlySource([]);
      // One indexed query for the selected year plus December needed by January M-1.
      final query = DocumentStore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              year == 1 ? DateTime(1) : DateTime(year - 1, 12),
            ),
          )
          .where('date', isLessThan: Timestamp.fromDate(DateTime(year + 1)))
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

  void _selectYear(int value) {
    final year = value.clamp(1, 9998);
    if (year == _year) return;
    setState(() {
      _year = year;
      _derived = null;
      if (_cache.length >= 3 && !_cache.containsKey(year))
        _cache.remove(_cache.keys.first);
    });
  }

  Future<void> _chooseYear() async {
    final value = await chooseStatsYear(context, _year);
    if (mounted && value != null) _selectYear(value);
  }

  Future<void> _refresh() async {
    DocumentStore.instance.clear();
    setState(() {
      _cache.clear();
      _derived = null;
    });
    await _load(_year);
  }

  StatsYear _derive(_MonthlySource source) {
    final now = DateTime.now();
    final day = '${now.year}-${now.month}-${now.day}';
    if (_derived == null ||
        !identical(source, _derivedSource) ||
        _derivedDay != day) {
      _derived = StatsYear.build(
        year: _year,
        now: now,
        transactions: source.transactions,
        sameDay: _sameDay,
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
    Widget header() => MonthPageHeader(
      title: context.tr('Stats mensuelles'),
      eyebrow: context.tr('ANALYSE'),
      subtitle: context.tr('Tous les mois de votre année, comparés à M−1.'),
      monthLabel: '$_year',
      compactMonthLabel: '$_year',
      previousLabel: context.tr('Année précédente'),
      nextLabel: context.tr('Année suivante'),
      onPrevious: () => _selectYear(_year - 1),
      onNext: () => _selectYear(_year + 1),
      onChoose: _chooseYear,
    );
    return FutureBuilder<_MonthlySource>(
      future: _load(_year),
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
              title: 'Année à venir',
              icon: Icons.event_outlined,
              child: Text(context.tr('Cette année n’a pas encore commencé.')),
            )
          else ...[
            (_) => MonthlyOverview(
              data: data.projection,
              totals: data.totals,
              currency: currency,
              hidden: privacy.hideAmounts,
            ),
            (_) => MonthlyProjection(
              data: data.projection,
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
