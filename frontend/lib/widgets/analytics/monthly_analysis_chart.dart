import 'package:mysold/widgets/graphiques/chart_pointer_region.dart';
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
  final ValueChanged<bool>? onAverageChanged;
  final bool referenceLoading, referenceFailed;
  final VoidCallback? onRetryReference;
  const MonthlyAnalysisChart({
    super.key,
    required this.data,
    required this.currency,
    required this.hidden,
    this.initialSeries = MonthlySeries.expense,
    this.initialCumulative = true,
    this.onSeriesChanged,
    this.onCumulativeChanged,
    this.onAverageChanged,
    this.referenceLoading = false,
    this.referenceFailed = false,
    this.onRetryReference,
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

enum _ReferenceChoice { previous, month, average }

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
            oldWidget.data.previousMonth != widget.data.previousMonth ||
            oldWidget.data.isAverage != widget.data.isAverage)
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
  bool get _canCompare =>
      widget.data.canCompare &&
      !widget.referenceLoading &&
      !widget.referenceFailed;
  String get _referenceLabel => widget.data.isAverage
      ? context.tr('Moyenne de l’année')
      : _month(widget.data.previousMonth);
  String get _averagePeriod {
    final months = widget.data.averageMonths;
    if (months.isEmpty)
      return context.tr('Aucun mois terminé à comparer dans cette année.');
    return context.trParams('Moyenne sur {count} mois · {period}', {
      'count': '${months.length}',
      'period': months.length == 1
          ? _month(months.first)
          : '${DateFormat.MMM(_locale).format(months.first)} – ${_month(months.last)}',
    });
  }

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

  Widget _option(String label, bool selected, VoidCallback onTap, {Key? key}) {
    return Semantics(
      container: true,
      child: AppSelectionButton(
        key: key,
        selected: selected,
        onPressed: onTap,
        minHeight: 44,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Center(
          child: Text(
            context.tr(label),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _menu<T>({
    required Key key,
    required String label,
    required String tooltip,
    required T selected,
    required List<PopupMenuEntry<T>> entries,
    required ValueChanged<T> onSelected,
    int maxLines = 2,
  }) => PopupMenuButton<T>(
    key: key,
    tooltip: tooltip,
    initialValue: selected,
    onSelected: onSelected,
    itemBuilder: (_) => entries,
    child: Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: AppDesign.panel(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 18),
        ],
      ),
    ),
  );

  Widget _referenceMenu() => _menu<_ReferenceChoice>(
    key: const ValueKey('comparison-reference-menu'),
    label: _referenceLabel,
    tooltip: context.tr('Comparer avec'),
    selected: widget.data.isAverage
        ? _ReferenceChoice.average
        : widget.data.previousMonth ==
              DateTime(widget.data.month.year, widget.data.month.month - 1)
        ? _ReferenceChoice.previous
        : _ReferenceChoice.month,
    entries: [
      PopupMenuItem(
        key: const ValueKey('comparison-reference-previous'),
        value: _ReferenceChoice.previous,
        enabled:
            widget.onResetReference != null || widget.onAverageChanged != null,
        child: _menuLabel(Icons.restore, context.tr('Mois précédent (M-1)')),
      ),
      PopupMenuItem(
        key: const ValueKey('comparison-reference-month'),
        value: _ReferenceChoice.month,
        enabled: widget.onChooseReference != null,
        child: _menuLabel(
          Icons.calendar_month_outlined,
          context.tr('Un autre mois'),
        ),
      ),
      PopupMenuItem(
        key: const ValueKey('comparison-reference-average'),
        value: _ReferenceChoice.average,
        enabled: widget.onAverageChanged != null,
        child: _menuLabel(Icons.timeline, context.tr('Moyenne de l’année')),
      ),
    ],
    onSelected: (choice) {
      switch (choice) {
        case _ReferenceChoice.previous:
          widget.onAverageChanged?.call(false);
          widget.onResetReference?.call();
        case _ReferenceChoice.month:
          widget.onAverageChanged?.call(false);
          widget.onChooseReference?.call();
        case _ReferenceChoice.average:
          widget.onAverageChanged?.call(true);
      }
    },
  );

  Widget _menuLabel(IconData icon, String label, {Color? color}) => Row(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 12),
      Flexible(child: Text(label)),
    ],
  );

  Widget _controls() => LayoutBuilder(
    builder: (context, bounds) {
      final type = _menu<MonthlySeries>(
        key: const ValueKey('analysis-type-menu'),
        label: context.tr(_labels[_series]!),
        tooltip: context.tr('Type de transaction'),
        maxLines: 1,
        selected: _series,
        entries: [
          for (final series in MonthlySeries.values)
            PopupMenuItem(
              key: ValueKey('analysis-${series.name}'),
              value: series,
              child: _menuLabel(
                _icons[series]!,
                context.tr(_labels[series]!),
                color: _color(series),
              ),
            ),
        ],
        onSelected: _chooseSeries,
      );
      final reading = Container(
        decoration: AppDesign.panel(context),
        padding: const EdgeInsets.all(3),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _option(
                  'Cumulé',
                  _cumulative,
                  () => _chooseReading(true),
                  key: const ValueKey('analysis-cumulative'),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _option(
                  'Jour',
                  !_cumulative,
                  () => _chooseReading(false),
                  key: const ValueKey('analysis-daily'),
                ),
              ),
            ],
          ),
        ),
      );
      double labelWidth(String label) {
        final painter = TextPainter(
          text: TextSpan(
            text: context.tr(label),
            style: Theme.of(
              context,
            ).textTheme.labelLarge!.copyWith(fontSize: 12),
          ),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      final readingWidth = math.max(
        132.0,
        2 * (math.max(labelWidth('Cumulé'), labelWidth('Jour')) + 18) + 8,
      );
      if (bounds.maxWidth - readingWidth < 110 ||
          MediaQuery.textScalerOf(context).scale(12) > 17) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [type, const SizedBox(height: 8), reading],
        );
      }
      return Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: type,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: readingWidth, child: reading),
        ],
      );
    },
  );
  @override
  Widget build(BuildContext context) {
    final data = widget.data, colors = Theme.of(context).colorScheme;
    final current = data.values(_series, cumulative: _cumulative);
    final previous = widget.referenceLoading || widget.referenceFailed
        ? const <double>[]
        : data.values(_series, previous: true, cumulative: _cumulative);
    final color = _color(_series);
    return MonthlyStatsPanel(
      title: 'Comparaison',
      icon: Icons.query_stats,
      action: _referenceMenu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _controls(),
          const SizedBox(height: 12),
          if (data.isAverage)
            Tooltip(
              message: context.tr(
                'Mois terminés depuis janvier, hors mois analysé. Les mois sans opération comptent aussi.',
              ),
              child: Text(
                widget.referenceLoading
                    ? context.tr('Chargement de vos données…')
                    : widget.referenceFailed
                    ? context.tr('Moyenne de l’année')
                    : _averagePeriod,
                key: const ValueKey('comparison-average-period'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (!data.isAverage && !data.canCompare)
            Text(
              context.tr('Une des périodes n’a pas encore commencé.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (widget.referenceLoading) ...[
            const LinearProgressIndicator(key: ValueKey('comparison-loading')),
            const SizedBox(height: 12),
          ],
          if (widget.referenceFailed) ...[
            Text(context.tr('Impossible de charger la comparaison.')),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: widget.onRetryReference,
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('Réessayer')),
              ),
            ),
          ],
          _summary(),
          if (_series == MonthlySeries.transfer) ...[
            const SizedBox(height: 10),
            Text(
              context.tr(
                'Les transferts sont suivis séparément et ne modifient pas le reste.',
              ),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
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
                if (_canCompare)
                  _legend(_referenceLabel, colors.onSurfaceVariant, true),
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
                    identifier: 'monthly-comparison-chart',
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
                  _detail(current, previous, color),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary() {
    final series = _series;
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
        widget.hidden || !_canCompare || difference == 0 || neutral
        ? colors.onSurfaceVariant
        : good
        ? Colors.green.shade600
        : colors.error;
    final delta = !_canCompare
        ? '—'
        : '${!widget.hidden && difference > 0 ? '+' : ''}${_money(difference)}';
    final percent = !_canCompare || widget.hidden || previous == 0
        ? ''
        : NumberFormat.decimalPercentPattern(
            locale: _locale,
            decimalDigits: 1,
          ).format(difference / previous.abs());
    Widget amount(String label, String value, String key, {Color? color}) =>
        Column(
          key: ValueKey(key),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        );
    return Padding(
      key: const ValueKey('comparison-summary'),
      padding: const EdgeInsets.only(top: 14),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final first = amount(
            _month(widget.data.month),
            widget.data.selected.isFuture ? '—' : _money(current),
            'comparison-current-value',
          );
          final second = amount(
            _referenceLabel,
            _canCompare ? _money(previous) : '—',
            'comparison-reference-value',
          );
          if (bounds.maxWidth >= 520 &&
              MediaQuery.textScalerOf(context).scale(12) < 18) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: first),
                const SizedBox(width: 16),
                Expanded(child: second),
                const SizedBox(width: 16),
                Expanded(
                  child: amount(
                    '${context.tr('Écart')}${percent.isEmpty ? '' : ' · $percent'}',
                    delta,
                    'comparison-delta-value',
                    color: deltaColor,
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: first),
                  const SizedBox(width: 12),
                  Expanded(child: second),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                key: const ValueKey('comparison-delta-value'),
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    context.tr('Écart'),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    delta,
                    style: TextStyle(
                      color: deltaColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (percent.isNotEmpty)
                    Text(
                      '($percent)',
                      style: TextStyle(fontSize: 12, color: deltaColor),
                    ),
                ],
              ),
            ],
          );
        },
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

              return RepaintBoundary(
                child: ChartPointerRegion(
                  onSelect: select,
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
    final available =
        _canCompare && _day <= current.length && _day <= previous.length;
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
                    (
                      _month(widget.data.month),
                      current,
                      widget.data.dailyCount,
                      color,
                      false,
                    ),
                    (
                      _referenceLabel,
                      _canCompare ? previous : const <double>[],
                      widget.data.previousDailyCount,
                      colors.onSurfaceVariant,
                      widget.data.isAverage,
                    ),
                  ])
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            period.$1,
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
                            '${context.tr(period.$5 ? 'Opérations moyennes ce jour' : 'Opérations ce jour')} : ${_day <= period.$3.length ? NumberFormat.decimalPattern(_locale).format(period.$3[_day - 1]) : '—'}',
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
