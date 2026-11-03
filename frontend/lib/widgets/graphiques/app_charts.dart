import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'chart_info_region.dart';

// Financial charts update directly. Interpolating every series on the UI
// thread makes switching tabs/filters expensive on slower Web clients.
class AppLineChart extends StatelessWidget {
  final LineChartData data;
  const AppLineChart(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    final chart = RepaintBoundary(
      child: LineChart(
        data.copyWith(lineTouchData: const LineTouchData(enabled: false)),
        duration: Duration.zero,
      ),
    );
    // Other charts already supply their own non-capturing selection region.
    if (!data.lineTouchData.enabled ||
        !data.lineTouchData.handleBuiltInTouches) {
      return chart;
    }
    return ChartInfoRegion(
      resolve: (position, size) => _lineInfo(data, position, size),
      child: chart,
    );
  }
}

/// Resolve existing tooltip content without fl_chart's pan/long-press
/// recognizers, which hold the gesture even after the finger starts scrolling.
ChartInfo? _lineInfo(LineChartData data, Offset position, Size size) {
  double reserved(AxisTitles axis) =>
      data.titlesData.show && axis.sideTitles.showTitles
      ? axis.sideTitles.reservedSize
      : 0;
  final area = Rect.fromLTRB(
    reserved(data.titlesData.leftTitles),
    reserved(data.titlesData.topTitles),
    size.width - reserved(data.titlesData.rightTitles),
    size.height - reserved(data.titlesData.bottomTitles),
  );
  if (area.isEmpty || !area.contains(position)) return null;
  final spots = [
    for (final bar in data.lineBarsData)
      if (bar.show)
        for (final spot in bar.spots)
          if (spot.x.isFinite && spot.y.isFinite) spot,
  ];
  if (spots.isEmpty) return null;
  final minX = data.minX.isFinite
      ? data.minX
      : spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
  final maxX = data.maxX.isFinite
      ? data.maxX
      : spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
  final x = minX + (position.dx - area.left) / area.width * (maxX - minX);
  LineBarSpot? nearest;
  var distance = double.infinity;
  for (var index = 0; index < data.lineBarsData.length; index++) {
    final bar = data.lineBarsData[index];
    if (!bar.show) continue;
    for (final spot in bar.spots) {
      if (!spot.x.isFinite || !spot.y.isFinite) continue;
      final delta = (spot.x - x).abs();
      if (delta < distance) {
        distance = delta;
        nearest = LineBarSpot(bar, index, spot);
      }
    }
  }
  if (nearest == null) return null;
  final item = data.lineTouchData.touchTooltipData.getTooltipItems([
    nearest,
  ]).firstOrNull;
  if (item == null) return null;
  final lines = TextSpan(
    text: item.text,
    children: item.children,
  ).toPlainText().split('\n');
  return ChartInfo(
    lines.first,
    lines.skip(1).join('\n'),
    color: nearest.bar.color,
  );
}

class AppBarChart extends StatelessWidget {
  final BarChartData data;
  const AppBarChart(this.data, {super.key});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: BarChart(data, swapAnimationDuration: Duration.zero),
  );
}

class AppPieChart extends StatelessWidget {
  final PieChartData data;
  const AppPieChart(this.data, {super.key});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: PieChart(data, swapAnimationDuration: Duration.zero),
  );
}
