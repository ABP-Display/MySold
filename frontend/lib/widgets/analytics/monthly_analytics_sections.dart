import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/app_select_field.dart';
import 'package:mysold/widgets/app_selection_button.dart';
import 'package:mysold/widgets/graphiques/app_charts.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';

String _money(
  BuildContext context,
  double value,
  String currency,
  bool hidden,
) => hidden
    ? '•••• $currency'
    : NumberFormat.currency(
        locale: Localizations.localeOf(context).toString(),
        symbol: currency,
      ).format(value);
String _month(BuildContext context, DateTime value) =>
    DateFormat.yMMM(Localizations.localeOf(context).toString()).format(value);
Color _muted(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

class MonthlyStatsPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;
  const MonthlyStatsPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });
  @override
  Widget build(BuildContext context) => AppPanel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(color: _muted(context), fontSize: 12, height: 1.5),
          ),
        ],
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class MonthlyOverview extends StatelessWidget {
  final MonthlyAnalytics data;
  final String currency;
  final bool hidden;
  const MonthlyOverview({
    super.key,
    required this.data,
    required this.currency,
    required this.hidden,
  });
  @override
  Widget build(BuildContext context) => AppMetricGrid(
    children: [
      for (final item in [
        ('Revenus', data.current.income, Icons.south_west, Colors.green),
        (
          'Dépenses',
          data.current.expense,
          Icons.north_east,
          Theme.of(context).colorScheme.error,
        ),
        (
          'Investissements',
          data.current.investment,
          Icons.trending_up,
          Theme.of(context).colorScheme.primary,
        ),
        (
          'Reste du mois',
          data.current.available,
          Icons.payments_outlined,
          Theme.of(context).colorScheme.primary,
        ),
      ])
        AppMetricCard(
          label: context.tr(item.$1),
          value: _money(context, item.$2, currency, hidden),
          icon: item.$3,
          color: hidden ? _muted(context) : item.$4,
        ),
    ],
  );
}

class MonthlyComparison extends StatelessWidget {
  final MonthlyAnalytics data;
  final String currency;
  final bool hidden;
  final ValueChanged<bool> onSameDay;
  const MonthlyComparison({
    super.key,
    required this.data,
    required this.currency,
    required this.hidden,
    required this.onSameDay,
  });
  @override
  Widget build(BuildContext context) => MonthlyStatsPanel(
    title: 'Comparaison mensuelle M−1',
    icon: Icons.compare_arrows,
    subtitle:
        '${_month(context, data.month)} / ${_month(context, data.previousMonth)} · ${context.tr(data.sameDayComparison ? 'À date égale' : 'Mois complets')}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.isCurrent) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final same in [true, false])
                AppSelectionButton(
                  key: ValueKey(
                    same ? 'comparison-same-day' : 'comparison-full-month',
                  ),
                  selected: data.sameDayComparison == same,
                  onPressed: () => onSameDay(same),
                  child: Text(
                    context.tr(same ? 'À date égale' : 'Mois complets'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              data.sameDayComparison
                  ? 'Le mois précédent est arrêté au même jour.'
                  : 'Le mois en cours est incomplet ; M−1 est affiché en entier.',
            ),
            style: TextStyle(fontSize: 12, color: _muted(context)),
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, bounds) {
            final columns =
                bounds.maxWidth >= 660 &&
                    MediaQuery.textScalerOf(context).scale(14) < 22
                ? 2
                : 1;
            final width = (bounds.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final metric in [
                  ('Revenus', data.current.income, data.previous.income, false),
                  (
                    'Dépenses',
                    data.current.expense,
                    data.previous.expense,
                    true,
                  ),
                  (
                    'Investissements',
                    data.current.investment,
                    data.previous.investment,
                    false,
                  ),
                  (
                    'Reste disponible',
                    data.current.available,
                    data.previous.available,
                    false,
                  ),
                ])
                  SizedBox(
                    width: width,
                    child: _ComparisonMetric(
                      label: metric.$1,
                      current: metric.$2,
                      previous: metric.$3,
                      inverted: metric.$4,
                      month: _month(context, data.month),
                      previousMonth: _month(context, data.previousMonth),
                      currency: currency,
                      hidden: hidden,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _ComparisonMetric extends StatelessWidget {
  final String label, month, previousMonth, currency;
  final double current, previous;
  final bool hidden, inverted;
  const _ComparisonMetric({
    required this.label,
    required this.month,
    required this.previousMonth,
    required this.currency,
    required this.current,
    required this.previous,
    required this.hidden,
    required this.inverted,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final delta = current - previous;
    final color = hidden || delta == 0
        ? scheme.onSurfaceVariant
        : (inverted ? delta < 0 : delta > 0)
        ? Colors.green.shade600
        : scheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDesign.panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(label),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, bounds) {
              Widget value(String name, double amount, Color color) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontSize: 12, color: _muted(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _money(context, amount, currency, hidden),
                    style: TextStyle(fontWeight: FontWeight.w600, color: color),
                  ),
                ],
              );
              if (bounds.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 22)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    value(previousMonth, previous, _muted(context)),
                    const SizedBox(height: 12),
                    value(month, current, scheme.onSurface),
                  ],
                );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: value(previousMonth, previous, _muted(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: value(month, current, scheme.onSurface)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (hidden || (current >= 0 && previous >= 0)) ...[
            for (final pair in [
              (previous, scheme.onSurfaceVariant.withValues(alpha: .5)),
              (current, scheme.primary),
            ]) ...[
              LinearProgressIndicator(
                value: hidden
                    ? 1
                    : math.max(current, previous) == 0
                    ? 0
                    : pair.$1 / math.max(current, previous),
                minHeight: 5,
                color: hidden ? _muted(context).withValues(alpha: .2) : pair.$2,
                backgroundColor: scheme.onSurface.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
            ],
          ],
          Text(
            '${context.tr('Écart')} : ${!hidden && delta > 0 ? '+' : ''}${_money(context, delta, currency, hidden)}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPair extends StatelessWidget {
  final List<Widget> children;
  const _MetricPair({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns =
          bounds.maxWidth >= 560 &&
              MediaQuery.textScalerOf(context).scale(14) < 22
          ? 2
          : 1;
      final width = (bounds.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class MonthlyProjection extends StatelessWidget {
  final MonthlyAnalytics data;
  final String currency;
  final bool hidden;
  const MonthlyProjection({
    super.key,
    required this.data,
    required this.currency,
    required this.hidden,
  });
  @override
  Widget build(BuildContext context) => MonthlyStatsPanel(
    title: 'Projection fin de mois',
    icon: Icons.auto_graph,
    subtitle: context.tr(
      data.isCurrent
          ? 'Dépenses estimées au rythme actuel, revenus reçus et investissements inchangés.'
          : 'Mois terminé : résultat réel.',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricPair(
          children: [
            AppMetricCard(
              label: context.tr('Reste du mois'),
              value: _money(context, data.current.available, currency, hidden),
              icon: Icons.payments_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            AppMetricCard(
              label: context.tr(
                data.isCurrent ? 'Fin de mois estimée' : 'Résultat du mois',
              ),
              value: data.projectedAvailable == null
                  ? '—'
                  : _money(context, data.projectedAvailable!, currency, hidden),
              icon: Icons.flag_outlined,
              color: hidden || (data.projectedAvailable ?? 0) >= 0
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ],
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: data.elapsedDays / data.daysInMonth,
          minHeight: 5,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text(
          '${data.elapsedDays} / ${data.daysInMonth} ${context.tr('jours écoulés')}',
          style: TextStyle(color: _muted(context), fontSize: 12),
        ),
        if (data.operations.isEmpty) ...[
          const SizedBox(height: 8),
          Text(context.tr('Pas assez de données pour estimer la fin du mois.')),
        ],
      ],
    ),
  );
}

class MonthlySpendingChart extends StatefulWidget {
  final MonthlyAnalytics data;
  final String currency;
  final bool hidden;
  const MonthlySpendingChart({
    super.key,
    required this.data,
    required this.currency,
    required this.hidden,
  });
  @override
  State<MonthlySpendingChart> createState() => _MonthlySpendingChartState();
}

class _MonthlySpendingChartState extends State<MonthlySpendingChart> {
  late int _day = math.max(1, widget.data.elapsedDays);
  @override
  void didUpdateWidget(covariant MonthlySpendingChart old) {
    super.didUpdateWidget(old);
    if (old.data.month != widget.data.month)
      _day = math.max(1, widget.data.elapsedDays);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data, scheme = Theme.of(context).colorScheme;
    final current = data.cumulativeExpense,
        previous = data.previousCumulativeExpense;
    final maximum = [...current, ...previous].fold(1.0, math.max) * 1.15;
    final lastDay = math.max(data.daysInMonth, data.previousDays);
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final axisStep = scale > 1.5
        ? 15
        : narrow
        ? 10
        : 5;
    void select(int value) {
      if (_day != value) setState(() => _day = value.clamp(1, lastDay));
    }

    return MonthlyStatsPanel(
      title: 'Rythme des dépenses',
      icon: Icons.show_chart,
      subtitle: context.tr(
        'Cumul quotidien. Choisissez un jour pour comparer les montants.',
      ),
      child: widget.hidden
          ? const PrivacyChartMask(height: 220)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    Text(
                      '● ${_month(context, data.month)}',
                      style: TextStyle(color: scheme.primary, fontSize: 12),
                    ),
                    Text(
                      '┄ ${_month(context, data.previousMonth)}',
                      style: TextStyle(color: _muted(context), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (data.current.expense == 0 && data.previous.expense == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      context.tr(
                        'Aucune dépense enregistrée sur ces périodes.',
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 210,
                    child: AppLineChart(
                      LineChartData(
                        minX: 1,
                        maxX: lastDay.toDouble(),
                        minY: 0,
                        maxY: maximum,
                        clipData: const FlClipData.all(),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: false,
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions) return;
                            final spots = response?.lineBarSpots;
                            if (spots != null && spots.isNotEmpty)
                              select(spots.first.x.round());
                          },
                        ),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: maximum / 4,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: scheme.outline.withValues(alpha: .15),
                            strokeWidth: 1,
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
                              showTitles: scale <= 1.5,
                              reservedSize: 46 * scale,
                              interval: maximum / 4,
                              getTitlesWidget: (value, meta) => Text(
                                NumberFormat.compact(
                                  locale: Localizations.localeOf(
                                    context,
                                  ).toString(),
                                ).format(value),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _muted(context),
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: axisStep.toDouble(),
                              reservedSize: 26 * scale,
                              getTitlesWidget: (value, meta) =>
                                  value.round() != 1 &&
                                      value.round() % axisStep != 0
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        '${value.toInt()}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _muted(context),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        lineBarsData: [
                          for (final series in [
                            (previous, scheme.onSurfaceVariant, true),
                            (current, scheme.primary, false),
                          ])
                            if (series.$1.isNotEmpty)
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < series.$1.length; i++)
                                    FlSpot(i + 1.0, series.$1[i]),
                                ],
                                color: series.$2,
                                barWidth: 2,
                                isCurved: false,
                                dashArray: series.$3 ? [5, 4] : null,
                                dotData: FlDotData(show: series.$1.length == 1),
                                belowBarData: BarAreaData(
                                  show: !series.$3,
                                  color: scheme.primary.withValues(alpha: .06),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: AppDesign.panel(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${context.tr('Jour')} $_day',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_month(context, data.month)} : ${_day <= current.length ? _money(context, current[_day - 1], widget.currency, false) : '—'}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_month(context, data.previousMonth)} : ${_day <= previous.length ? _money(context, previous[_day - 1], widget.currency, false) : '—'}',
                      ),
                    ],
                  ),
                ),
                Slider(
                  key: const ValueKey('monthly-chart-day'),
                  min: 1,
                  max: lastDay.toDouble(),
                  divisions: lastDay - 1,
                  value: _day.toDouble(),
                  label: '${context.tr('Jour')} $_day',
                  semanticFormatterCallback: (value) =>
                      '${context.tr('Jour')} ${value.round()}',
                  onChanged: (value) => select(value.round()),
                ),
              ],
            ),
    );
  }
}

class MonthlyCategoryBreakdown extends StatelessWidget {
  final MonthlyAnalytics data;
  final String currency;
  final bool hidden;
  const MonthlyCategoryBreakdown({
    super.key,
    required this.data,
    required this.currency,
    required this.hidden,
  });
  @override
  Widget build(BuildContext context) {
    final categories = [...data.categories.take(5)];
    if (data.categories.length > 5)
      categories.add(
        MonthlyCategoryTotal(
          '__other__',
          context.tr('Autres'),
          data.categories.skip(5).fold(0.0, (total, row) => total + row.amount),
        ),
      );
    return MonthlyStatsPanel(
      title: 'Où part votre budget ?',
      icon: Icons.category_outlined,
      subtitle: context.tr(
        'Les principaux postes de dépenses du mois sélectionné.',
      ),
      child: categories.isEmpty
          ? Text(context.tr('Aucune dépense ce mois-ci.'))
          : Column(
              children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Text(
                              category.name.isEmpty
                                  ? context.tr('Sans catégorie')
                                  : category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_money(context, category.amount, currency, hidden)} · ${hidden ? '**' : (category.amount / data.current.expense * 100).toStringAsFixed(1)} %',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: hidden
                              ? 1
                              : category.amount / data.current.expense,
                          minHeight: 5,
                          color: hidden
                              ? _muted(context).withValues(alpha: .2)
                              : Theme.of(context).colorScheme.primary,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class MonthlyHabits extends StatelessWidget {
  final MonthlyAnalytics data;
  final String currency;
  final bool hidden;
  const MonthlyHabits({
    super.key,
    required this.data,
    required this.currency,
    required this.hidden,
  });
  @override
  Widget build(BuildContext context) => MonthlyStatsPanel(
    title: 'Vos habitudes du mois',
    icon: Icons.insights_outlined,
    subtitle: context.tr('Selon les opérations enregistrées sur la période.'),
    child: data.operations.isEmpty
        ? Text(context.tr('Aucune opération enregistrée sur cette période.'))
        : AppMetricGrid(
            children: [
              for (final item in [
                (
                  'Dépense moyenne / jour',
                  _money(context, data.dailyAverage, currency, hidden),
                  Icons.calendar_today_outlined,
                ),
                (
                  'Panier moyen',
                  _money(context, data.averagePurchase, currency, hidden),
                  Icons.shopping_bag_outlined,
                ),
                (
                  'Jours sans dépense',
                  hidden
                      ? '••'
                      : '${data.daysWithoutExpense} / ${data.elapsedDays}',
                  Icons.event_available_outlined,
                ),
                (
                  'Nombre de dépenses',
                  hidden ? '••' : '${data.expenseCount}',
                  Icons.receipt_long_outlined,
                ),
              ])
                AppMetricCard(
                  label: context.tr(item.$1),
                  value: item.$2,
                  icon: item.$3,
                  color: hidden
                      ? _muted(context)
                      : Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
  );
}

class MonthlyOperationRanking extends StatefulWidget {
  final MonthlyAnalytics data;
  final String currency;
  final bool hidden;
  const MonthlyOperationRanking({
    super.key,
    required this.data,
    required this.currency,
    required this.hidden,
  });
  @override
  State<MonthlyOperationRanking> createState() =>
      _MonthlyOperationRankingState();
}

class _MonthlyOperationRankingState extends State<MonthlyOperationRanking> {
  String _type = 'expense';
  MonthlyOperationOrder _order = MonthlyOperationOrder.amount;
  @override
  Widget build(BuildContext context) {
    final rows = widget.data.ranked(_type, _order);
    return MonthlyStatsPanel(
      title: 'Opérations à la loupe',
      icon: Icons.manage_search,
      subtitle: context.tr('Les 5 opérations principales selon le tri choisi.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, bounds) {
              final fields = [
                AppSelectField<String>(
                  key: const ValueKey('monthly-operation-type'),
                  label: context.tr('Type'),
                  icon: Icons.swap_vert,
                  value: _type,
                  options: [
                    AppSelectOption(
                      value: 'expense',
                      label: context.tr('Dépenses'),
                    ),
                    AppSelectOption(
                      value: 'income',
                      label: context.tr('Revenus'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                AppSelectField<MonthlyOperationOrder>(
                  key: const ValueKey('monthly-operation-order'),
                  label: context.tr('Trier par'),
                  icon: Icons.sort,
                  value: _order,
                  options: [
                    AppSelectOption(
                      value: MonthlyOperationOrder.amount,
                      label: context.tr('Montant décroissant'),
                    ),
                    AppSelectOption(
                      value: MonthlyOperationOrder.latest,
                      label: context.tr('Plus récentes'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _order = value);
                  },
                ),
              ];
              if (bounds.maxWidth < 620 ||
                  MediaQuery.textScalerOf(context).scale(14) > 22)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [fields[0], const SizedBox(height: 12), fields[1]],
                );
              return Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 12),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(context.tr('Aucune opération enregistrée sur cette période.')),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Text(
                        row.description.trim().isNotEmpty
                            ? row.description
                            : context.tr(
                                _type == 'expense' ? 'Dépense' : 'Revenu',
                              ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _money(
                          context,
                          row.amount,
                          widget.currency,
                          widget.hidden,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(row.date),
                    style: TextStyle(fontSize: 12, color: _muted(context)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
