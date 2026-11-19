import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat, DateFormat;
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/month_operation_charts.dart';
import 'transfer_sankey_layout.dart';

const _flowColors = [
  Color(0xff77b8ae),
  Color(0xffb3a2d0),
  Color(0xff88a9d3),
  Color(0xffcfb27c),
  Color(0xffc68d9f),
];

class TransferSankeyChart extends StatefulWidget {
  final List<TransferRoute> routes;
  final Map<String, String> accounts, investments;
  final String Function(int) money;
  final String currency;
  const TransferSankeyChart({
    super.key,
    required this.routes,
    required this.accounts,
    required this.investments,
    required this.money,
    this.currency = '€',
  });
  @override
  State<TransferSankeyChart> createState() => _TransferSankeyChartState();
}

class _TransferSankeyChartState extends State<TransferSankeyChart> {
  (bool, String?, String?)? _selected;
  final _hover = ValueNotifier<int?>(null);
  final _scroll = ScrollController();
  @override
  void didUpdateWidget(covariant TransferSankeyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.routes.any((r) => r.key == _selected)) _selected = null;
    _hover.value = null;
  }

  @override
  void dispose() {
    _hover.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _source(BuildContext context, TransferRoute r) => r.sourceIsAsset
      ? '${context.tr('Actif')} · ${widget.investments[r.source] ?? context.tr('Investissement')}'
      : widget.accounts[r.source] ?? context.tr('Compte inconnu');
  String _target(BuildContext context, TransferRoute r) =>
      widget.accounts[r.target] ?? context.tr('Compte inconnu');
  void _open(int index) {
    _hover.value = null;
    setState(() => _selected = widget.routes[index].key);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final selection = widget.routes
        .where((r) => r.key == _selected)
        .firstOrNull;
    if (selection != null)
      return Semantics(
        identifier: 'sankey-detail',
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: context.tr('Retour au graphique'),
                  onPressed: () => setState(() => _selected = null),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: const Icon(Icons.arrow_back, size: 18),
                ),
                Expanded(
                  child: Text(
                    '${_source(context, selection)} → ${_target(context, selection)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.trParams(
                        selection.entries.length == 1
                            ? '{count} opération'
                            : '{count} opérations',
                        {'count': selection.entries.length},
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      widget.money(selection.total),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                primary: false,
                padding: EdgeInsets.zero,
                children: [
                  for (final entry in selection.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat.yMMMd(locale).format(entry.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              widget.money(entry.cents),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                context.tr('Départ'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Text(
                context.tr('Arrivée'),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Expanded(
          child: LayoutBuilder(
            builder: (context, bounds) {
              final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
              final height = math.max(
                bounds.maxHeight,
                TransferSankeyLayout.requiredHeight(widget.routes, scale),
              );
              final layout = TransferSankeyLayout.build(
                Size(bounds.maxWidth, height),
                widget.routes,
                scale,
              );
              final names = <SankeyNodeKey, String>{
                for (final route in widget.routes)
                  (route.sourceIsAsset, route.source): _source(context, route),
                for (final route in widget.routes)
                  (false, route.target): _target(context, route),
              };
              String compact(int cents) => NumberFormat.compactCurrency(
                locale: locale,
                symbol: widget.currency,
                decimalDigits: cents % 100 == 0 ? 0 : 2,
              ).format(cents / 100);
              final painter = _SankeyPainter(
                layout,
                names,
                compact,
                [for (final route in widget.routes) widget.money(route.total)],
                colors,
                scale,
                _hover,
                Directionality.of(context),
              );
              final canvas = Semantics(
                identifier: 'transfer-sankey-canvas',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (e) =>
                      _hover.value = layout.hitTest(e.localPosition),
                  onExit: (_) => _hover.value = null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (e) {
                      final i = layout.hitTest(e.localPosition);
                      if (i != null) _open(i);
                    },
                    onTapCancel: () => _hover.value = null,
                    child: SizedBox(
                      width: bounds.maxWidth,
                      height: height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                key: const ValueKey('transfer-sankey-paint'),
                                painter: painter,
                              ),
                            ),
                          ),
                          for (final band in layout.bands)
                            Positioned.fromRect(
                              rect: painter.hitRects[band.routeIndex]!,
                              child: Semantics(
                                identifier: 'sankey-flow-${band.routeIndex}',
                                button: true,
                                label:
                                    '${_source(context, widget.routes[band.routeIndex])} → ${_target(context, widget.routes[band.routeIndex])}, ${widget.money(widget.routes[band.routeIndex].total)}',
                                onTap: () => _open(band.routeIndex),
                                child: const SizedBox.expand(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              if (height <= bounds.maxHeight + .1) return canvas;
              return Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: canvas,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

TextPainter _text(
  String value,
  double size,
  Color color,
  TextDirection direction, {
  int lines = 1,
  FontWeight weight = FontWeight.w500,
  double? width,
  TextAlign align = TextAlign.center,
}) {
  return TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        height: 1.1,
        color: color,
        fontWeight: weight,
      ),
    ),
    textDirection: direction,
    textAlign: align,
    maxLines: lines,
    ellipsis: '…',
  )..layout(maxWidth: width ?? double.infinity);
}

class _SankeyPainter extends CustomPainter {
  final TransferSankeyLayout layout;
  final Map<SankeyNodeKey, String> names;
  final String Function(int) compact;
  final List<String> amounts;
  final ColorScheme colors;
  final double scale;
  final ValueNotifier<int?> hover;
  final TextDirection direction;
  final hitRects = <int, Rect>{};
  final _labels = <int, ({Rect rect, TextPainter text})>{};

  _SankeyPainter(
    this.layout,
    this.names,
    this.compact,
    this.amounts,
    this.colors,
    this.scale,
    this.hover,
    this.direction,
  ) : super(repaint: hover) {
    final occupied = <Rect>[];
    for (final band in layout.bands) {
      final gap = band.end.dx - band.start.dx;
      final text = _text(
        amounts[band.routeIndex],
        10 * scale,
        colors.onSurface,
        direction,
        weight: FontWeight.w700,
        width: math.max(1, gap - 10),
      );
      Rect? label;
      for (final t in [.5, .32, .68, .2, .8]) {
        final point = band.point(t);
        final candidate = Rect.fromCenter(
          center: point,
          width: text.width + 8,
          height: text.height + 6,
        );
        if (candidate.left < band.start.dx + 2 ||
            candidate.right > band.end.dx - 2)
          continue;
        if (occupied.any((r) => r.inflate(3).overlaps(candidate))) continue;
        label = candidate;
        break;
      }
      if (label != null) {
        occupied.add(label);
        _labels[band.routeIndex] = (rect: label, text: text);
      }
      final center = label?.center ?? band.point(.5);
      hitRects[band.routeIndex] = Rect.fromCenter(
        center: center,
        width: math.min(gap, math.max(32, text.width + 8)),
        height: math.max(24, text.height + 6),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final band in layout.bands) {
      final active = hover.value;
      final color = _flowColors[band.colorIndex % _flowColors.length];
      canvas.drawPath(
        band.path,
        Paint()
          ..color = color.withValues(
            alpha: active == null
                ? .62
                : active == band.routeIndex
                ? .9
                : .25,
          ),
      );
      if (band.thickness > 12) {
        final point = band.point(.84);
        final arrow = Path()
          ..moveTo(point.dx - 3, point.dy - 3)
          ..lineTo(point.dx, point.dy)
          ..lineTo(point.dx - 3, point.dy + 3);
        canvas.drawPath(
          arrow,
          Paint()
            ..color = colors.onSurface.withValues(alpha: .65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
    for (final node in [...layout.sources, ...layout.targets]) {
      final rect = node.rect;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = colors.surface,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(.5), const Radius.circular(6)),
        Paint()
          ..color = colors.outlineVariant
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final targetIndex = layout.targets.indexOf(node);
      final accent = targetIndex < 0
          ? colors.onSurfaceVariant
          : _flowColors[targetIndex % _flowColors.length];
      final x = targetIndex < 0 ? rect.right - 3 : rect.left;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, rect.top + 6, 3, rect.height - 12),
          const Radius.circular(2),
        ),
        Paint()..color = accent,
      );
      final name = _text(
        names[node.key] ?? '',
        10.5 * scale,
        colors.onSurface,
        direction,
        lines: 2,
        weight: FontWeight.w600,
        width: rect.width - 12,
      );
      final amount = _text(
        compact(node.cents),
        10.5 * scale,
        colors.onSurfaceVariant,
        direction,
        width: rect.width - 12,
      );
      final y = rect.center.dy - (name.height + 3 + amount.height) / 2;
      name.paint(canvas, Offset(rect.center.dx - name.width / 2, y));
      amount.paint(
        canvas,
        Offset(rect.center.dx - amount.width / 2, y + name.height + 3),
      );
    }
    for (final entry in _labels.entries) {
      final label = entry.value,
          band = layout.bands.firstWhere((b) => b.routeIndex == entry.key);
      // A small backing preserves contrast on both light and dark ribbons.
      canvas.drawRRect(
        RRect.fromRectAndRadius(label.rect, const Radius.circular(3)),
        Paint()..color = colors.surface.withValues(alpha: .88),
      );
      label.text.paint(
        canvas,
        Offset(
          label.rect.center.dx - label.text.width / 2,
          label.rect.center.dy - label.text.height / 2,
        ),
      );
      if (hover.value == entry.key)
        canvas.drawRRect(
          RRect.fromRectAndRadius(label.rect, const Radius.circular(3)),
          Paint()
            ..color = _flowColors[band.colorIndex % _flowColors.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter old) =>
      old.layout != layout || old.colors != colors || old.amounts != amounts;
}
