import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'app_charts.dart';

class AnnualFlowSeries {
  final String label;
  final List<double> values;
  final Color color;
  final bool dashed;
  const AnnualFlowSeries({
    required this.label,
    required this.values,
    required this.color,
    this.dashed = false,
  }) : assert(values.length == 12);
}

/// Show the whole year without horizontal scrolling. Narrow layouts use two
/// semesters with a shared Y scale; exact values stay outside the plot.
class AnnualFlowChart extends StatefulWidget {
  final int year;
  final String currency, locale;
  final List<AnnualFlowSeries> series;
  const AnnualFlowChart({
    super.key,
    required this.year,
    required this.currency,
    required this.locale,
    required this.series,
  }) : assert(series.length > 0);

  @override
  State<AnnualFlowChart> createState() => _AnnualFlowChartState();
}

class _MoveMonth extends Intent {
  final int delta;
  const _MoveMonth(this.delta);
}

class _AnnualFlowChartState extends State<AnnualFlowChart> {
  late int _selected = _initialMonth();
  bool _focused = false;

  int _initialMonth() =>
      widget.year == DateTime.now().year ? DateTime.now().month - 1 : 0;

  @override
  void didUpdateWidget(covariant AnnualFlowChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year) _selected = _initialMonth();
  }

  void _select(int index) {
    if (_selected != index) setState(() => _selected = index);
  }

  String _month(int index, {bool short = false}) =>
      (short ? DateFormat.MMM(widget.locale) : DateFormat.MMMM(widget.locale))
          .format(DateTime(widget.year, index + 1));

  String _money(double value) => NumberFormat.currency(
    locale: widget.locale,
    symbol: widget.currency,
  ).format(value);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final values = widget.series.expand((series) => series.values);
    final low = values.fold(0.0, math.min);
    final high = values.fold(0.0, math.max);
    final range = math.max(1.0, high - low);
    final minY = low < 0 ? low - range * .1 : 0.0;
    final maxY = high + range * .12;
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(10) > 15;
        final monthsPerPlot = largeText && constraints.maxWidth < 520
            ? 3
            : constraints.maxWidth < 640 || largeText
            ? 6
            : 12;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                for (final series in widget.series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        series.dashed
                            ? Icons.more_horiz
                            : Icons.horizontal_rule,
                        size: 20,
                        color: series.color,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          series.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label: context.tr('Évolution mensuelle'),
              value: '${_month(_selected)} ${widget.year}',
              increasedValue: _selected < 11
                  ? '${_month(_selected + 1)} ${widget.year}'
                  : null,
              decreasedValue: _selected > 0
                  ? '${_month(_selected - 1)} ${widget.year}'
                  : null,
              onIncrease: _selected < 11 ? () => _select(_selected + 1) : null,
              onDecrease: _selected > 0 ? () => _select(_selected - 1) : null,
              child: FocusableActionDetector(
                onShowFocusHighlight: (value) =>
                    setState(() => _focused = value),
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveMonth(-1),
                  SingleActivator(LogicalKeyboardKey.arrowRight): _MoveMonth(1),
                },
                actions: {
                  _MoveMonth: CallbackAction<_MoveMonth>(
                    onInvoke: (intent) {
                      _select((_selected + intent.delta).clamp(0, 11));
                      return null;
                    },
                  ),
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _focused ? colors.primary : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      for (
                        var first = 0;
                        first < 12;
                        first += monthsPerPlot
                      ) ...[
                        if (first > 0) const SizedBox(height: 16),
                        if (monthsPerPlot < 12)
                          _periodTitle(first, first + monthsPerPlot - 1),
                        _plot(first, first + monthsPerPlot - 1, minY, maxY),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('Touchez ou survolez un mois pour voir les montants.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('annual-flow-detail'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_month(_selected)} ${widget.year}',
                    key: const ValueKey('annual-flow-selected-month'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, details) {
                      final columns =
                          MediaQuery.textScalerOf(context).scale(12) > 18
                          ? 1
                          : details.maxWidth >= 720
                          ? 4
                          : details.maxWidth >= 200
                          ? 2
                          : 1;
                      final width =
                          (details.maxWidth - 12 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 16,
                        children: [
                          for (final series in widget.series)
                            SizedBox(
                              width: width,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    series.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _money(series.values[_selected]),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: series.color,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _periodTitle(int first, int last) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      '${_month(first)} – ${_month(last)}',
      style: Theme.of(context).textTheme.labelMedium,
    ),
  );

  Widget _plot(int first, int last, double minY, double maxY) {
    final colors = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final axisWidth = 40 * scale;
    final bottomHeight = 28 * scale;
    return SizedBox(
      key: ValueKey('annual-flow-plot-$first'),
      height: 200 + bottomHeight,
      child: LayoutBuilder(
        builder: (context, bounds) {
          void select(Offset position) {
            final plotWidth = bounds.maxWidth - axisWidth - 16;
            if (plotWidth <= 0 ||
                position.dx < axisWidth ||
                position.dx > bounds.maxWidth - 16 ||
                position.dy > bounds.maxHeight - bottomHeight)
              return;
            _select(
              first +
                  ((position.dx - axisWidth) / plotWidth * (last - first))
                      .round()
                      .clamp(0, last - first),
            );
          }

          return MouseRegion(
            cursor: SystemMouseCursors.precise,
            onHover: (event) => select(event.localPosition),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => select(event.localPosition),
              onPointerMove: (event) => select(event.localPosition),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: AppLineChart(
                  LineChartData(
                    minX: first.toDouble(),
                    maxX: last.toDouble(),
                    minY: minY,
                    maxY: maxY,
                    clipData: FlClipData.all(),
                    lineTouchData: LineTouchData(enabled: false),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: (maxY - minY) / 4,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: colors.outlineVariant.withValues(alpha: .5),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: minY < 0
                          ? [
                              HorizontalLine(
                                y: 0,
                                color: colors.onSurfaceVariant,
                                strokeWidth: 1,
                              ),
                            ]
                          : [],
                      verticalLines: _selected >= first && _selected <= last
                          ? [
                              VerticalLine(
                                x: _selected.toDouble(),
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: .6,
                                ),
                                strokeWidth: 1,
                                dashArray: [3, 3],
                              ),
                            ]
                          : [],
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
                          reservedSize: axisWidth,
                          interval: (maxY - minY) / 4,
                          getTitlesWidget: (value, _) => Text(
                            NumberFormat.compact(
                              locale: widget.locale,
                            ).format(value),
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
                          interval: 1,
                          reservedSize: bottomHeight,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            axisSide: meta.axisSide,
                            fitInside: SideTitleFitInsideData.fromTitleMeta(
                              meta,
                              enabled: true,
                            ),
                            child: Text(
                              _month(
                                value.round().clamp(first, last),
                                short: true,
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    lineBarsData: [
                      for (final series in widget.series)
                        LineChartBarData(
                          spots: [
                            for (var month = first; month <= last; month++)
                              FlSpot(month.toDouble(), series.values[month]),
                          ],
                          color: series.color,
                          barWidth: 2.5,
                          isCurved: false,
                          dashArray: series.dashed ? [6, 4] : null,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, _, bar, __) =>
                                FlDotCirclePainter(
                                  radius: spot.x == _selected ? 4 : 2,
                                  color: series.color,
                                  strokeWidth: 0,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
