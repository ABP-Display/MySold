import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/graphiques/app_charts.dart';
import 'package:mysold/widgets/graphiques/chart_pointer_region.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';

class EntityAnnualChart extends StatefulWidget {
  final List<double?> values;
  final int year;
  final String currency;
  final bool hidden, zeroBased;
  const EntityAnnualChart({
    super.key,
    required this.values,
    required this.year,
    required this.currency,
    required this.hidden,
    this.zeroBased = false,
  });
  @override
  State<EntityAnnualChart> createState() => _EntityAnnualChartState();
}

class _SelectMonth extends Intent {
  final int step;
  const _SelectMonth(this.step);
}

class _EntityAnnualChartState extends State<EntityAnnualChart> {
  late final ValueNotifier<int> _month;
  bool _focused = false;
  List<int> get _available => [
    for (var i = 0; i < math.min(12, widget.values.length); i++)
      if (widget.values[i] != null) i + 1,
  ];

  @override
  void initState() {
    super.initState();
    _month = ValueNotifier(_available.lastOrNull ?? 1);
  }

  @override
  void didUpdateWidget(covariant EntityAnnualChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || !_available.contains(_month.value)) {
      _month.value = _available.lastOrNull ?? 1;
    }
  }

  void _select(int target) {
    final available = _available;
    if (available.isEmpty) return;
    final closest = available.reduce(
      (a, b) => (a - target).abs() <= (b - target).abs() ? a : b,
    );
    if (closest != _month.value) _month.value = closest;
  }

  void _step(int step) {
    final available = _available;
    if (available.isEmpty) return;
    final index = (available.indexOf(_month.value) + step).clamp(
      0,
      available.length - 1,
    );
    _select(available[index]);
  }

  @override
  void dispose() {
    _month.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hidden) return const PrivacyChartMask(height: 290);
    if (_available.isEmpty)
      return SizedBox(
        height: 260,
        child: Center(
          child: Text(
            context.tr('Historique insuffisant pour tracer une courbe.'),
          ),
        ),
      );
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final values = widget.values.whereType<double>();
    final low = widget.zeroBased
        ? math.min(0.0, values.reduce(math.min))
        : values.reduce(math.min);
    final high = values.reduce(math.max);
    final padding = math.max(1.0, (high - low) * .12);
    final minY = widget.zeroBased && low == 0 ? 0.0 : low - padding;
    final maxY = high + padding;
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final axisWidth = scale > 1.5 ? 0.0 : 48 * scale;
    final bottomHeight = 30 * scale;
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _SelectMonth(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _SelectMonth(1),
      },
      actions: {
        _SelectMonth: CallbackAction<_SelectMonth>(
          onInvoke: (intent) {
            _step(intent.step);
            return null;
          },
        ),
      },
      child: ValueListenableBuilder<int>(
        valueListenable: _month,
        builder: (context, month, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                height: MediaQuery.textScalerOf(context).scale(24) * 2.5,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat.yMMMM(
                          locale,
                        ).format(DateTime(widget.year, month)),
                        key: const ValueKey('entity-chart-month'),
                        maxLines: 2,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        NumberFormat.currency(
                          locale: locale,
                          symbol: widget.currency,
                          decimalDigits: 2,
                        ).format(widget.values[month - 1]),
                        key: const ValueKey('entity-chart-value'),
                        maxLines: 2,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, bounds) {
                final step = bounds.maxWidth >= 700 && scale <= 1.5 ? 1 : 3;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    border: _focused ? Border.all(color: colors.primary) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox(
                    height: 230 + bottomHeight,
                    key: const ValueKey('entity-annual-plot'),
                    child: LayoutBuilder(
                      builder: (context, area) {
                        void select(Offset offset) {
                          final width = area.maxWidth - axisWidth - 16;
                          if (width <= 0 ||
                              offset.dx < axisWidth ||
                              offset.dx > area.maxWidth - 16 ||
                              offset.dy > area.maxHeight - bottomHeight)
                            return;
                          _select(
                            1 + ((offset.dx - axisWidth) / width * 11).round(),
                          );
                        }

                        return Semantics(
                          identifier: 'entity-annual-plot',
                          label: context.tr('Évolution annuelle'),
                          child: RepaintBoundary(
                            child: ChartPointerRegion(
                              onSelect: select,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: AppLineChart(
                                  LineChartData(
                                    minX: 1,
                                    maxX: 12,
                                    minY: minY,
                                    maxY: maxY,
                                    clipData: const FlClipData.all(),
                                    lineTouchData: const LineTouchData(
                                      enabled: false,
                                    ),
                                    borderData: FlBorderData(show: false),
                                    gridData: FlGridData(
                                      drawVerticalLine: false,
                                      horizontalInterval: (maxY - minY) / 4,
                                      getDrawingHorizontalLine: (_) => FlLine(
                                        color: colors.outlineVariant.withValues(
                                          alpha: .4,
                                        ),
                                        strokeWidth: 1,
                                        dashArray: [4, 4],
                                      ),
                                    ),
                                    extraLinesData: ExtraLinesData(
                                      verticalLines: [
                                        VerticalLine(
                                          x: month.toDouble(),
                                          color: colors.onSurfaceVariant
                                              .withValues(alpha: .45),
                                          strokeWidth: 1,
                                          dashArray: [3, 4],
                                        ),
                                      ],
                                    ),
                                    titlesData: FlTitlesData(
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: axisWidth > 0,
                                          reservedSize: axisWidth,
                                          interval: (maxY - minY) / 4,
                                          getTitlesWidget: (value, _) {
                                            if (value <= minY + 1e-6 ||
                                                value >= maxY - 1e-6)
                                              return const SizedBox.shrink();
                                            return Text(
                                              NumberFormat.compact(
                                                locale: locale,
                                              ).format(value),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 1,
                                          reservedSize: bottomHeight,
                                          getTitlesWidget: (value, meta) {
                                            final m = value.round();
                                            if (m < 1 ||
                                                m > 12 ||
                                                (m != 1 &&
                                                    m != 12 &&
                                                    (m - 1) % step != 0))
                                              return const SizedBox.shrink();
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(
                                                DateFormat.MMM(locale).format(
                                                  DateTime(widget.year, m),
                                                ),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: [
                                          for (final m in _available)
                                            FlSpot(
                                              m.toDouble(),
                                              widget.values[m - 1]!,
                                            ),
                                        ],
                                        color: colors.primary,
                                        barWidth: 2.5,
                                        dotData: FlDotData(
                                          show: true,
                                          checkToShowDot: (spot, _) =>
                                              spot.x.round() == month,
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: colors.primary.withValues(
                                            alpha: .06,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
