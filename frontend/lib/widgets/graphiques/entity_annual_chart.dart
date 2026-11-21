import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/graphiques/app_charts.dart';
import 'package:mysold/widgets/graphiques/chart_pointer_region.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';
import 'package:mysold/widgets/app_design.dart';

class EntityAnnualChart extends StatefulWidget {
  final List<double?> values;
  final int year;
  final String currency;
  final bool hidden, zeroBased;
  final double? opening;
  const EntityAnnualChart({
    super.key,
    required this.values,
    required this.year,
    required this.currency,
    required this.hidden,
    this.zeroBased = false,
    this.opening,
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
  bool get _hasOpening => widget.opening?.isFinite == true;
  int get _start => _hasOpening ? 0 : 1;
  double? _value(int month) => month == 0
      ? (_hasOpening ? widget.opening : null)
      : month <= widget.values.length
      ? widget.values[month - 1]
      : null;
  List<int> get _available => [
    if (_hasOpening) 0,
    for (var i = 0; i < math.min(12, widget.values.length); i++)
      if (widget.values[i]?.isFinite == true) i + 1,
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
    final values = _available.map((month) => _value(month)!);
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
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _legend(context, 'Évolution annuelle', colors.primary, false),
                if (_hasOpening)
                  _legend(
                    context,
                    'Au 1er janvier',
                    colors.onSurfaceVariant,
                    true,
                  ),
              ],
            ),
            const SizedBox(height: 14),
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
                            _start +
                                ((offset.dx - axisWidth) /
                                        width *
                                        (12 - _start))
                                    .round(),
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
                                    minX: _start.toDouble(),
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
                                            if (_hasOpening && m == 0) {
                                              return SideTitleWidget(
                                                axisSide: meta.axisSide,
                                                child: Text(
                                                  DateFormat.Md(locale).format(
                                                    DateTime(widget.year, 1, 1),
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        colors.onSurfaceVariant,
                                                  ),
                                                ),
                                              );
                                            }
                                            if (m < 1 ||
                                                m > 12 ||
                                                (_hasOpening &&
                                                    step > 1 &&
                                                    m % 3 != 0) ||
                                                (_hasOpening && m == 1) ||
                                                (!_hasOpening &&
                                                    m != 1 &&
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
                                      if (_hasOpening)
                                        LineChartBarData(
                                          spots: [
                                            FlSpot(
                                              _start.toDouble(),
                                              widget.opening!,
                                            ),
                                            FlSpot(12, widget.opening!),
                                          ],
                                          color: colors.onSurfaceVariant,
                                          barWidth: 1.5,
                                          dashArray: [5, 4],
                                          dotData: const FlDotData(show: false),
                                        ),
                                      LineChartBarData(
                                        spots: [
                                          for (
                                            var m = _start;
                                            m <= _available.last;
                                            m++
                                          )
                                            _value(m)?.isFinite == true
                                                ? FlSpot(
                                                    m.toDouble(),
                                                    _value(m)!,
                                                  )
                                                : FlSpot.nullSpot,
                                        ],
                                        color: colors.primary,
                                        barWidth: 2.5,
                                        dotData: FlDotData(
                                          show: true,
                                          checkToShowDot: (spot, _) =>
                                              spot.x.isFinite &&
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
            const SizedBox(height: 14),
            _readout(context, month, locale),
          ],
        ),
      ),
    );
  }

  Widget _legend(
    BuildContext context,
    String label,
    Color color,
    bool dashed,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        dashed ? Icons.more_horiz : Icons.horizontal_rule,
        color: color,
        size: 20,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          context.tr(label),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );

  Widget _readout(BuildContext context, int month, String locale) {
    final colors = Theme.of(context).colorScheme;
    final date = month == 0
        ? context.trParams('Valeur au 1er janvier {year}', {
            'year': widget.year,
          })
        : DateFormat.yMMMM(locale).format(DateTime(widget.year, month));
    String money(double value) => NumberFormat.currency(
      locale: locale,
      symbol: widget.currency,
      decimalDigits: 2,
    ).format(value);
    final delta = _hasOpening
        ? ((_value(month)! - widget.opening!) * 100).round() / 100
        : null;
    final percent = delta != null && widget.opening! > 0
        ? NumberFormat.decimalPercentPattern(
            locale: locale,
            decimalDigits: 1,
          ).format(delta / widget.opening!)
        : null;
    return Container(
      key: const ValueKey('entity-chart-detail'),
      padding: const EdgeInsets.all(14),
      decoration: AppDesign.panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            date,
            key: const ValueKey('entity-chart-month'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, bounds) {
              final stacked =
                  bounds.maxWidth < 250 ||
                  MediaQuery.textScalerOf(context).scale(12) > 18;
              Widget cell(String label, String value, {Key? key}) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(label),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    key: key,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
              final current = cell(
                widget.zeroBased ? 'Montant cumulé' : 'Solde',
                money(_value(month)!),
                key: const ValueKey('entity-chart-value'),
              );
              final opening = _hasOpening
                  ? cell('Au 1er janvier', money(widget.opening!))
                  : null;
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        current,
                        if (opening != null) ...[
                          const SizedBox(height: 12),
                          opening,
                        ],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: current),
                        if (opening != null) ...[
                          const SizedBox(width: 12),
                          Expanded(child: opening),
                        ],
                      ],
                    );
            },
          ),
          if (delta != null) ...[
            const SizedBox(height: 12),
            Text(
              '${context.tr('Variation depuis le 1er janvier')} : ${delta > 0 ? '+' : ''}${money(delta)}${percent == null ? '' : ' ($percent)'}',
              key: const ValueKey('entity-chart-delta'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: widget.zeroBased || delta == 0
                    ? colors.onSurface
                    : delta > 0
                    ? Colors.green.shade600
                    : colors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
