import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'package:mysold/models/month_operation_charts.dart';

typedef SankeyNodeKey = (bool, String?);

class TransferSankeyNode {
  final SankeyNodeKey key;
  final Rect rect;
  final int cents;
  const TransferSankeyNode(this.key, this.rect, this.cents);
}

class TransferSankeyBand {
  final int routeIndex, colorIndex;
  final Path path;
  final Offset start, end;
  final double thickness;
  const TransferSankeyBand(
    this.routeIndex,
    this.colorIndex,
    this.path,
    this.start,
    this.end,
    this.thickness,
  );
  Offset point(double t) {
    final middle = (start.dx + end.dx) / 2;
    final u = 1 - t;
    return Offset(
      u * u * u * start.dx +
          3 * u * u * t * middle +
          3 * u * t * t * middle +
          t * t * t * end.dx,
      start.dy + (end.dy - start.dy) * (3 * t * t - 2 * t * t * t),
    );
  }
}

/// Two independent columns allow account A -> B and B -> A without cycles.
class TransferSankeyLayout {
  final Size size;
  final List<TransferSankeyNode> sources, targets;
  final List<TransferSankeyBand> bands;
  const TransferSankeyLayout._(
    this.size,
    this.sources,
    this.targets,
    this.bands,
  );

  static double requiredHeight(List<TransferRoute> routes, double scale) {
    final sources = routes
        .map((r) => (r.sourceIsAsset, r.source))
        .toSet()
        .length;
    final targets = routes.map((r) => (false, r.target)).toSet().length;
    final count = math.max(sources, targets);
    return count * 50 * scale + math.max(0, count - 1) * 8 + 8;
  }

  factory TransferSankeyLayout.build(
    Size size,
    List<TransferRoute> routes,
    double scale,
  ) {
    assert(size.height >= requiredHeight(routes, scale) - .1);
    final sourceTotals = <SankeyNodeKey, int>{},
        targetTotals = <SankeyNodeKey, int>{};
    for (final r in routes) {
      final s = (r.sourceIsAsset, r.source), t = (false, r.target);
      sourceTotals[s] = (sourceTotals[s] ?? 0) + r.total;
      targetTotals[t] = (targetTotals[t] ?? 0) + r.total;
    }
    List<SankeyNodeKey> sorted(Map<SankeyNodeKey, int> totals) =>
        totals.keys.toList()..sort((a, b) {
          final order = totals[b]!.compareTo(totals[a]!);
          return order == 0 ? a.toString().compareTo(b.toString()) : order;
        });
    final sk = sorted(sourceTotals), tk = sorted(targetTotals);
    final minimum = 50.0 * scale,
        padding = 8.0,
        width = (size.width * .3).clamp(64.0, 170.0);
    final total = sourceTotals.values.fold(0, (sum, v) => sum + v);
    double needed(Map<SankeyNodeKey, int> values, double unit) =>
        values.values.fold(
          0.0,
          (sum, value) => sum + math.max(minimum, value * unit + padding),
        ) +
        math.max(0, values.length - 1) * 8;
    var low = 0.0, high = total == 0 ? 0.0 : size.height / total;
    for (var i = 0; i < 40; i++) {
      final unit = (low + high) / 2;
      if (math.max(needed(sourceTotals, unit), needed(targetTotals, unit)) <=
          size.height - 8)
        low = unit;
      else
        high = unit;
    }
    final unit = low;
    List<TransferSankeyNode> place(
      List<SankeyNodeKey> keys,
      Map<SankeyNodeKey, int> values,
      double x,
    ) {
      var y = (size.height - needed(values, unit)) / 2;
      return [
        for (final key in keys)
          () {
            final height = math.max(minimum, values[key]! * unit + padding);
            final node = TransferSankeyNode(
              key,
              Rect.fromLTWH(x, y, width, height),
              values[key]!,
            );
            y += height + 8;
            return node;
          }(),
      ];
    }

    final sources = place(sk, sourceTotals, 0),
        targets = place(tk, targetTotals, size.width - width);
    final sourceCenters = <int, double>{}, targetCenters = <int, double>{};
    for (final node in sources) {
      final indices =
          [
            for (var i = 0; i < routes.length; i++)
              if ((routes[i].sourceIsAsset, routes[i].source) == node.key) i,
          ]..sort(
            (a, b) => tk
                .indexOf((false, routes[a].target))
                .compareTo(tk.indexOf((false, routes[b].target))),
          );
      var y = node.rect.center.dy - node.cents * unit / 2;
      for (final index in indices) {
        final thickness = routes[index].total * unit;
        sourceCenters[index] = y + thickness / 2;
        y += thickness;
      }
    }
    for (final node in targets) {
      final indices =
          [
            for (var i = 0; i < routes.length; i++)
              if ((false, routes[i].target) == node.key) i,
          ]..sort(
            (a, b) => sk
                .indexOf((routes[a].sourceIsAsset, routes[a].source))
                .compareTo(
                  sk.indexOf((routes[b].sourceIsAsset, routes[b].source)),
                ),
          );
      var y = node.rect.center.dy - node.cents * unit / 2;
      for (final index in indices) {
        final thickness = routes[index].total * unit;
        targetCenters[index] = y + thickness / 2;
        y += thickness;
      }
    }
    final bands = <TransferSankeyBand>[];
    for (var i = 0; i < routes.length; i++) {
      final start = Offset(width, sourceCenters[i]!),
          end = Offset(size.width - width, targetCenters[i]!);
      final half = routes[i].total * unit / 2, middle = (start.dx + end.dx) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy - half)
        ..cubicTo(
          middle,
          start.dy - half,
          middle,
          end.dy - half,
          end.dx,
          end.dy - half,
        )
        ..lineTo(end.dx, end.dy + half)
        ..cubicTo(
          middle,
          end.dy + half,
          middle,
          start.dy + half,
          start.dx,
          start.dy + half,
        )
        ..close();
      bands.add(
        TransferSankeyBand(
          i,
          tk.indexOf((false, routes[i].target)),
          path,
          start,
          end,
          half * 2,
        ),
      );
    }
    return TransferSankeyLayout._(
      size,
      List.unmodifiable(sources),
      List.unmodifiable(targets),
      List.unmodifiable(bands),
    );
  }

  int? hitTest(Offset point) {
    for (final band in bands.reversed)
      if (band.path.contains(point)) return band.routeIndex;
    // Thin ribbons stay touchable without changing their financial proportions.
    for (final band in bands)
      for (var i = 0; i <= 24; i++)
        if ((band.point(i / 24) - point).distance < 8) return band.routeIndex;
    return null;
  }
}
