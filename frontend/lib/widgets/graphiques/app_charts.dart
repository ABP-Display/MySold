import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// Financial data updates directly by default. Only an explicit, local pie
// selection opts into motion; tab/filter changes stay immediate.
class AppLineChart extends StatelessWidget {
  final LineChartData data;
  const AppLineChart(this.data, {super.key});

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: LineChart(data, duration: Duration.zero));
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
  final Duration duration;
  final Curve curve;
  const AppPieChart(
    this.data, {
    super.key,
    this.duration = Duration.zero,
    this.curve = Curves.linear,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: PieChart(
      data,
      swapAnimationDuration: duration,
      swapAnimationCurve: curve,
    ),
  );
}
