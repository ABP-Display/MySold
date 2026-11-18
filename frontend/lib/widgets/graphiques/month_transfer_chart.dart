import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/month_chart_data.dart';
import 'chart_info_region.dart';
import 'month_chart_style.dart';

class MonthTransferChart extends StatelessWidget {
  final List<TransferFlow> flows;
  final Map<String, String> accounts, investments;
  final String currency;
  const MonthTransferChart({
    super.key,
    required this.flows,
    required this.accounts,
    required this.investments,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final data = TransferDiagram.fromFlows(flows),
        colors = Theme.of(context).colorScheme;
    String label(String key) {
      if (key.startsWith('group:'))
        return context.trParams('Autres comptes ({count})', {
          'count': key == 'group:source'
              ? data.groupedSources
              : data.groupedTargets,
        });
      final split = key.indexOf(':');
      final id = key.substring(split + 1);
      return key.startsWith('investment:')
          ? '${context.tr('Actif')} · ${investments[id] ?? context.tr('Investissement')}'
          : accounts[id] ?? context.tr('Compte inconnu');
    }

    return LayoutBuilder(
      builder: (context, bounds) {
        final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
        final nodeWidth = math.min(180.0, bounds.maxWidth * .3);
        final nodeHeight = math.max(86.0, 80 * scale);
        final count = math.max(data.sources.length, data.targets.length);
        final height = count * nodeHeight + math.max(0, count - 1) * 20 + 16;
        final sources = <String, Rect>{}, targets = <String, Rect>{};
        void place(List<String> keys, Map<String, Rect> output, double x) {
          final gap = (height - keys.length * nodeHeight) / (keys.length + 1);
          for (var i = 0; i < keys.length; i++)
            output[keys[i]] = Rect.fromLTWH(
              x,
              gap + (nodeHeight + gap) * i,
              nodeWidth,
              nodeHeight,
            );
        }

        place(data.sources, sources, 0);
        place(data.targets, targets, bounds.maxWidth - nodeWidth);
        final maximum = [
          ...data.sourceTotals.values,
          ...data.targetTotals.values,
        ].fold(1, math.max);
        final unit = (nodeHeight * .6) / maximum;
        final sourceOffset = <String, double>{},
            targetOffset = <String, double>{};
        final ribbons = <_Ribbon>[];
        const palette = [
          Color(0xFF4BAFB4),
          Color(0xFFAD85D7),
          Color(0xFF6F9FCC),
          Color(0xFF8EB590),
        ];
        for (final flow in data.flows) {
          final s = sources[flow.source]!, t = targets[flow.target]!;
          final thickness = flow.cents * unit;
          final sy =
              s.center.dy -
              data.sourceTotals[flow.source]! * unit / 2 +
              (sourceOffset[flow.source] ?? 0) +
              thickness / 2;
          final ty =
              t.center.dy -
              data.targetTotals[flow.target]! * unit / 2 +
              (targetOffset[flow.target] ?? 0) +
              thickness / 2;
          sourceOffset[flow.source] =
              (sourceOffset[flow.source] ?? 0) + thickness;
          targetOffset[flow.target] =
              (targetOffset[flow.target] ?? 0) + thickness;
          ribbons.add(
            _Ribbon(
              flow,
              Offset(s.right, sy),
              Offset(t.left, ty),
              thickness,
              palette[data.targets.indexOf(flow.target) % palette.length],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  context.tr('Mouvements entre comptes'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  monthChartMoney(
                    context,
                    flows.fold(0, (sum, f) => sum + f.cents),
                    currency,
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: height,
              child: ChartInfoRegion(
                resolve: (position, _) {
                  for (final entry in [
                    ...sources.entries,
                    ...targets.entries,
                  ]) {
                    if (entry.value.contains(position)) {
                      final total = sources[entry.key] == entry.value
                          ? data.sourceTotals[entry.key]!
                          : data.targetTotals[entry.key]!;
                      return ChartInfo(
                        label(entry.key),
                        monthChartMoney(context, total, currency),
                      );
                    }
                  }
                  _Ribbon? closest;
                  var distance = double.infinity;
                  for (final ribbon in ribbons) {
                    if (position.dx < ribbon.start.dx ||
                        position.dx > ribbon.end.dx)
                      continue;
                    final relative =
                        (position.dx - ribbon.start.dx) /
                        (ribbon.end.dx - ribbon.start.dx);
                    var lower = 0.0, upper = 1.0;
                    for (var i = 0; i < 12; i++) {
                      final middle = (lower + upper) / 2;
                      final x =
                          1.5 * middle -
                          1.5 * middle * middle +
                          middle * middle * middle;
                      if (x < relative)
                        lower = middle;
                      else
                        upper = middle;
                    }
                    final t = (lower + upper) / 2;
                    final y =
                        ribbon.start.dy +
                        (ribbon.end.dy - ribbon.start.dy) *
                            (3 * t * t - 2 * t * t * t);
                    final delta = (position.dy - y).abs();
                    if (delta < math.max(8, ribbon.width / 2) &&
                        delta < distance) {
                      closest = ribbon;
                      distance = delta;
                    }
                  }
                  return closest == null
                      ? null
                      : ChartInfo(
                          '${label(closest.flow.source)} → ${label(closest.flow.target)}',
                          monthChartMoney(
                            context,
                            closest.flow.cents,
                            currency,
                          ),
                          color: closest.color,
                        );
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _FlowPainter(ribbons)),
                    ),
                    for (final entry in [
                      ...sources.entries,
                      ...targets.entries,
                    ])
                      Positioned.fromRect(
                        rect: entry.value,
                        child: Tooltip(
                          message: label(entry.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  label(entry.key),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      monthChartMoney(
                                        context,
                                        sources[entry.key] == entry.value
                                            ? data.sourceTotals[entry.key]!
                                            : data.targetTotals[entry.key]!,
                                        currency,
                                      ),
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('Hors revenus et dépenses'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _Ribbon {
  final TransferFlow flow;
  final Offset start, end;
  final double width;
  final Color color;
  const _Ribbon(this.flow, this.start, this.end, this.width, this.color);
}

class _FlowPainter extends CustomPainter {
  final List<_Ribbon> ribbons;
  const _FlowPainter(this.ribbons);
  @override
  void paint(Canvas canvas, Size size) {
    for (final ribbon in ribbons) {
      final middle = (ribbon.start.dx + ribbon.end.dx) / 2;
      final path = Path()
        ..moveTo(ribbon.start.dx, ribbon.start.dy)
        ..cubicTo(
          middle,
          ribbon.start.dy,
          middle,
          ribbon.end.dy,
          ribbon.end.dx,
          ribbon.end.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = ribbon.color.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.75, ribbon.width),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlowPainter oldDelegate) =>
      oldDelegate.ribbons != ribbons;
}
