import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/investment_type.dart';
import 'package:mysold/models/month_chart_data.dart';
import 'app_charts.dart';
import 'month_chart_style.dart';

class MonthInvestmentChart extends StatelessWidget {
  final MonthChartData data;
  final String currency;
  final int? selectedWeek;
  final ValueChanged<int?> onWeekChanged;
  const MonthInvestmentChart({
    super.key,
    required this.data,
    required this.currency,
    required this.selectedWeek,
    required this.onWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final week = selectedWeek == null ? null : data.weeks[selectedWeek!];
    final values = week == null
        ? [for (final w in data.weeks) w.amounts]
        : [
            for (final d in week.days)
              data.investmentDays[d.day] ?? const <String, int>{},
          ];
    final totals = [
      for (final value in values) value.values.fold(0, (a, b) => a + b),
    ];
    final total = totals.fold(0, (a, b) => a + b);
    final tooltips = [
      for (var i = 0; i < values.length; i++) GlobalKey<TooltipState>(),
    ];
    final groups = [
      for (final type in chartInvestmentTypes)
        if (values.any((v) => (v[type] ?? 0) > 0)) type,
    ];
    final colors = Theme.of(context).colorScheme;
    final smallDate = DateFormat.MMMd(locale);
    String range(InvestmentWeek w) =>
        '${smallDate.format(w.start)} – ${smallDate.format(w.end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (week != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('investment-back-month'),
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: () => onWeekChanged(null),
              label: Text(context.tr('Retour au mois')),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              week == null ? context.tr('Versements par semaine') : range(week),
              key: const ValueKey('investment-period'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              monthChartMoney(context, total, currency),
              key: const ValueKey('investment-period-total'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, bounds) {
            final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
            final axisWidth = largeText ? 0.0 : 44.0;
            final bottom = math.max(
              32.0,
              MediaQuery.textScalerOf(context).scale(11) * 1.5 + 8,
            );
            const right = 12.0;
            final maximum = totals.fold(0, math.max) / 100;
            final rough = math.max(.01, maximum / 4);
            final magnitude = math
                .pow(10, (math.log(rough) / math.ln10).floor())
                .toDouble();
            final interval = maximum == 0
                ? .25
                : math.max(
                    .01,
                    [1, 2, 5, 10].firstWhere((n) => n * magnitude >= rough) *
                        magnitude,
                  );
            final maxY = maximum == 0
                ? 1.0
                : (maximum / interval).ceil() * interval + interval * .3;
            final barWidth = math.min(
              42.0,
              math.max(
                8.0,
                (bounds.maxWidth - axisWidth - right) / values.length * .48,
              ),
            );
            final rods = <BarChartGroupData>[];
            for (var i = 0; i < values.length; i++) {
              double from = 0;
              final stacks = <BarChartRodStackItem>[];
              for (final type in groups) {
                final next = from + (values[i][type] ?? 0) / 100;
                if (next > from)
                  stacks.add(
                    BarChartRodStackItem(
                      from,
                      next,
                      investmentChartColor(type),
                    ),
                  );
                from = next;
              }
              rods.add(
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: from,
                      width: barWidth,
                      color: colors.outlineVariant,
                      rodStackItems: stacks,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            }
            Widget amountLabel(int i) => ExcludeSemantics(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, area) => Stack(
                    children: [
                      Positioned(
                        left: 2,
                        right: 2,
                        top: math.max(
                          0,
                          area.maxHeight * (1 - totals[i] / 100 / maxY) - 18,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            NumberFormat.compact(
                              locale: locale,
                            ).format(totals[i] / 100),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            return SizedBox(
              height: 232 + bottom,
              child: Stack(
                children: [
                  Positioned.fill(
                    right: right,
                    child: AppBarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        minY: 0,
                        maxY: maxY,
                        barGroups: rods,
                        barTouchData: BarTouchData(enabled: false),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: interval,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: colors.outlineVariant.withValues(alpha: .35),
                            dashArray: [4, 4],
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: axisWidth > 0,
                              reservedSize: axisWidth,
                              interval: interval,
                              getTitlesWidget: (v, _) => v >= maxY - 1e-6
                                  ? const SizedBox.shrink()
                                  : Text(
                                      NumberFormat.compact(
                                        locale: locale,
                                      ).format(v),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: bottom,
                              interval: 1,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= values.length)
                                  return const SizedBox.shrink();
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(
                                    week == null
                                        ? (largeText
                                              ? '${i + 1}'
                                              : context.trParams('S{number}', {
                                                  'number': i + 1,
                                                }))
                                        : (bounds.maxWidth < 500
                                              ? '${week.days[i].day}'
                                              : DateFormat.E(
                                                  locale,
                                                ).format(week.days[i])),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    left: axisWidth,
                    right: right,
                    bottom: bottom,
                    child: Row(
                      children: [
                        for (var i = 0; i < values.length; i++)
                          Expanded(
                            child: week == null
                                ? Semantics(
                                    button: true,
                                    label:
                                        '${context.trParams('Semaine {number}', {'number': i + 1})}, ${range(data.weeks[i])}, ${monthChartMoney(context, totals[i], currency)}',
                                    child: Tooltip(
                                      message:
                                          '${range(data.weeks[i])} · ${monthChartMoney(context, totals[i], currency)}',
                                      child: GestureDetector(
                                        key: ValueKey('investment-week-$i'),
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => onWeekChanged(i),
                                        child: amountLabel(i),
                                      ),
                                    ),
                                  )
                                : Tooltip(
                                    key: tooltips[i],
                                    message:
                                        '${DateFormat.yMMMMEEEEd(locale).format(week.days[i])} · ${monthChartMoney(context, totals[i], currency)}\n${groups.where((type) => (values[i][type] ?? 0) > 0).map((type) => '${context.tr(investmentTypeOption(type).label)} : ${monthChartMoney(context, values[i][type]!, currency)}').join('\n')}',
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => tooltips[i].currentState
                                          ?.ensureTooltipVisible(),
                                      child: Semantics(
                                        label:
                                            '${smallDate.format(week.days[i])}, ${monthChartMoney(context, totals[i], currency)}',
                                        child: amountLabel(i),
                                      ),
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            for (final type in groups)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: investmentChartColor(type),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.tr(investmentTypeOption(type).label),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      monthChartMoney(
                        context,
                        values.fold(0, (sum, v) => sum + (v[type] ?? 0)),
                        currency,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
