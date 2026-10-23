import 'package:mysold/widgets/app_design.dart';
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

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  Future<_AnalyticsData>? _future;
  int? _lastFinancialVersion;
  int? _lastReferenceVersion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userData = context.watch<UserDataProvider>();
    if (_future == null ||
        _lastFinancialVersion != userData.financialDataVersion ||
        _lastReferenceVersion != userData.referenceDataVersion) {
      _lastFinancialVersion = userData.financialDataVersion;
      _lastReferenceVersion = userData.referenceDataVersion;
      _future = _loadAnalytics();
    }
  }

  Future<_AnalyticsData> _loadAnalytics() async {
    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return _AnalyticsData.empty();

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final yearStart = DateTime(now.year, 1, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    final service = BudgetService(userId: uid);
    final userDoc = DocumentStore.instance.collection('users').doc(uid);

    final references = context.read<UserDataProvider>();
    final accountsFuture = userDoc.collection('accounts').get();
    final categoriesFuture = references.getCategories();
    final yearTransactionsFuture = service.getTransactionsBetween(
      start: yearStart,
      end: nextMonth,
      descending: false,
    );
    final previousMonthFuture = previousMonth.year == now.year
        ? Future<List<TransactionModel>>.value(const [])
        : service.getTransactionsForMonth(previousMonth);

    final accountSnapshot = await accountsFuture;
    final categories = await categoriesFuture;
    final yearTransactions = await yearTransactionsFuture;
    final previousYearMonthTransactions = await previousMonthFuture;

    final currentTransactions = yearTransactions.where((tx) {
      return tx.date.year == currentMonth.year &&
          tx.date.month == currentMonth.month;
    }).toList();

    final previousTransactions = [
      ...yearTransactions.where((tx) {
        return tx.date.year == previousMonth.year &&
            tx.date.month == previousMonth.month;
      }),
      ...previousYearMonthTransactions,
    ];
    final locale = Localizations.localeOf(context).toString();

    final currentWealth = accountSnapshot.docs.fold(0.0, (sum, doc) {
      final data = doc.data();
      return sum + ((data['balance'] ?? 0) as num).toDouble();
    });

    return _AnalyticsData.fromTransactions(
      now: now,
      currentWealth: currentWealth,
      yearTransactions: yearTransactions,
      currentTransactions: currentTransactions,
      previousTransactions: previousTransactions,
      categories: categories,
      locale: locale,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadAnalytics());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>().currency;
    final privacy = context.watch<PrivacyProvider>();

    return FutureBuilder<_AnalyticsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('${context.tr('Erreur')} : ${snapshot.error}'),
          );
        }

        final data = snapshot.data ?? _AnalyticsData.empty();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            children: [
              _buildHeader(data),
              const SizedBox(height: 14),
              _buildKpiGrid(data, currency, privacy),
              const SizedBox(height: 16),
              _buildMonthComparison(data, currency, privacy),
              const SizedBox(height: 16),
              _buildProjection(data, currency, privacy),
              const SizedBox(height: 16),
              _buildTopIncomes(data, currency, privacy),
              const SizedBox(height: 16),
              _buildTopExpenses(data, currency, privacy),
              const SizedBox(height: 16),
              _buildRecurringIncome(data, currency, privacy),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(_AnalyticsData data) {
    final month = DateFormat(
      'MMMM yyyy',
      Localizations.localeOf(context).toString(),
    ).format(DateTime.now());
    return PageIntro(
      eyebrow: context.tr('ANALYSE'),
      title: context.tr('Statistiques'),
      subtitle: '${context.tr('Votre budget en perspective')} · $month',
      action: _TrendBadge(
        value: data.currentAvailable - data.previousAvailable,
        hidden: context.watch<PrivacyProvider>().hideAmounts,
      ),
    );
  }

  Widget _buildKpiGrid(
    _AnalyticsData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    final cards = [
      AppMetricCard(
        label: context.tr('Patrimoine'),
        value: privacy.money(data.currentWealth, currency),
        icon: Icons.account_balance_wallet_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      AppMetricCard(
        label: context.tr('Taux epargne'),
        value: privacy.hideAmounts
            ? '**%'
            : data.currentIncome <= 0
            ? '-'
            : '${data.savingsRate.toStringAsFixed(1)} %',
        icon: Icons.savings_outlined,
        color: privacy.hideAmounts
            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.52)
            : data.savingsRate >= 0
            ? Colors.green
            : Colors.redAccent,
      ),
      AppMetricCard(
        label: context.tr('Reste du mois'),
        value: privacy.money(data.currentAvailable, currency),
        icon: Icons.payments_outlined,
        color: _remainingColor(data.currentAvailable, privacy),
      ),
      AppMetricCard(
        label: context.tr('Projection fin mois'),
        value: privacy.money(data.endMonthProjection, currency),
        icon: Icons.timeline_outlined,
        color: _remainingColor(data.endMonthProjection, privacy),
      ),
    ];

    return AppMetricGrid(children: cards);
  }

  Widget _buildWealthEvolution(
    _AnalyticsData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    final actualSpots = data.actualWealthPoints
        .map((point) => FlSpot(point.x, point.value))
        .toList();
    final projectedSpots = data.projectedWealthPoints
        .map((point) => FlSpot(point.x, point.value))
        .toList();
    final values = [
      ...data.actualWealthPoints.map((point) => point.value),
      ...data.projectedWealthPoints.map((point) => point.value),
      0.0,
    ];
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs();
    final padding = range == 0 ? 100.0 : range * 0.12;
    final yearStart = DateTime(DateTime.now().year, 1, 1);
    final yearEnd = DateTime(DateTime.now().year, 12, 31);
    final maxX = yearEnd.difference(yearStart).inDays.toDouble();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actualColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.88);
    final projectedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.38);

    return _Panel(
      title: 'Evolution du patrimoine annuel',
      icon: Icons.show_chart_rounded,
      child: privacy.hideAmounts
          ? const PrivacyChartMask(height: 240)
          : Column(
              children: [
                Row(
                  children: [
                    _LegendDot(color: actualColor, label: context.tr('Reel')),
                    const SizedBox(width: 14),
                    _LegendDot(
                      color: projectedColor,
                      label: context.tr('Projection'),
                      dashed: true,
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
                      minY: minY - padding,
                      maxY: maxY + padding,
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
                                '${DateFormat('dd/MM').format(date)}\n${privacy.money(item.y, currency)}',
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
                            reservedSize: 46,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                privacy.compactMoney(value, currency),
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
                            color: actualColor.withOpacity(
                              isDark ? 0.10 : 0.06,
                            ),
                          ),
                        ),
                        if (projectedSpots.length > 1)
                          LineChartBarData(
                            spots: projectedSpots,
                            isCurved: true,
                            barWidth: 2.2,
                            color: projectedColor,
                            dashArray: const [2, 8],
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(show: false),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMonthComparison(
    _AnalyticsData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    return _Panel(
      title: 'Comparaison mensuelle',
      icon: Icons.compare_arrows_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _monthSummaryPair(data, currency, privacy),
          const SizedBox(height: 16),
          _comparisonRow(
            'Revenus',
            data.currentIncome,
            data.previousIncome,
            currency,
            privacy,
          ),
          _comparisonRow(
            'Depenses',
            data.currentExpense,
            data.previousExpense,
            currency,
            privacy,
            inverted: true,
          ),
          _comparisonRow(
            'Investissements',
            data.currentInvestment,
            data.previousInvestment,
            currency,
            privacy,
          ),
          _comparisonRow(
            'Reste disponible',
            data.currentAvailable,
            data.previousAvailable,
            currency,
            privacy,
          ),
        ],
      ),
    );
  }

  Widget _monthSummaryPair(
    _AnalyticsData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        final cards = [
          _MonthSummaryCard(
            label: data.previousMonthLabel,
            income: data.previousIncome,
            expense: data.previousExpense,
            investment: data.previousInvestment,
            available: data.previousAvailable,
            currency: currency,
            privacy: privacy,
          ),
          _MonthSummaryCard(
            label: data.currentMonthLabel,
            income: data.currentIncome,
            expense: data.currentExpense,
            investment: data.currentInvestment,
            available: data.currentAvailable,
            currency: currency,
            privacy: privacy,
            highlighted: true,
          ),
        ];

        if (wide) {
          return Row(
            children: [
              Expanded(child: cards.first),
              const SizedBox(width: 10),
              Expanded(child: cards.last),
            ],
          );
        }

        return Column(
          children: [cards.first, const SizedBox(height: 10), cards.last],
        );
      },
    );
  }

  Widget _comparisonRow(
    String label,
    double current,
    double previous,
    String currency,
    PrivacyProvider privacy, {
    bool inverted = false,
  }) {
    final delta = current - previous;
    final isGood = inverted ? delta <= 0 : delta >= 0;
    final color = privacy.hideAmounts
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.52)
        : isGood
        ? Colors.green
        : Colors.redAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(context.tr(label))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                privacy.money(current, currency),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                privacy.money(previous, currency),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.56),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              privacy.hideAmounts
                  ? privacy.money(delta, currency)
                  : '${delta >= 0 ? '+' : ''}${privacy.money(delta, currency)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjection(
    _AnalyticsData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    final color = privacy.hideAmounts
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.58)
        : data.endMonthProjection >= 0
        ? Colors.green
        : Colors.redAccent;
    return _Panel(
      title: 'Projection fin de mois',
      icon: Icons.auto_graph_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ProjectionMetric(
                  label: 'Solde actuel',
                  value: privacy.money(data.currentAvailable, currency),
                  color: _remainingColor(data.currentAvailable, privacy),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProjectionMetric(
                  label: 'Fin de mois estimée',
                  value: privacy.money(data.endMonthProjection, currency),
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'Revenus encaissés conservés, dépenses projetées au rythme actuel, investissements déduits du disponible.',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: data.monthProgress,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                privacy.hideAmounts
                    ? '**%'
                    : '${(data.monthProgress * 100).toStringAsFixed(0)} %',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopIncomes(
    _AnalyticsData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    return _Panel(
      title: 'Top revenus',
      icon: Icons.trending_up_rounded,
      child: data.topIncomes.isEmpty
          ? Text(context.tr('Aucun revenu ce mois-ci.'))
          : Column(
              children: data.topIncomes.map((income) {
                return _RankingRow(
                  title: income.label,
                  subtitle: DateFormat('dd/MM/yyyy').format(income.date),
                  trailing: privacy.money(income.amount, currency),
                  color: Colors.green,
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTopExpenses(
    _AnalyticsData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    return _Panel(
      title: 'Top depenses',
      icon: Icons.local_fire_department_outlined,
      child: data.topExpenses.isEmpty
          ? Text(context.tr('Aucune depense ce mois-ci.'))
          : Column(
              children: data.topExpenses.map((expense) {
                return _RankingRow(
                  title: expense.label,
                  subtitle: DateFormat('dd/MM/yyyy').format(expense.date),
                  trailing: privacy.money(expense.amount, currency),
                  color: Colors.redAccent,
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRecurringIncome(
    _AnalyticsData data,
    String currency,
    PrivacyProvider privacy,
  ) {
    return _Panel(
      title: 'Revenus recurrents',
      icon: Icons.repeat_rounded,
      child: data.recurringIncome.isEmpty
          ? Text(context.tr('Aucun revenu recurrent detecte pour le moment.'))
          : Column(
              children: data.recurringIncome.map((income) {
                return _RankingRow(
                  title: income.label,
                  subtitle:
                      '${income.monthCount} ${context.tr('mois detectes')}',
                  trailing: privacy.money(income.averageAmount, currency),
                  color: Colors.green,
                );
              }).toList(),
            ),
    );
  }

  Color _remainingColor(double value, PrivacyProvider privacy) {
    if (privacy.hideAmounts) {
      return Theme.of(context).colorScheme.onSurface.withOpacity(0.52);
    }
    if (value < 0) return Colors.redAccent;
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.84)
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.64);
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Panel({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(title),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  final String label;
  final double income;
  final double expense;
  final double investment;
  final double available;
  final String currency;
  final PrivacyProvider privacy;
  final bool highlighted;

  const _MonthSummaryCard({
    required this.label,
    required this.income,
    required this.expense,
    required this.investment,
    required this.available,
    required this.currency,
    required this.privacy,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primary.withOpacity(0.10)
            : scheme.surface.withOpacity(0.36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? scheme.primary.withOpacity(0.22)
              : scheme.outline.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _miniLine(context, 'Revenus', income, Colors.green),
          _miniLine(context, 'Dépenses', expense, Colors.redAccent),
          _miniLine(
            context,
            'Investissements',
            investment,
            Theme.of(context).colorScheme.primary,
          ),
          _miniLine(
            context,
            'Reste',
            available,
            available >= 0
                ? Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.84)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.64)
                : Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _miniLine(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr(label),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            privacy.money(value, currency),
            style: TextStyle(
              color: privacy.hideAmounts ? null : color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectionMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ProjectionMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final Color color;

  const _RankingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.20),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.60),
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double value;
  final bool hidden;

  const _TrendBadge({required this.value, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final color = hidden
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.52)
        : value >= 0
        ? Colors.green
        : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        hidden
            ? Icons.visibility_off_outlined
            : value >= 0
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        size: 19,
        color: color,
      ),
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

class _AnalyticsData {
  final String currentMonthLabel;
  final String previousMonthLabel;
  final double currentWealth;
  final double currentIncome;
  final double currentExpense;
  final double currentInvestment;
  final double previousIncome;
  final double previousExpense;
  final double previousInvestment;
  final double endMonthProjection;
  final double monthProgress;
  final List<_WealthPoint> actualWealthPoints;
  final List<_WealthPoint> projectedWealthPoints;
  final List<_ExpenseItem> topExpenses;
  final List<_ExpenseItem> topIncomes;
  final List<_RecurringIncome> recurringIncome;

  const _AnalyticsData({
    required this.currentMonthLabel,
    required this.previousMonthLabel,
    required this.currentWealth,
    required this.currentIncome,
    required this.currentExpense,
    required this.currentInvestment,
    required this.previousIncome,
    required this.previousExpense,
    required this.previousInvestment,
    required this.endMonthProjection,
    required this.monthProgress,
    required this.actualWealthPoints,
    required this.projectedWealthPoints,
    required this.topExpenses,
    required this.topIncomes,
    required this.recurringIncome,
  });

  double get currentNet => currentIncome - currentExpense;
  double get previousNet => previousIncome - previousExpense;
  double get currentAvailable =>
      currentIncome - currentExpense - currentInvestment;
  double get previousAvailable =>
      previousIncome - previousExpense - previousInvestment;

  double get savingsRate {
    if (currentIncome <= 0) return 0;
    return (currentAvailable / currentIncome) * 100;
  }

  factory _AnalyticsData.fromTransactions({
    required DateTime now,
    required double currentWealth,
    required List<TransactionModel> yearTransactions,
    required List<TransactionModel> currentTransactions,
    required List<TransactionModel> previousTransactions,
    required Map<String, Map<String, dynamic>> categories,
    required String locale,
  }) {
    final currentMonthLabel = DateFormat('MMMM yyyy', locale).format(now);
    final previousMonthDate = DateTime(now.year, now.month - 1, 1);
    final previousMonthLabel = DateFormat(
      'MMMM yyyy',
      locale,
    ).format(previousMonthDate);
    final currentIncome = _sum(currentTransactions, 'income');
    final currentExpense = _sum(currentTransactions, 'expense');
    final currentInvestment = _sum(currentTransactions, 'investment');
    final previousIncome = _sum(previousTransactions, 'income');
    final previousExpense = _sum(previousTransactions, 'expense');
    final previousInvestment = _sum(previousTransactions, 'investment');
    final elapsedDays = now.day.clamp(1, 31);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final averageDailyExpense = currentExpense / elapsedDays;
    final projectedExpense = averageDailyExpense * daysInMonth;
    final projection = currentIncome - currentInvestment - projectedExpense;
    final monthProgress = (elapsedDays / daysInMonth).clamp(0.0, 1.0);

    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year, 12, 31);
    final currentDay = DateTime(now.year, now.month, now.day);
    final pastTransactions = yearTransactions.where((tx) {
      return !tx.date.isAfter(currentDay);
    }).toList();

    final actualFlow = pastTransactions.fold(0.0, (sum, tx) {
      return sum + _wealthFlow(tx);
    });
    final estimatedStartWealth = currentWealth - actualFlow;
    final elapsedYearDays = currentDay
        .difference(yearStart)
        .inDays
        .clamp(1, 366)
        .toInt();
    final dailyProjectionFlow = actualFlow / elapsedYearDays;

    final actualPoints = <_WealthPoint>[];
    final projectedPoints = <_WealthPoint>[];
    var date = yearStart;
    while (!date.isAfter(yearEnd)) {
      final x = date.difference(yearStart).inDays.toDouble();
      if (!date.isAfter(currentDay)) {
        final value = estimatedStartWealth + _flowUntil(pastTransactions, date);
        actualPoints.add(_WealthPoint(x: x, value: value, date: date));
      } else {
        final futureDays = date.difference(currentDay).inDays;
        final value = currentWealth + dailyProjectionFlow * futureDays;
        projectedPoints.add(_WealthPoint(x: x, value: value, date: date));
      }
      date = date.add(const Duration(days: 7));
    }

    final currentX = currentDay.difference(yearStart).inDays.toDouble();
    final currentPoint = _WealthPoint(
      x: currentX,
      value: currentWealth,
      date: currentDay,
    );
    if (actualPoints.isEmpty || actualPoints.last.date!.isBefore(currentDay)) {
      actualPoints.add(currentPoint);
    } else {
      actualPoints[actualPoints.length - 1] = currentPoint;
    }
    projectedPoints.insert(0, currentPoint);
    if (projectedPoints.last.date!.isBefore(yearEnd)) {
      final futureDays = yearEnd.difference(currentDay).inDays;
      projectedPoints.add(
        _WealthPoint(
          x: yearEnd.difference(yearStart).inDays.toDouble(),
          value: currentWealth + dailyProjectionFlow * futureDays,
          date: yearEnd,
        ),
      );
    }

    final topExpenses =
        currentTransactions.where((tx) => tx.type == 'expense').map((tx) {
          final category = categories[tx.categoryId]?['name']?.toString();
          return _ExpenseItem(
            label: tx.description.trim().isEmpty
                ? category ?? 'Depense'
                : tx.description.trim(),
            amount: tx.amount.abs(),
            date: tx.date,
          );
        }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    final topIncomes =
        currentTransactions.where((tx) => tx.type == 'income').map((tx) {
          final category = categories[tx.categoryId]?['name']?.toString();
          return _ExpenseItem(
            label: tx.description.trim().isEmpty
                ? category ?? 'Revenu'
                : tx.description.trim(),
            amount: tx.amount.abs(),
            date: tx.date,
          );
        }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    final recurringIncome = _detectRecurringIncome(yearTransactions);

    return _AnalyticsData(
      currentMonthLabel: currentMonthLabel,
      previousMonthLabel: previousMonthLabel,
      currentWealth: currentWealth,
      currentIncome: currentIncome,
      currentExpense: currentExpense,
      currentInvestment: currentInvestment,
      previousIncome: previousIncome,
      previousExpense: previousExpense,
      previousInvestment: previousInvestment,
      endMonthProjection: projection,
      monthProgress: monthProgress.toDouble(),
      actualWealthPoints: actualPoints,
      projectedWealthPoints: projectedPoints,
      topExpenses: topExpenses.take(5).toList(),
      topIncomes: topIncomes.take(5).toList(),
      recurringIncome: recurringIncome.take(5).toList(),
    );
  }

  factory _AnalyticsData.empty() {
    return _AnalyticsData(
      currentMonthLabel: '',
      previousMonthLabel: '',
      currentWealth: 0,
      currentIncome: 0,
      currentExpense: 0,
      currentInvestment: 0,
      previousIncome: 0,
      previousExpense: 0,
      previousInvestment: 0,
      endMonthProjection: 0,
      monthProgress: 0,
      actualWealthPoints: const [_WealthPoint(x: 0, value: 0, date: null)],
      projectedWealthPoints: const [],
      topExpenses: const [],
      topIncomes: const [],
      recurringIncome: const [],
    );
  }

  static double _wealthFlow(TransactionModel tx) {
    if (tx.type == 'income') {
      return tx.amount.abs();
    }
    if (tx.type == 'expense') {
      return -tx.amount.abs();
    }
    return 0;
  }

  static double _flowUntil(List<TransactionModel> transactions, DateTime date) {
    return transactions.where((tx) => !tx.date.isAfter(date)).fold(0.0, (
      sum,
      tx,
    ) {
      return sum + _wealthFlow(tx);
    });
  }

  static double _sum(List<TransactionModel> transactions, String type) {
    return transactions
        .where((tx) => tx.type == type)
        .fold(0.0, (sum, tx) => sum + tx.amount.abs());
  }

  static List<_RecurringIncome> _detectRecurringIncome(
    List<TransactionModel> transactions,
  ) {
    final grouped = <String, List<TransactionModel>>{};
    for (final tx in transactions.where((tx) => tx.type == 'income')) {
      final key = tx.description.trim().toLowerCase();
      if (key.isEmpty) continue;
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    final recurring = <_RecurringIncome>[];
    for (final entry in grouped.entries) {
      final months = entry.value
          .map((tx) => '${tx.date.year}-${tx.date.month}')
          .toSet();
      if (months.length < 2) continue;
      final total = entry.value.fold(0.0, (sum, tx) => sum + tx.amount.abs());
      recurring.add(
        _RecurringIncome(
          label: _titleCase(entry.key),
          averageAmount: total / entry.value.length,
          monthCount: months.length,
        ),
      );
    }

    recurring.sort((a, b) => b.averageAmount.compareTo(a.averageAmount));
    return recurring;
  }

  static String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _ExpenseItem {
  final String label;
  final double amount;
  final DateTime date;

  const _ExpenseItem({
    required this.label,
    required this.amount,
    required this.date,
  });
}

class _WealthPoint {
  final double x;
  final double value;
  final DateTime? date;

  const _WealthPoint({
    required this.x,
    required this.value,
    required this.date,
  });
}

class _RecurringIncome {
  final String label;
  final double averageAmount;
  final int monthCount;

  const _RecurringIncome({
    required this.label,
    required this.averageAmount,
    required this.monthCount,
  });
}
