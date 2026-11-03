import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/models/month_comparison.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/app_selection_button.dart';
import 'package:mysold/widgets/graphiques/app_charts.dart';
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
  final MonthComparison data;
  final VoidCallback? onChooseReference, onResetReference;
  final String currency;
  final bool hidden;
  final MonthlySeries initialSeries;
  final bool initialCumulative;
  final ValueChanged<MonthlySeries>? onSeriesChanged;
  final ValueChanged<bool>? onCumulativeChanged;
  const MonthlyAnalysisChart({
    super.key,
    required this.data,
    required this.currency,
    required this.hidden,
    this.initialSeries = MonthlySeries.expense,
    this.initialCumulative = true,
    this.onSeriesChanged,
    this.onCumulativeChanged,
    this.onChooseReference,
    this.onResetReference,
  });
  @override
  State<MonthlyAnalysisChart> createState() => _MonthlyAnalysisChartState();
}

class _MoveDay extends Intent {
  final int delta;
  const _MoveDay(this.delta);
}

class _MonthlyAnalysisChartState extends State<MonthlyAnalysisChart> {
  late MonthlySeries _series = widget.initialSeries;
  late bool _cumulative = widget.initialCumulative;
  bool _focused = false;
  late final ValueNotifier<int> _selection;
  int get _day => _selection.value;
  @override
  void initState() {
    super.initState();
    _selection = ValueNotifier(math.max(1, widget.data.elapsedDays));
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  int get _lastDay =>
      math.max(1, math.max(widget.data.elapsedDays, widget.data.previousDays));
  @override
  void didUpdateWidget(covariant MonthlyAnalysisChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selection.value =
        (oldWidget.data.month != widget.data.month ||
            oldWidget.data.previousMonth != widget.data.previousMonth)
        ? math.max(1, widget.data.elapsedDays)
        : _day.clamp(1, _lastDay);
  }

  void _select(int day) {
    final selected = day.clamp(1, _lastDay);
    if (_day != selected) _selection.value = selected;
  }

  void _chooseSeries(MonthlySeries value) {
    setState(() => _series = value);
    widget.onSeriesChanged?.call(value);
  }

  void _chooseReading(bool value) {
    setState(() => _cumulative = value);
    widget.onCumulativeChanged?.call(value);
  }

  String get _locale => Localizations.localeOf(context).toString();
  String _month(DateTime date) => DateFormat.yMMM(_locale).format(date);
  String _money(double value) => widget.hidden
      ? '•••• ${widget.currency}'
      : NumberFormat.currency(
          locale: _locale,
          symbol: widget.currency,
        ).format(value);
  Color _color(MonthlySeries series) => switch (series) {
    MonthlySeries.income => Colors.green.shade600,
    MonthlySeries.expense => Theme.of(context).colorScheme.error,
    _ => Theme.of(context).colorScheme.primary,
  };

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
  Widget _monthChoice(
    String label,
    DateTime month,
    VoidCallback? onPressed,
    Key key,
  ) => OutlinedButton(
    onPressed: onPressed,
    key: key,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    child: Row(
      children: [
        const Icon(Icons.calendar_month_outlined, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(label),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 5),
              Text(
                DateFormat.yMMMM(_locale).format(month),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.expand_more, size: 20),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final data = widget.data, colors = Theme.of(context).colorScheme;
    final current = data.values(_series, cumulative: _cumulative);
    final previous = data.values(
      _series,
      previous: true,
      cumulative: _cumulative,
    );
    final color = _color(_series);
    return MonthlyStatsPanel(
      title: 'Comparaison entre deux mois',
      icon: Icons.query_stats,
      subtitle: context.tr(
        'Choisissez un poste pour comparer son évolution et le rythme des transactions.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _monthChoice(
                'Mois de référence',
                data.previousMonth,
                widget.onChooseReference,
                const ValueKey('comparison-month-reference'),
              ),
            ),
          ),
          if (widget.onResetReference != null)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: widget.onResetReference,
                icon: const Icon(Icons.restore, size: 18),
                label: Text(context.tr('Revenir à M−1')),
              ),
            ),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _pair(
                'Lecture du graphique',
                _option(
                  'Cumulé',
                  _cumulative,
                  () => _chooseReading(true),
                  key: const ValueKey('analysis-cumulative'),
                ),
                _option(
                  'Par jour',
                  !_cumulative,
                  () => _chooseReading(false),
                  key: const ValueKey('analysis-daily'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              !data.canCompare
                  ? 'Une des périodes n’a pas encore commencé.'
                  : 'Chaque mois utilise ses journées disponibles ; le mois en cours reste incomplet.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Cumulé : total progressif. Par jour : montant de chaque journée.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, bounds) {
              final large = MediaQuery.textScalerOf(context).scale(12) > 18;
              final columns = large
                  ? (bounds.maxWidth >= 700 ? 2 : 1)
                  : bounds.maxWidth >= 1100
                  ? 5
                  : bounds.maxWidth >= 800
                  ? 3
                  : 2;
              final width = (bounds.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final series in const [
                    MonthlySeries.income,
                    MonthlySeries.expense,
                    MonthlySeries.investment,
                    MonthlySeries.transfer,
                    MonthlySeries.remaining,
                  ])
                    SizedBox(width: width, child: _metric(series)),
                ],
              );
            },
          ),
          if (_series == MonthlySeries.transfer) ...[
            const SizedBox(height: 10),
            Text(
              context.tr(
                'Les transferts sont suivis séparément et ne modifient pas le reste.',
              ),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            '${context.tr(_labels[_series]!)} · ${context.tr(_cumulative ? 'Cumulé' : 'Par jour')}',
            key: const ValueKey('monthly-analysis-series'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          if (widget.hidden)
            const PrivacyChartMask(height: 260)
          else if (!data.hasActivity)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                context.tr('Aucune opération enregistrée sur ces périodes.'),
              ),
            )
          else ...[
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _legend(_month(data.month), color, false),
                _legend(
                  _month(data.previousMonth),
                  colors.onSurfaceVariant,
                  true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Hover/drag rebuild only the plot and its fixed readout.
            ValueListenableBuilder<int>(
              valueListenable: _selection,
              builder: (context, day, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    container: true,
                    label: context.tr('Analyse quotidienne'),
                    value: '${context.tr('Jour')} $_day',
                    increasedValue: _day < _lastDay
                        ? '${context.tr('Jour')} ${_day + 1}'
                        : null,
                    decreasedValue: _day > 1
                        ? '${context.tr('Jour')} ${_day - 1}'
                        : null,
                    onIncrease: _day < _lastDay
                        ? () => _select(_day + 1)
                        : null,
                    onDecrease: _day > 1 ? () => _select(_day - 1) : null,
                    child: FocusableActionDetector(
                      onShowFocusHighlight: (value) =>
                          setState(() => _focused = value),
                      shortcuts: const {
                        SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveDay(
                          -1,
                        ),
                        SingleActivator(LogicalKeyboardKey.arrowRight):
                            _MoveDay(1),
                      },
                      actions: {
                        _MoveDay: CallbackAction<_MoveDay>(
                          onInvoke: (intent) {
                            _select(_day + intent.delta);
                            return null;
                          },
                        ),
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _focused
                                ? colors.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: _plot(current, previous, color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      'Touchez ou survolez un jour pour voir les montants.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _detail(current, previous, color),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(MonthlySeries series) {
    final colors = Theme.of(context).colorScheme;
    final current = widget.data.current.value(series),
        previous = widget.data.previous.value(series);
    final difference = current - previous;
    final neutral =
        series == MonthlySeries.investment || series == MonthlySeries.transfer;
    final good = series == MonthlySeries.expense
        ? difference < 0
        : difference > 0;
    final deltaColor =
        widget.hidden || !widget.data.canCompare || difference == 0 || neutral
        ? colors.onSurfaceVariant
        : good
        ? Colors.green.shade600
        : colors.error;
    return Semantics(
      container: true,
      child: AppSelectionButton(
        key: ValueKey('analysis-${series.name}'),
        selected: _series == series,
        onPressed: () => _chooseSeries(series),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    context.tr(_labels[series]!),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _icons[series],
                  size: 16,
                  color: widget.hidden
                      ? colors.onSurfaceVariant
                      : _color(series),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.data.selected.isFuture ? '—' : _money(current),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              '${_month(widget.data.previousMonth)} : ${widget.data.reference.isFuture ? '—' : _money(previous)}',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Text(
              !widget.data.canCompare
                  ? '${context.tr('Écart')} : —'
                  : '${context.tr('Écart')} : ${!widget.hidden && difference > 0 ? '+' : ''}${_money(difference)}${widget.hidden || previous == 0 ? '' : ' (${NumberFormat.decimalPercentPattern(locale: _locale, decimalDigits: 1).format(difference / previous.abs())})'}',
              style: TextStyle(
                fontSize: 11,
                color: deltaColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, Color color, bool dashed) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        dashed ? Icons.more_horiz : Icons.horizontal_rule,
        size: 20,
        color: color,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );

  Widget _plot(List<double> current, List<double> previous, Color color) {
    final colors = Theme.of(context).colorScheme;
    final values = [...current, ...previous];
    final low = values.fold(0.0, math.min), high = values.fold(0.0, math.max);
    final span = math.max(1.0, high - low);
    final minY = low < 0 ? low - span * .12 : 0.0;
    final maxY = high + span * .12;
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final axisWidth = scale > 1.5 ? 0.0 : 46 * scale;
    final bottomHeight = 28 * scale;
    final plotLast = math.max(2, _lastDay);
    return LayoutBuilder(
      builder: (context, bounds) {
        final step = _lastDay <= 6
            ? 1
            : bounds.maxWidth < 500 || scale > 1.5
            ? 5
            : 3;
        return SizedBox(
          key: const ValueKey('monthly-analysis-plot'),
          height: 230 + bottomHeight,
          child: LayoutBuilder(
            builder: (context, area) {
              void select(Offset position) {
                final width = area.maxWidth - axisWidth - 16;
                if (width <= 0 ||
                    position.dx < axisWidth ||
                    position.dx > area.maxWidth - 16 ||
                    position.dy > area.maxHeight - bottomHeight)
                  return;
                _select(
                  1 +
                      ((position.dx - axisWidth) / width * (plotLast - 1))
                          .round(),
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
                        minX: 1,
                        maxX: plotLast.toDouble(),
                        minY: minY,
                        maxY: maxY,
                        clipData: const FlClipData.all(),
                        lineTouchData: const LineTouchData(enabled: false),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: (maxY - minY) / 4,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: colors.outlineVariant.withValues(alpha: .4),
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
                          verticalLines: [
                            VerticalLine(
                              x: _day.toDouble(),
                              color: colors.onSurfaceVariant.withValues(
                                alpha: .6,
                              ),
                              strokeWidth: 1,
                              dashArray: [3, 3],
                            ),
                          ],
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
                              showTitles: axisWidth > 0,
                              reservedSize: axisWidth,
                              interval: (maxY - minY) / 4,
                              getTitlesWidget: (value, _) => Text(
                                NumberFormat.compact(
                                  locale: _locale,
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
                              reservedSize: bottomHeight,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final day = value.round();
                                if (day > _lastDay ||
                                    (day != 1 && day % step != 0) ||
                                    (day != 1 &&
                                        day < step + 1 &&
                                        _lastDay > 6))
                                  return const SizedBox.shrink();
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          for (final series in [
                            (previous, colors.onSurfaceVariant, true),
                            (current, color, false),
                          ])
                            if (series.$1.isNotEmpty)
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < series.$1.length; i++)
                                    FlSpot(i + 1.0, series.$1[i]),
                                ],
                                color: series.$2,
                                barWidth: series.$3 ? 2 : 2.5,
                                dashArray: series.$3 ? [5, 4] : null,
                                isCurved: false,
                                dotData: FlDotData(
                                  show: true,
                                  checkToShowDot: (spot, _) =>
                                      spot.x.round() == _day,
                                ),
                                belowBarData: BarAreaData(
                                  show: !series.$3,
                                  color: color.withValues(alpha: .06),
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
      },
    );
  }

  Widget _detail(List<double> current, List<double> previous, Color color) {
    final colors = Theme.of(context).colorScheme;
    final available = _day <= current.length && _day <= previous.length;
    final difference = available
        ? current[_day - 1] - previous[_day - 1]
        : null;
    return Container(
      key: const ValueKey('monthly-analysis-detail'),
      padding: const EdgeInsets.all(14),
      decoration: AppDesign.panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${context.tr('Jour')} $_day · ${context.tr(_labels[_series]!)}',
            key: const ValueKey('monthly-analysis-selected-day'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, bounds) {
              final columns =
                  bounds.maxWidth >= 420 &&
                      MediaQuery.textScalerOf(context).scale(12) < 18
                  ? 2
                  : 1;
              final width = (bounds.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  for (final period in [
                    (widget.data.month, current, widget.data.dailyCount, color),
                    (
                      widget.data.previousMonth,
                      previous,
                      widget.data.previousDailyCount,
                      colors.onSurfaceVariant,
                    ),
                  ])
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _month(period.$1),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _day <= period.$2.length
                                ? _money(period.$2[_day - 1])
                                : '—',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: period.$4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${context.tr('Opérations ce jour')} : ${_day <= period.$3.length ? period.$3[_day - 1] : '—'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            '${context.tr('Écart')} : ${difference == null ? '—' : '${difference > 0 ? '+' : ''}${_money(difference)}'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
