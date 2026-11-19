import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'app_charts.dart';

class MonthPieSlice {
  final String? id;
  final String label;
  final int cents;
  final Color color;
  const MonthPieSlice(this.id, this.label, this.cents, this.color);
}

class MonthBreakdownChart extends StatefulWidget {
  final List<MonthPieSlice> slices;
  final String Function(int) money;
  const MonthBreakdownChart({
    super.key,
    required this.slices,
    required this.money,
  });
  @override
  State<MonthBreakdownChart> createState() => _MonthBreakdownChartState();
}

class _MonthBreakdownChartState extends State<MonthBreakdownChart> {
  int? _selected, _hovered, _legendPreview;
  bool _animate = false;
  int? get _active => _legendPreview ?? _hovered ?? _selected;

  @override
  void didUpdateWidget(covariant MonthBreakdownChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
      [for (final s in oldWidget.slices) (s.id, s.label, s.cents, s.color)],
      [for (final s in widget.slices) (s.id, s.label, s.cents, s.color)],
    )) {
      _selected = null;
      _hovered = null;
      _legendPreview = null;
      _animate = false;
    }
  }

  void _select(int? index, {bool animate = true}) {
    final next = index == _selected ? null : index;
    if (next == _selected && _hovered == null && _legendPreview == null) return;
    setState(() {
      _selected = next;
      _hovered = null;
      _legendPreview = null;
      _animate = animate;
    });
  }

  void _hover(int? index) {
    if (index != _hovered)
      setState(() {
        _hovered = index;
        _animate = true;
      });
  }

  void _previewLegend(int index, bool active) {
    if (!active && _legendPreview != index) return;
    final next = active ? index : null;
    if (next == _legendPreview) return;
    setState(() {
      _legendPreview = next;
      if (active) _hovered = null;
      _animate = true;
    });
  }

  int? _hit(
    Offset position,
    Size size,
    double inner,
    double ring,
    double extra,
  ) {
    final relative = position - Offset(size.width / 2, size.height / 2);
    if (relative.distance < inner || relative.distance > inner + ring + extra)
      return null;
    final total = widget.slices.fold(0, (sum, s) => sum + s.cents);
    if (total <= 0) return null;
    final angle =
        (math.atan2(relative.dy, relative.dx) + math.pi * 2.5) % (math.pi * 2);
    var end = 0.0;
    for (var i = 0; i < widget.slices.length; i++) {
      end += widget.slices[i].cents / total * math.pi * 2;
      if (angle <= end) {
        return relative.distance <= inner + ring + (i == _active ? extra : 0)
            ? i
            : null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final colors = Theme.of(context).colorScheme;
      final total = widget.slices.fold(0, (sum, s) => sum + s.cents);
      final donutSize = math.min(
        bounds.maxHeight,
        (bounds.maxWidth * 2 / 3 - 10).clamp(96.0, 190.0),
      );
      final inner = donutSize * .28, ring = donutSize * .17;
      final extra = math.min(8.0, donutSize * .045);
      final selected = _active == null ? null : widget.slices[_active!];
      final duration = _animate && !MediaQuery.disableAnimationsOf(context)
          ? const Duration(milliseconds: 180)
          : Duration.zero;
      String percentOf(MonthPieSlice slice) =>
          NumberFormat.decimalPercentPattern(
            locale: Localizations.localeOf(context).toString(),
            decimalDigits: 1,
          ).format(total == 0 ? 0 : slice.cents / total);
      final percent = selected == null ? null : percentOf(selected);
      final hovered = _hovered == null ? null : widget.slices[_hovered!];
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: Semantics(
              container: true,
              identifier: 'month-pie-plot',
              child: Center(
                child: SizedBox(
                  width: donutSize,
                  height: donutSize,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onHover: (event) => _hover(
                      _hit(
                        event.localPosition,
                        Size.square(donutSize),
                        inner,
                        ring,
                        extra,
                      ),
                    ),
                    onExit: (_) => _hover(null),
                    child: Tooltip(
                      message: hovered == null
                          ? ''
                          : '${hovered.label} · ${widget.money(hovered.cents)} · ${percentOf(hovered)}',
                      child: GestureDetector(
                        // Accessible selection is exposed by the legend buttons;
                        // the canvas needs the original pointer coordinates.
                        excludeFromSemantics: true,
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (event) => _select(
                          _hit(
                            event.localPosition,
                            Size.square(donutSize),
                            inner,
                            ring,
                            extra,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AppPieChart(
                              PieChartData(
                                startDegreeOffset: -90,
                                sectionsSpace: 0,
                                centerSpaceRadius: inner,
                                pieTouchData: PieTouchData(enabled: false),
                                sections: [
                                  for (var i = 0; i < widget.slices.length; i++)
                                    PieChartSectionData(
                                      value: widget.slices[i].cents.toDouble(),
                                      color: widget.slices[i].color,
                                      radius: ring + (i == _active ? extra : 0),
                                      showTitle: false,
                                    ),
                                ],
                              ),
                              duration: duration,
                              curve: const Cubic(.23, 1, .32, 1),
                            ),
                            IgnorePointer(
                              child: SizedBox(
                                width: inner * 1.8,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        widget.money(selected?.cents ?? total),
                                        key: const ValueKey(
                                          'month-pie-center-amount',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (percent != null)
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          percent,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              container: true,
              identifier: 'month-pie-legend',
              child: Column(
                children: [
                  for (var i = 0; i < widget.slices.length; i++)
                    Expanded(
                      child: _PieLegendItem(
                        index: i,
                        slice: widget.slices[i],
                        money: widget.money(widget.slices[i].cents),
                        selected: i == _active,
                        onSelect: (animate) => _select(i, animate: animate),
                        onPreview: (active) => _previewLegend(i, active),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PieLegendItem extends StatefulWidget {
  final int index;
  final MonthPieSlice slice;
  final String money;
  final bool selected;
  final ValueChanged<bool> onSelect;
  final ValueChanged<bool> onPreview;
  const _PieLegendItem({
    required this.index,
    required this.slice,
    required this.money,
    required this.selected,
    required this.onSelect,
    required this.onPreview,
  });
  @override
  State<_PieLegendItem> createState() => _PieLegendItemState();
}

class _PieLegendItemState extends State<_PieLegendItem> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'month-pie-slice-${widget.index}',
      button: true,
      selected: widget.selected,
      label: '${widget.slice.label} · ${widget.money}',
      onTap: () => widget.onSelect(true),
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onSelect(false);
              return null;
            },
          ),
        },
        child: MouseRegion(
          onEnter: (_) => widget.onPreview(true),
          onExit: (_) => widget.onPreview(false),
          child: Listener(
            onPointerDown: (_) => widget.onPreview(true),
            onPointerUp: (_) => widget.onPreview(false),
            onPointerCancel: (_) => widget.onPreview(false),
            child: GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onSelect(true),
              onTapCancel: () => widget.onPreview(false),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: widget.selected
                        ? colors.onSurface.withValues(alpha: .07)
                        : null,
                    border: _focused ? Border.all(color: colors.primary) : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: widget.slice.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.slice.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.1,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.money,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
