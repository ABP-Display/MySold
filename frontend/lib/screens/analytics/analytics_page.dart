import 'package:mysold/widgets/active_page_builder.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/data/bounded_async_cache.dart';
import 'package:mysold/widgets/page_pending_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/models/month_comparison.dart';
import 'package:mysold/models/transaction_model.dart';
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
  final VoidCallback? onInitialLoad;
  const AnalyticsPage({super.key, this.onInitialLoad});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with WidgetsBindingObserver {
  DateTime _selected = _month(DateTime.now()),
      _calendar = _month(DateTime.now());
  late DateTime _reference = _prior(_selected);
  final _cache = BoundedAsyncCache<DateTime, _MonthSource>(capacity: 6);
  Future<List<_MonthSource>>? _pair;
  bool _followPrevious = true;
  // Keep chart preferences while a newly selected month is loading.
  MonthlySeries _series = MonthlySeries.expense;
  bool _cumulative = true;
  int? _financialVersion;
  bool _initialLoadNotified = false;

  void _notifyInitialLoad() {
    if (_initialLoadNotified) return;
    _initialLoadNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onInitialLoad?.call();
    });
  }

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
      if (_calendar != current) _pair = null;
      _calendar = current;
    });
  }

  Future<_MonthSource> _load(DateTime month) {
    return _cache.load(month, () async {
      final transactions = await context
          .read<UserDataProvider>()
          .getMonthTransactions(month);
      return _MonthSource.fromTransactions(month, transactions);
    });
  }

  _MonthSource? _readySource(DateTime month) {
    final ready = _cache.peek(month);
    if (ready != null) return ready;
    final transactions = context
        .read<UserDataProvider>()
        .cachedMonthTransactions(month);
    if (transactions == null) return null;
    final source = _MonthSource.fromTransactions(month, transactions);
    _cache.store(month, source);
    return source;
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
    context.read<UserDataProvider>().markFinancialDataChanged();
    setState(() {
      _cache.clear();
      _pair = null;
    });
    await _sources();
  }

  @override
  Widget build(BuildContext context) => ActivePageBuilder(builder: _buildPage);

  Widget _buildPage(BuildContext context) {
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
    final selected = _readySource(_selected),
        reference = _readySource(_reference);
    return FutureBuilder<List<_MonthSource>>(
      key: ValueKey((_selected, _reference)),
      initialData: selected != null && reference != null
          ? [selected, reference]
          : null,
      future: _sources(),
      builder: (context, snapshot) {
        if (snapshot.hasData || snapshot.hasError) _notifyInitialLoad();
        if (!snapshot.hasData) {
          if (!snapshot.hasError) return PagePendingContent(header: header());
          return ListView(
            dragStartBehavior: DragStartBehavior.down,
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + WorkspaceOverlayInsets.bottomOf(context),
            ),
            children: [
              header(),
              if (snapshot.hasError) ...[
                Text(context.tr('Impossible de charger les statistiques.')),
                FilledButton(
                  onPressed: _refresh,
                  child: Text(context.tr('Réessayer')),
                ),
              ],
            ],
          );
        }
        final now = DateTime.now(),
            first = snapshot.data![0].derive(now),
            second = snapshot.data![1].derive(now);
        final comparison = MonthComparison(first, second);
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
            initialSeries: _series,
            initialCumulative: _cumulative,
            onSeriesChanged: (value) => _series = value,
            onCumulativeChanged: (value) => _cumulative = value,
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
  factory _MonthSource.fromTransactions(
    DateTime month,
    List<TransactionModel> transactions,
  ) => _MonthSource(
    month,
    transactions
        .map(
          (transaction) => MonthlyOperation(
            id: transaction.id ?? '',
            type: transaction.type,
            amount: transaction.amount,
            date: transaction.date,
          ),
        )
        .toList(),
  );
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
