import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/models/month_comparison.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/widgets/lazy_section_list.dart';
import 'package:mysold/widgets/month_page_header.dart';
import 'package:mysold/widgets/month_year_picker.dart';
import 'package:mysold/widgets/analytics/monthly_analytics_sections.dart';
import 'package:mysold/widgets/analytics/monthly_analysis_chart.dart';

DateTime _month(DateTime value) => DateTime(value.year, value.month);

DateTime _prior(DateTime value) => value.year == 1 && value.month == 1
    ? value
    : DateTime(value.year, value.month - 1);

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with WidgetsBindingObserver {
  DateTime _selected = _month(DateTime.now()),
      _calendar = _month(DateTime.now());
  late DateTime _reference = _prior(_selected);
  final _cache = <DateTime, Future<_MonthSource>>{};
  Future<List<_MonthSource>>? _pair;
  bool _sameDay = true, _followPrevious = true;
  // Keep chart preferences while a newly selected month is loading.
  MonthlySeries _series = MonthlySeries.expense;
  bool _cumulative = true;
  int? _financialVersion;

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
    final current = _month(DateTime.now());
    setState(() {
      if (_selected == _calendar) {
        _selected = current;
        if (_followPrevious) _reference = _prior(current);
      }
      _calendar = current;
      _cache.clear();
      _pair = null;
    });
  }

  Future<_MonthSource> _load(DateTime month) {
    final cached = _cache[month];
    if (cached != null) return cached;
    if (_cache.length >= 6) _cache.remove(_cache.keys.first);
    return _cache[month] = () async {
      final uid = LocalAuth.instance.currentUser?.uid;
      if (uid == null) return _MonthSource(month, const []);
      final snapshot = await DocumentStore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(month))
          .where(
            'date',
            isLessThan: Timestamp.fromDate(
              DateTime(month.year, month.month + 1),
            ),
          )
          .orderBy('date')
          .get();
      return _MonthSource(
        month,
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
    }();
  }

  Future<List<_MonthSource>> _sources() =>
      _pair ??= Future.wait([_load(_selected), _load(_reference)]);
  void _selectMonth(DateTime value) {
    final month = _month(value);
    if (month.year < 1 || month.year > 9998 || month == _selected) return;
    setState(() {
      _selected = month;
      if (_followPrevious) _reference = _prior(month);
      _pair = null;
    });
  }

  Future<void> _chooseMonth({bool reference = false}) async {
    final value = await showMonthYearPicker(
      context,
      reference ? _reference : _selected,
    );
    if (!mounted || value == null || value.year > 9998) return;
    if (!reference) {
      _selectMonth(value);
      return;
    }
    if (_reference == value) return;
    setState(() {
      _reference = _month(value);
      _followPrevious = false;
      _pair = null;
    });
  }

  void _previousMonth() => setState(() {
    _reference = _prior(_selected);
    _followPrevious = true;
    _pair = null;
  });
  Future<void> _refresh() async {
    DocumentStore.instance.clear();
    setState(() {
      _cache.clear();
      _pair = null;
    });
    await _sources();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserDataProvider>();
    final hidden = context.watch<PrivacyProvider>().hideAmounts;
    final currency = context.watch<CurrencyProvider>().currency;
    final locale = Localizations.localeOf(context).toString();
    if (_financialVersion != user.financialDataVersion) {
      _financialVersion = user.financialDataVersion;
      _cache.clear();
      _pair = null;
    }
    Widget header() => MonthPageHeader(
      title: context.tr('Stats mensuelles'),
      eyebrow: context.tr('ANALYSE'),
      subtitle: context.tr('Votre mois, résumé et comparé.'),
      monthLabel: DateFormat.yMMMM(locale).format(_selected),
      compactMonthLabel: DateFormat.yMMM(locale).format(_selected),
      previousLabel: context.tr('Mois précédent'),
      nextLabel: context.tr('Mois suivant'),
      onPrevious: () => _selectMonth(_prior(_selected)),
      onNext: () => _selectMonth(DateTime(_selected.year, _selected.month + 1)),
      onChoose: () => _chooseMonth(),
    );
    return FutureBuilder<List<_MonthSource>>(
      future: _sources(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              header(),
              if (snapshot.hasError) ...[
                Text(context.tr('Impossible de charger les statistiques.')),
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
        }
        final now = DateTime.now(),
            first = snapshot.data![0].derive(now),
            second = snapshot.data![1].derive(now);
        final comparison = MonthComparison(first, second, sameDay: _sameDay);
        final sections = <WidgetBuilder>[
          (_) => header(),
          (_) =>
              MonthlyOverview(data: first, currency: currency, hidden: hidden),
          (_) => MonthlyProjection(
            data: first,
            currency: currency,
            hidden: hidden,
          ),
          (_) => MonthlyAnalysisChart(
            data: comparison,
            currency: currency,
            hidden: hidden,
            onSameDay: (value) => setState(() => _sameDay = value),
            initialSeries: _series,
            initialCumulative: _cumulative,
            onSeriesChanged: (value) => _series = value,
            onCumulativeChanged: (value) => _cumulative = value,
            onChooseMonth: () => _chooseMonth(),
            onChooseReference: () => _chooseMonth(reference: true),
            onResetReference: _followPrevious ? null : _previousMonth,
          ),
        ];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: LazySectionList(gaps: const [16, 16, 16], sections: sections),
        );
      },
    );
  }
}

class _MonthSource {
  final DateTime month;
  final List<MonthlyOperation> transactions;
  MonthlyAnalytics? _data;
  DateTime? _day;
  _MonthSource(this.month, this.transactions);
  MonthlyAnalytics derive(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    if (_data == null || _day != day) {
      _data = MonthlyAnalytics.build(
        month: month,
        now: now,
        transactions: transactions,
      );
      _day = day;
    }
    return _data!;
  }
}
