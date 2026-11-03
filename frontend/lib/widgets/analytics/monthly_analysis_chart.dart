import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/models/stats_year.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/app_selection_button.dart';
import 'package:mysold/widgets/graphiques/annual_flow_chart.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';
import 'monthly_analytics_sections.dart';

const _labels = {
  MonthlySeries.income: 'Revenus',
  MonthlySeries.expense: 'Dépenses',
  MonthlySeries.investment: 'Investissements',
  MonthlySeries.remaining: 'Reste',
  MonthlySeries.transfer: 'Transferts',
};
const _icons = {
  MonthlySeries.income: Icons.south_west,
  MonthlySeries.expense: Icons.north_east,
  MonthlySeries.investment: Icons.trending_up,
  MonthlySeries.remaining: Icons.payments_outlined,
  MonthlySeries.transfer: Icons.swap_horiz,
};

class MonthlyAnalysisChart extends StatefulWidget {
  final StatsYear data;
  final String currency;
  final bool hidden;
  final ValueChanged<bool> onSameDay;
  const MonthlyAnalysisChart({
    super.key,
    required this.data,
    required this.currency,
    required this.hidden,
    required this.onSameDay,
  });
  @override
  State<MonthlyAnalysisChart> createState() => _MonthlyAnalysisChartState();
}

class _MonthlyAnalysisChartState extends State<MonthlyAnalysisChart> {
  MonthlySeries _series = MonthlySeries.expense;
  bool _daily = false;
  Widget _option(
    String label,
    bool selected,
    VoidCallback onTap, {
    bool enabled = true,
    Key? key,
  }) {
    if (!enabled)
      return Semantics(
        button: true,
        enabled: false,
        label: context.tr(label),
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.center,
          child: Text(
            context.tr(label),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .35),
            ),
          ),
        ),
      );
    return Semantics(
      container: true,
      child: AppSelectionButton(
        key: key,
        selected: selected,
        onPressed: onTap,
        minHeight: 48,
        child: Center(
          child: Text(context.tr(label), textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _pair(String label, Widget first, Widget second) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr(label),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium,
      ),
      const SizedBox(height: 8),
      Container(
        decoration: AppDesign.panel(context),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 4),
            Expanded(child: second),
          ],
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final data = widget.data, colors = Theme.of(context).colorScheme;
    final sameAllowed = data.year == data.now.year;
    final current = data.values(_series, dailyAverage: _daily);
    final previous = data.values(_series, previous: true, dailyAverage: _daily);
    final color = _series == MonthlySeries.income
        ? Colors.green.shade600
        : _series == MonthlySeries.expense
        ? colors.error
        : colors.primary;
    return MonthlyStatsPanel(
      title: 'Analyse face à M−1',
      icon: Icons.query_stats,
      subtitle: context.tr(
        'Les douze mois de l’année, comparés au mois précédent.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final period = _pair(
                    'Période comparée',
                    _option(
                      'Mois complets',
                      !data.sameDay,
                      () => widget.onSameDay(false),
                      key: const ValueKey('comparison-full-month'),
                    ),
                    _option(
                      'À date égale',
                      data.sameDay,
                      () => widget.onSameDay(true),
                      enabled: sameAllowed,
                      key: const ValueKey('comparison-same-day'),
                    ),
                  );
                  final reading = _pair(
                    'Lecture du graphique',
                    _option(
                      'Cumulé',
                      !_daily,
                      () => setState(() => _daily = false),
                      key: const ValueKey('analysis-cumulative'),
                    ),
                    _option(
                      'Par jour',
                      _daily,
                      () => setState(() => _daily = true),
                      key: const ValueKey('analysis-daily'),
                    ),
                  );
                  if (bounds.maxWidth < 680 ||
                      MediaQuery.textScalerOf(context).scale(14) > 21)
                    return Column(
                      children: [period, const SizedBox(height: 16), reading],
                    );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: period),
                      const SizedBox(width: 20),
                      Expanded(child: reading),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              data.sameDay
                  ? 'Le mois en cours et M−1 sont arrêtés au même jour ; les mois terminés restent complets.'
                  : sameAllowed
                  ? 'Le mois en cours est incomplet ; M−1 est affiché en entier.'
                  : 'Année terminée : comparaison de mois complets.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, bounds) {
              final wide =
                  bounds.maxWidth >= 900 &&
                  MediaQuery.textScalerOf(context).scale(12) < 19;
              final width = wide
                  ? (bounds.maxWidth - 32) / 5
                  : (bounds.maxWidth - 8) /
                        (MediaQuery.textScalerOf(context).scale(12) > 20
                            ? 1
                            : 2);
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final series in const [
                    MonthlySeries.income,
                    MonthlySeries.expense,
                    MonthlySeries.investment,
                    MonthlySeries.transfer,
                    MonthlySeries.remaining,
                  ])
                    SizedBox(
                      width: width,
                      child: Semantics(
                        container: true,
                        child: AppSelectionButton(
                          key: ValueKey('analysis-${series.name}'),
                          selected: _series == series,
                          onPressed: () => setState(() => _series = series),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_icons[series], size: 19),
                              const SizedBox(height: 6),
                              Text(
                                context.tr(_labels[series]!),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            '${context.tr(_labels[_series]!)} · ${context.tr(_daily ? 'Moyenne quotidienne' : 'Total mensuel')}',
            textAlign: TextAlign.center,
            key: const ValueKey('year-analysis-series'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (_series == MonthlySeries.transfer) ...[
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Les transferts sont suivis séparément et ne modifient pas le reste.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          if (widget.hidden)
            const PrivacyChartMask(height: 280)
          else
            AnnualFlowChart(
              year: data.year,
              currency: widget.currency,
              locale: Localizations.localeOf(context).toString(),
              availableMonths: data.months
                  .map((month) => !month.isFuture)
                  .toList(),
              series: [
                AnnualFlowSeries(
                  label: '${data.year}',
                  values: current.map((v) => v ?? 0).toList(),
                  color: color,
                ),
                AnnualFlowSeries(
                  label: context.tr('Mois M−1'),
                  values: previous.map((v) => v ?? 0).toList(),
                  color: colors.onSurfaceVariant,
                  dashed: true,
                ),
              ],
              detailFooter: (context, index) {
                final month = data.months[index];
                if (month.isFuture) return Text(context.tr('Mois à venir'));
                final locale = Localizations.localeOf(context).toString();
                final count = month.dailyCount.fold(0, (a, b) => a + b),
                    oldCount = month.previousDailyCount.fold(
                      0,
                      (a, b) => a + b,
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'M−1 : ${DateFormat.yMMMM(locale).format(month.previousMonth)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${context.tr('Opérations enregistrées')} : $count / M−1 : $oldCount',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
