import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// Financial charts update directly. Interpolating every series on the UI
// thread makes switching tabs/filters expensive on slower Web clients.
class AppLineChart extends StatelessWidget {
  final LineChartData data;
  const AppLineChart(this.data, {super.key});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: LineChart(data, duration: Duration.zero),
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
