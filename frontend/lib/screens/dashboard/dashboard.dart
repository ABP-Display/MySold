import 'package:mysold/widgets/graphiques/chart_info_region.dart';
import 'package:mysold/widgets/graphiques/viewport_bar_chart.dart';
import 'package:mysold/widgets/app_design.dart';
import 'dart:math' as math;

import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:mysold/services/budget_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Map<int, Future<_AnnualDashboardData>> _yearCache = {};
  int _selectedYear = DateTime.now().year;
  bool _accountsExpanded = false;
  int _visibleAccountCount = 5;
  int? _lastFinancialDataVersion;
  int? _lastReferenceDataVersion;
  final Set<_MonthlyChartSeries> _monthlyChartSeries = {
    ..._MonthlyChartSeries.values,
  };
  final ScrollController _monthlyChartScrollController = ScrollController();
  int? _monthlyChartAutoScrolledYear;

  @override
  void dispose() {
    _monthlyChartScrollController.dispose();
    super.dispose();
  }

  Future<_AnnualDashboardData> _loadYearData(int year) {
    return _yearCache.putIfAbsent(year, () => _fetchYearData(year));
  }

  Future<_AnnualDashboardData> _fetchYearData(int year) async {
    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return _AnnualDashboardData.empty(year);

    final service = BudgetService(userId: uid);
    final userDoc = DocumentStore.instance.collection('users').doc(uid);

    final accountFuture = userDoc.collection('accounts').get();
    final categoriesFuture = context.read<UserDataProvider>().getCategories();
    final transactionsFuture = service.getTransactionsForYear(year);

    final accountSnapshot = await accountFuture;
    final categories = await categoriesFuture;
    final transactions = await transactionsFuture;

    final accounts = accountSnapshot.docs.map((doc) {
      final data = doc.data();
      return _AccountSummary(
        name: data['name'] ?? 'Compte',
        balance: (data['balance'] ?? 0).toDouble(),
      );
    }).toList()..sort((a, b) => b.balance.compareTo(a.balance));

    final monthlyIncome = List<double>.filled(12, 0);
    final monthlyExpense = List<double>.filled(12, 0);
    final monthlyInvestment = List<double>.filled(12, 0);
    final expenseByCategory = <String, double>{};

    for (final tx in transactions) {
      final monthIndex = tx.date.month - 1;
      if (monthIndex < 0 || monthIndex > 11) continue;

      if (tx.type == 'income') {
        monthlyIncome[monthIndex] += tx.amount;
      } else if (tx.type == 'expense') {
        monthlyExpense[monthIndex] += tx.amount;
        final categoryName = categories[tx.categoryId]?['name'] ?? 'Autre';
        expenseByCategory[categoryName] =
            (expenseByCategory[categoryName] ?? 0) + tx.amount;
      } else if (tx.type == 'investment') {
        monthlyInvestment[monthIndex] += tx.amount.abs();
      }
    }

    final incomeTotal = monthlyIncome.fold(0.0, (sum, value) => sum + value);
    final expenseTotal = monthlyExpense.fold(0.0, (sum, value) => sum + value);
    final investmentTotal = monthlyInvestment.fold(
      0.0,
      (sum, value) => sum + value,
    );
    final accountTotal = accounts.fold(0.0, (sum, account) {
      return sum + account.balance;
    });
    final wealthEvolution = _buildWealthEvolutionData(
      year: year,
      currentWealth: accountTotal,
      transactions: transactions,
    );

    return _AnnualDashboardData(
      year: year,
      accounts: accounts,
      incomeTotal: incomeTotal,
      expenseTotal: expenseTotal,
      investmentTotal: investmentTotal,
      accountTotal: accountTotal,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      monthlyInvestment: monthlyInvestment,
      expenseByCategory: expenseByCategory,
      actualWealthPoints: wealthEvolution.actualPoints,
      projectedWealthPoints: wealthEvolution.projectedPoints,
    );
  }

  void _changeYear(int delta) {
    setState(() => _selectedYear += delta);
  }

  Future<void> _refresh() async {
    setState(() {
      _yearCache.remove(_selectedYear);
    });
    await _loadYearData(_selectedYear);
  }

  String _money(double value, String currency, PrivacyProvider privacy) {
    return privacy.money(value, currency);
  }

  String _compactMoney(double value, String currency, PrivacyProvider privacy) {
    return privacy.compactMoney(value, currency);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>().currency;
    final privacy = context.watch<PrivacyProvider>();
    final userData = context.watch<UserDataProvider>();
    final financialDataVersion = userData.financialDataVersion;
    final referenceDataVersion = userData.referenceDataVersion;

    if (_lastFinancialDataVersion != financialDataVersion ||
        _lastReferenceDataVersion != referenceDataVersion) {
      _yearCache.clear();
      _lastFinancialDataVersion = financialDataVersion;
      _lastReferenceDataVersion = referenceDataVersion;
    }

    return FutureBuilder<_AnnualDashboardData>(
      future: _loadYearData(_selectedYear),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('${context.tr('Erreur')} : ${snapshot.error}'),
          );
        }

        final data = snapshot.data ?? _AnnualDashboardData.empty(_selectedYear);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            children: [
              PageIntro(
                eyebrow: context.tr('PATRIMOINE'),
                title: context.tr('Vue globale'),
                subtitle: context.tr(
                  'Une vue d’ensemble de vos comptes et de votre année.',
                ),
                action: Container(
                  decoration: AppDesign.panel(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.tr('Année précédente'),
                        onPressed: () => _changeYear(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        '$_selectedYear',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        tooltip: context.tr('Année suivante'),
                        onPressed: () => _changeYear(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ),
              _buildHeader(data, currency, privacy),
              const SizedBox(height: 16),
              _buildSummaryGrid(data, currency, privacy),
              const SizedBox(height: 18),
              _buildWealthEvolution(data, currency, privacy),
              const SizedBox(height: 18),
              _buildAccountsSection(data, currency, privacy),
              const SizedBox(height: 18),
              _buildMonthlyChart(data, currency, privacy),
              const SizedBox(height: 18),
              _buildExpenseCategories(data, currency, privacy),
              const SizedBox(height: 18),
              _buildQuickStats(data, currency, privacy),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    _AnnualDashboardData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Solde global des comptes'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _money(data.accountTotal, currency, privacy),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          _buildBalanceChip(data.annualBalance, currency, privacy),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(
    _AnnualDashboardData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    return AppMetricGrid(
      children: [
        AppMetricCard(
          icon: Icons.arrow_downward,
          label: context.tr('Revenus annuels'),
          value: _money(data.incomeTotal, currency, privacy),
          color: Colors.green,
        ),
        AppMetricCard(
          icon: Icons.arrow_upward,
          label: context.tr('Dépenses annuelles'),
          value: _money(data.expenseTotal, currency, privacy),
          color: Colors.redAccent,
        ),
        AppMetricCard(
          icon: Icons.trending_up_outlined,
          label: context.tr('Investissements annuels'),
          value: _money(data.investmentTotal, currency, privacy),
          color: Theme.of(context).colorScheme.primary,
        ),
        AppMetricCard(
          icon: Icons.ssid_chart,
          label: context.tr('Reste disponible'),
          value: _money(data.availableTotal, currency, privacy),
          color: _remainingColor(data.availableTotal, privacy),
        ),
      ],
    );
  }

  Widget _buildWealthEvolution(
    _AnnualDashboardData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    final actualSpots = data.actualWealthPoints
        .map((point) => FlSpot(point.x, point.value))
        .toList();
    final projectedSpots = data.projectedWealthPoints
        .map((point) => FlSpot(point.x, point.value))
        .toList();
    final allPoints = [
      ...data.actualWealthPoints,
      ...data.projectedWealthPoints,
    ];
    final axis = _WealthAxis.fromPoints(allPoints);
    final yearStart = DateTime(data.year, 1, 1);
    final yearEnd = DateTime(data.year, 12, 31);
    final maxX = yearEnd.difference(yearStart).inDays.toDouble();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actualColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.88);
    final projectedColor = isDark
        ? Colors.white.withOpacity(0.34)
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.42);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Évolution du patrimoine annuel',
            Icons.show_chart_rounded,
          ),
          const SizedBox(height: 14),
          if (privacy.hideAmounts)
            const PrivacyChartMask(height: 240)
          else ...[
            Row(
              children: [
                _LegendDot(color: actualColor, label: context.tr('Réel')),
                const SizedBox(width: 14),
                if (projectedSpots.length > 1)
                  _LegendDot(
                    color: projectedColor,
                    label: context.tr('Projection'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: axis.minY,
                  maxY: axis.maxY,
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.grey.shade800,
                      getTooltipItems: (items) {
                        return items.map((item) {
                          final date = yearStart.add(
                            Duration(days: item.x.round()),
                          );
                          return LineTooltipItem(
                            '${DateFormat('dd/MM').format(date)}\n${_money(item.y, currency, privacy)}',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _compactMoney(value, currency, privacy),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 61,
                        getTitlesWidget: (value, meta) {
                          final date = yearStart.add(
                            Duration(
                              days: value
                                  .round()
                                  .clamp(0, maxX.toInt())
                                  .toInt(),
                            ),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat(
                                'MMM',
                                Localizations.localeOf(context).toString(),
                              ).format(date),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: actualSpots,
                      isCurved: true,
                      barWidth: 3.4,
                      color: actualColor,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: actualColor.withOpacity(isDark ? 0.10 : 0.06),
                      ),
                    ),
                    if (projectedSpots.length > 1)
                      LineChartBarData(
                        spots: projectedSpots,
                        isCurved: true,
                        barWidth: 2.6,
                        color: projectedColor,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountsSection(
    _AnnualDashboardData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    final activeAccounts = data.accounts
        .where((account) => account.balance.abs() > 0.005)
        .toList();
    final accountsToDisplay = data.accounts
        .take(_visibleAccountCount)
        .toList(growable: false);
    final hasMoreAccounts = _visibleAccountCount < data.accounts.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                _accountsExpanded = !_accountsExpanded;
                if (!_accountsExpanded) _visibleAccountCount = 5;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('Comptes'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '${activeAccounts.length} ${context.tr('comptes actifs')}',
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.68),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _accountsExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (_accountsExpanded) const SizedBox(height: 12),
          if (data.accounts.isEmpty)
            Text(context.tr('Aucun compte disponible.'))
          else if (_accountsExpanded) ...[
            ...accountsToDisplay.map((account) {
              final share = data.accountTotal <= 0
                  ? 0.0
                  : (account.balance / data.accountTotal)
                        .clamp(0.0, 1.0)
                        .toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            account.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          _money(account.balance, currency, privacy),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: privacy.hideAmounts
                          ? 1
                          : share.isFinite
                          ? share
                          : 0,
                      minHeight: 6,
                      color: privacy.hideAmounts
                          ? Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.18)
                          : null,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              );
            }),
            if (hasMoreAccounts)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _visibleAccountCount = (_visibleAccountCount + 5)
                          .clamp(0, data.accounts.length)
                          .toInt();
                    });
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.tr('Afficher plus')),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _toggleMonthlyChartSeries(_MonthlyChartSeries series) {
    setState(() {
      if (_monthlyChartSeries.contains(series)) {
        _monthlyChartSeries.remove(series);
      } else {
        _monthlyChartSeries.add(series);
      }
    });
  }

  void _openMonthlyChartFilters(
    Map<_MonthlyChartSeries, _ChartSeriesStyle> seriesStyles,
  ) {
    showAppSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      context.tr('Afficher sur le graphique'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('Choisissez les catégories à afficher'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._MonthlyChartSeries.values.map((series) {
                      final style = seriesStyles[series]!;
                      final selected = _monthlyChartSeries.contains(series);
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected,
                        activeColor: style.color,
                        onChanged: (_) {
                          _toggleMonthlyChartSeries(series);
                          setModalState(() {});
                        },
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: style.color.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(style.icon, color: style.color, size: 18),
                        ),
                        title: Text(
                          context.tr(style.label),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonthlyChart(
    _AnnualDashboardData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    final remainingColor = _remainingChartColor();

    final seriesStyles = <_MonthlyChartSeries, _ChartSeriesStyle>{
      _MonthlyChartSeries.income: _ChartSeriesStyle(
        label: 'Revenus',
        icon: Icons.arrow_downward,
        color: Colors.green,
        values: data.monthlyIncome,
      ),
      _MonthlyChartSeries.expense: _ChartSeriesStyle(
        label: 'Depenses',
        icon: Icons.arrow_upward,
        color: Colors.redAccent,
        values: data.monthlyExpense,
      ),
      _MonthlyChartSeries.investment: _ChartSeriesStyle(
        label: 'Investissements',
        icon: Icons.trending_up_outlined,
        color: Theme.of(context).colorScheme.primary,
        values: data.monthlyInvestment,
      ),
      _MonthlyChartSeries.remaining: _ChartSeriesStyle(
        label: 'Reste',
        icon: Icons.ssid_chart,
        color: remainingColor,
        values: data.monthlyAvailable,
      ),
    };

    // Only the series selected via the filter toggles are rendered — 12
    // months x up to 4 series = up to 48 bars, driven entirely by the
    // current selection (all 4 selected by default).
    final activeSeries = _MonthlyChartSeries.values
        .where((series) => _monthlyChartSeries.contains(series))
        .toList(growable: false);

    final zeroLineColor = Theme.of(context).colorScheme.onSurface.withOpacity(
      Theme.of(context).brightness == Brightness.dark ? 0.24 : 0.18,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _sectionTitle(
                  'Revenus, dépenses, investissements et reste',
                  Icons.bar_chart_outlined,
                ),
              ),
              if (!privacy.hideAmounts)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openMonthlyChartFilters(seriesStyles),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (activeSeries.length < 4)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '${activeSeries.length}/4',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ),
                        Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: activeSeries.length < 4
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (privacy.hideAmounts)
            const PrivacyChartMask(height: 230)
          else if (activeSeries.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  context.tr('Sélectionnez au moins une catégorie'),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ),
            )
          else
            _buildMonthlyChartBody(
              data: data,
              currency: currency,
              privacy: privacy,
              activeSeries: activeSeries,
              seriesStyles: seriesStyles,
              zeroLineColor: zeroLineColor,
            ),
        ],
      ),
    );
  }

  Widget _buildFixedYAxis({
    required double minY,
    required double maxY,
    required double plotHeight,
    required double bottomAxisHeight,
    required String currency,
    required PrivacyProvider privacy,
  }) {
    final ticks = List.generate(5, (i) => maxY - i * (maxY - minY) / 4);
    return SizedBox(
      width: 46,
      child: Column(
        children: [
          SizedBox(
            height: plotHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: ticks.map((value) {
                return Text(
                  _compactMoney(value, currency, privacy),
                  style: const TextStyle(fontSize: 10),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: bottomAxisHeight),
        ],
      ),
    );
  }

  Widget _buildMonthlyChartBody({
    required _AnnualDashboardData data,
    required String currency,
    required PrivacyProvider privacy,
    required List<_MonthlyChartSeries> activeSeries,
    required Map<_MonthlyChartSeries, _ChartSeriesStyle> seriesStyles,
    required Color zeroLineColor,
  }) {
    final visibleValues = activeSeries.expand(
      (series) => seriesStyles[series]!.values,
    );
    final minValue = [...visibleValues, 0.0].reduce((a, b) => a < b ? a : b);
    final maxValue = [...visibleValues, 1.0].reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs();
    final axisPadding = range <= 1 ? 1.0 : range * 0.16;
    final minY = minValue < 0 ? minValue - axisPadding : 0.0;
    final maxY = maxValue + axisPadding;

    // Bar width and group width scale with how many series are active, so
    // a single selected category gets nice, wide, readable bars while all
    // four together stay compact but still legible (up to 48 bars total).
    final barCount = activeSeries.length;
    final barWidth = switch (barCount) {
      1 => 26.0,
      2 => 18.0,
      3 => 13.0,
      _ => 10.0,
    };
    final barsSpace = barCount > 1 ? 5.0 : 0.0;
    const groupPadding = 20.0;
    final groupWidth =
        (barWidth * barCount) + (barsSpace * (barCount - 1)) + groupPadding;
    const bottomAxisHeight = 28.0;
    final chartHeight = minY < 0 ? 280.0 : 250.0;
    final plotHeight = chartHeight - bottomAxisHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = (constraints.maxWidth - 50)
            .clamp(0.0, double.infinity)
            .toDouble();
        final chartWidth = math.max(groupWidth * 12, viewportWidth);

        // Land directly on the current month for the current year, so the
        // person never has to scroll to see e.g. September in September.
        if (data.year == DateTime.now().year &&
            _monthlyChartAutoScrolledYear != data.year) {
          _monthlyChartAutoScrolledYear = data.year;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_monthlyChartScrollController.hasClients) return;
            final currentMonthIndex = DateTime.now().month - 1;
            final position = _monthlyChartScrollController.position;
            final target =
                ((currentMonthIndex + 1) * groupWidth - viewportWidth + 12)
                    .clamp(0.0, position.maxScrollExtent)
                    .toDouble();
            _monthlyChartScrollController.animateTo(
              target,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            );
          });
        }

        return SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The Y axis stays fixed outside the horizontal scroll area.
              _buildFixedYAxis(
                minY: minY,
                maxY: maxY,
                plotHeight: plotHeight,
                bottomAxisHeight: bottomAxisHeight,
                currency: currency,
                privacy: privacy,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ViewportBarChart(
                  controller: _monthlyChartScrollController,
                  contentWidth: chartWidth,
                  info: (groupIndex, rodIndex) {
                    final series = activeSeries[rodIndex];
                    final style = seriesStyles[series]!;
                    return ChartInfo(
                      _monthLabels[groupIndex],
                      '${context.tr(style.label)} : ${_money(style.values[groupIndex], currency, privacy)}',
                      color: style.color,
                    );
                  },
                  data: BarChartData(
                    minY: minY,
                    maxY: maxY,
                    groupsSpace: 12,
                    alignment: BarChartAlignment.spaceEvenly,
                    gridData: FlGridData(
                      show: minY < 0,
                      drawVerticalLine: false,
                      horizontalInterval: maxY == minY
                          ? 1.0
                          : ((maxY - minY) / 4)
                                .abs()
                                .clamp(1, double.infinity)
                                .toDouble(),
                      getDrawingHorizontalLine: (value) {
                        final isZero = value.abs() < 0.001;
                        return FlLine(
                          color: isZero ? zeroLineColor : Colors.transparent,
                          strokeWidth: isZero ? 1 : 0,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index > 11) {
                              return const SizedBox.shrink();
                            }
                            final isCurrentMonth =
                                data.year == DateTime.now().year &&
                                index == DateTime.now().month - 1;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _monthLabels[index],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isCurrentMonth
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                  color: isCurrentMonth
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(12, (monthIndex) {
                      return BarChartGroupData(
                        x: monthIndex,
                        barsSpace: barsSpace,
                        barRods: activeSeries.map((series) {
                          final style = seriesStyles[series]!;
                          final toY = style.values[monthIndex];
                          return BarChartRodData(
                            toY: toY,
                            width: barWidth,
                            color: style.color,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(5),
                              topRight: const Radius.circular(5),
                              bottomLeft: Radius.circular(toY < 0 ? 5 : 0),
                              bottomRight: Radius.circular(toY < 0 ? 5 : 0),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxY,
                              color: style.color.withOpacity(0.06),
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseCategories(
    _AnnualDashboardData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    final entries = data.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Depenses par categorie', Icons.pie_chart_outline),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(context.tr('Aucune depense pour cette annee.'))
          else if (privacy.hideAmounts)
            const PrivacyChartMask(height: 190)
          else ...[
            SizedBox(
              height: 190,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 42,
                  sections: _buildCategorySections(entries),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...entries.take(6).map((entry) {
              final share = data.expenseTotal == 0
                  ? 0.0
                  : (entry.value / data.expenseTotal * 100);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(entry.key, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${share.toStringAsFixed(0)}% - ${_money(entry.value, currency, privacy)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildCategorySections(
    List<MapEntry<String, double>> entries,
  ) {
    const colors = [
      Colors.redAccent,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.blue,
      Colors.amber,
      Colors.pink,
      Colors.cyan,
    ];

    final total = entries.fold(0.0, (sum, entry) => sum + entry.value);

    return entries.take(8).toList().asMap().entries.map((item) {
      final index = item.key;
      final entry = item.value;
      final percentage = total == 0 ? 0 : (entry.value / total * 100);
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 58,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildQuickStats(
    _AnnualDashboardData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    final bestMonthIndex = _indexOfMax(data.monthlyIncome);
    final expenseMonthIndex = _indexOfMax(data.monthlyExpense);
    final hide = privacy.hideAmounts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Lecture rapide', Icons.insights_outlined),
          const SizedBox(height: 12),
          _statLine(
            'Moyenne revenus',
            _money(data.incomeTotal / 12, currency, privacy),
          ),
          _statLine(
            'Moyenne depenses',
            _money(data.expenseTotal / 12, currency, privacy),
          ),
          _statLine(
            'Moyenne investissements',
            _money(data.investmentTotal / 12, currency, privacy),
          ),
          _statLine(
            'Moyenne reste disponible',
            _money(data.availableTotal / 12, currency, privacy),
          ),
          _statLine(
            'Meilleur mois',
            hide || bestMonthIndex == null ? '-' : _monthLabels[bestMonthIndex],
          ),
          _statLine(
            'Mois le plus depensier',
            hide || expenseMonthIndex == null
                ? '-'
                : _monthLabels[expenseMonthIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceChip(
    double balance,
    String currency,
    PrivacyProvider privacy,
  ) {
    final isPositive = balance >= 0;
    final color = privacy.hideAmounts
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.52)
        : isPositive
        ? Colors.green
        : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            privacy.hideAmounts
                ? Icons.visibility_off_outlined
                : isPositive
                ? Icons.trending_up
                : Icons.trending_down,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            '${context.tr('Balance annuelle')}: ${_money(balance, currency, privacy)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _remainingChartColor() {
    final scheme = Theme.of(context).colorScheme;
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.84)
        : scheme.onSurface.withOpacity(0.62);
  }

  Color _remainingColor(double value, PrivacyProvider privacy) {
    if (privacy.hideAmounts) {
      return Theme.of(context).colorScheme.onSurface.withOpacity(0.52);
    }
    if (value < 0) return Colors.redAccent;
    return _remainingChartColor();
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr(title),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _statLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(context.tr(label))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
      ),
    );
  }

  _WealthEvolutionData _buildWealthEvolutionData({
    required int year,
    required double currentWealth,
    required List<TransactionModel> transactions,
  }) {
    final now = DateTime.now();
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31);
    final isCurrentYear = year == now.year;
    final currentDay = isCurrentYear
        ? DateTime(now.year, now.month, now.day)
        : yearEnd;
    final cappedCurrentDay = currentDay.isAfter(yearEnd) ? yearEnd : currentDay;
    final pastTransactions = transactions.where((tx) {
      return !tx.date.isAfter(cappedCurrentDay);
    }).toList();

    final actualFlow = pastTransactions.fold(0.0, (sum, tx) {
      return sum + _wealthFlow(tx);
    });
    final estimatedStartWealth = currentWealth - actualFlow;
    final actualPoints = <_WealthPoint>[];
    final projectedPoints = <_WealthPoint>[];
    var date = yearStart;
    while (!date.isAfter(yearEnd)) {
      final x = date.difference(yearStart).inDays.toDouble();
      if (!date.isAfter(cappedCurrentDay)) {
        final value = estimatedStartWealth + _flowUntil(pastTransactions, date);
        actualPoints.add(_WealthPoint(x: x, value: value, date: date));
      }
      date = date.add(const Duration(days: 7));
    }

    final currentPoint = _WealthPoint(
      x: cappedCurrentDay.difference(yearStart).inDays.toDouble(),
      value: currentWealth,
      date: cappedCurrentDay,
    );
    if (actualPoints.isEmpty ||
        actualPoints.last.date.isBefore(cappedCurrentDay)) {
      actualPoints.add(currentPoint);
    } else {
      actualPoints[actualPoints.length - 1] = currentPoint;
    }

    if (isCurrentYear && cappedCurrentDay.isBefore(yearEnd)) {
      projectedPoints.insert(0, currentPoint);
      final weeklyDeltas = _weeklyProjectionDeltas(actualPoints);
      var projectedDate = cappedCurrentDay.add(const Duration(days: 7));
      var projectedValue = currentWealth;
      var step = 0;

      while (!projectedDate.isAfter(yearEnd)) {
        final days = projectedDate.difference(projectedPoints.last.date).inDays;
        projectedValue += _projectedDeltaForStep(weeklyDeltas, step, days);
        projectedPoints.add(
          _WealthPoint(
            x: projectedDate.difference(yearStart).inDays.toDouble(),
            value: projectedValue,
            date: projectedDate,
          ),
        );
        projectedDate = projectedDate.add(const Duration(days: 7));
        step++;
      }

      if (projectedPoints.last.date.isBefore(yearEnd)) {
        final days = yearEnd.difference(projectedPoints.last.date).inDays;
        projectedValue += _projectedDeltaForStep(weeklyDeltas, step, days);
        projectedPoints.add(
          _WealthPoint(
            x: yearEnd.difference(yearStart).inDays.toDouble(),
            value: projectedValue,
            date: yearEnd,
          ),
        );
      }
    }

    return _WealthEvolutionData(
      actualPoints: actualPoints,
      projectedPoints: projectedPoints,
    );
  }

  double _wealthFlow(TransactionModel tx) {
    if (tx.type == 'income') {
      return tx.amount.abs();
    }
    if (tx.type == 'expense') {
      return -tx.amount.abs();
    }
    return 0;
  }

  double _flowUntil(List<TransactionModel> transactions, DateTime date) {
    return transactions.where((tx) => !tx.date.isAfter(date)).fold(0.0, (
      sum,
      tx,
    ) {
      return sum + _wealthFlow(tx);
    });
  }

  List<double> _weeklyProjectionDeltas(List<_WealthPoint> actualPoints) {
    if (actualPoints.length < 2) return const [0];

    final deltas = <double>[];
    for (var i = 1; i < actualPoints.length; i++) {
      final previous = actualPoints[i - 1];
      final current = actualPoints[i];
      final days = current.date.difference(previous.date).inDays;
      if (days <= 0) continue;
      final weeklyDelta = (current.value - previous.value) / days * 7;
      deltas.add(weeklyDelta);
    }

    final meaningfulDeltas = deltas
        .where((delta) => delta.abs() > 0.005)
        .toList(growable: false);
    final recentDeltas = (meaningfulDeltas.isEmpty ? deltas : meaningfulDeltas)
        .reversed
        .take(12)
        .toList()
        .reversed
        .toList();

    if (recentDeltas.isEmpty) return const [0];
    if (recentDeltas.length >= 4) return recentDeltas;

    final average =
        recentDeltas.fold(0.0, (sum, value) => sum + value) /
        recentDeltas.length;
    return List<double>.filled(4, average);
  }

  double _projectedDeltaForStep(List<double> weeklyDeltas, int step, int days) {
    if (weeklyDeltas.isEmpty || days <= 0) return 0;

    final average =
        weeklyDeltas.fold(0.0, (sum, value) => sum + value) /
        weeklyDeltas.length;
    final pattern = weeklyDeltas[step % weeklyDeltas.length];
    final damping = (1 - (step * 0.025)).clamp(0.55, 1.0).toDouble();
    final weeklyDelta = (average * 0.45) + (pattern * 0.55 * damping);

    return weeklyDelta * (days / 7);
  }

  int? _indexOfMax(List<double> values) {
    if (values.every((value) => value == 0)) return null;
    var index = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[index]) index = i;
    }
    return index;
  }
}

enum _MonthlyChartSeries { income, expense, investment, remaining }

class _ChartSeriesStyle {
  final String label;
  final IconData icon;
  final Color color;
  final List<double> values;

  const _ChartSeriesStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.values,
  });
}

const _monthLabels = [
  'Jan',
  'Fev',
  'Mar',
  'Avr',
  'Mai',
  'Juin',
  'Juil',
  'Aou',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class _AnnualDashboardData {
  final int year;
  final List<_AccountSummary> accounts;
  final double incomeTotal;
  final double expenseTotal;
  final double investmentTotal;
  final double accountTotal;
  final List<double> monthlyIncome;
  final List<double> monthlyExpense;
  final List<double> monthlyInvestment;
  final Map<String, double> expenseByCategory;
  final List<_WealthPoint> actualWealthPoints;
  final List<_WealthPoint> projectedWealthPoints;

  const _AnnualDashboardData({
    required this.year,
    required this.accounts,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.investmentTotal,
    required this.accountTotal,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.monthlyInvestment,
    required this.expenseByCategory,
    required this.actualWealthPoints,
    required this.projectedWealthPoints,
  });

  double get annualBalance => incomeTotal - expenseTotal;
  double get availableTotal => incomeTotal - expenseTotal - investmentTotal;
  List<double> get monthlyAvailable {
    return List.generate(
      12,
      (index) =>
          monthlyIncome[index] -
          monthlyExpense[index] -
          monthlyInvestment[index],
    );
  }

  factory _AnnualDashboardData.empty(int year) {
    return _AnnualDashboardData(
      year: year,
      accounts: const [],
      incomeTotal: 0,
      expenseTotal: 0,
      investmentTotal: 0,
      accountTotal: 0,
      monthlyIncome: List<double>.filled(12, 0),
      monthlyExpense: List<double>.filled(12, 0),
      monthlyInvestment: List<double>.filled(12, 0),
      expenseByCategory: const {},
      actualWealthPoints: [_WealthPoint(x: 0, value: 0, date: DateTime(year))],
      projectedWealthPoints: const [],
    );
  }
}

class _AccountSummary {
  final String name;
  final double balance;

  const _AccountSummary({required this.name, required this.balance});
}

class _WealthEvolutionData {
  final List<_WealthPoint> actualPoints;
  final List<_WealthPoint> projectedPoints;

  const _WealthEvolutionData({
    required this.actualPoints,
    required this.projectedPoints,
  });
}

class _WealthPoint {
  final double x;
  final double value;
  final DateTime date;

  const _WealthPoint({
    required this.x,
    required this.value,
    required this.date,
  });
}

class _WealthAxis {
  final double minY;
  final double maxY;

  const _WealthAxis({required this.minY, required this.maxY});

  factory _WealthAxis.fromPoints(List<_WealthPoint> points) {
    if (points.isEmpty) {
      return const _WealthAxis(minY: -1, maxY: 1);
    }

    final firstValue = points.first.value;
    var minValue = firstValue;
    var maxValue = firstValue;
    for (final point in points) {
      if (point.value < minValue) minValue = point.value;
      if (point.value > maxValue) maxValue = point.value;
    }

    final lowerDistance = (firstValue - minValue).abs();
    final upperDistance = (maxValue - firstValue).abs();
    final variation = (maxValue - minValue).abs();
    final padding = variation == 0 ? 1.0 : variation * 0.18;
    final halfRange =
        [
          lowerDistance,
          upperDistance,
          padding,
        ].reduce((a, b) => a > b ? a : b) +
        padding;

    return _WealthAxis(
      minY: firstValue - halfRange,
      maxY: firstValue + halfRange,
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _LegendDot({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          Row(
            children: List.generate(4, (index) {
              return Container(
                width: 5,
                height: 5,
                margin: EdgeInsets.only(right: index == 3 ? 0 : 3),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              );
            }),
          )
        else
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.68),
          ),
        ),
      ],
    );
  }
}
