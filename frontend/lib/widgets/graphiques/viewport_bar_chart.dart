import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'chart_info_region.dart';

class BarSelection {
  final int group, rod;
  const BarSelection(this.group, this.rod);
}

/// Locate the nearest bar using the same group spacing as the chart painter.
BarSelection? barSelectionAt(BarChartData data, Size size, Offset position) {
  assert(
    data.alignment == BarChartAlignment.spaceAround ||
        data.alignment == BarChartAlignment.spaceEvenly,
  );
  final left =
      data.titlesData.show && data.titlesData.leftTitles.sideTitles.showTitles
      ? data.titlesData.leftTitles.sideTitles.reservedSize
      : 0.0;
  final right =
      data.titlesData.show && data.titlesData.rightTitles.sideTitles.showTitles
      ? data.titlesData.rightTitles.sideTitles.reservedSize
      : 0.0;
  final top =
      data.titlesData.show && data.titlesData.topTitles.sideTitles.showTitles
      ? data.titlesData.topTitles.sideTitles.reservedSize
      : 0.0;
  final bottom =
      data.titlesData.show && data.titlesData.bottomTitles.sideTitles.showTitles
      ? data.titlesData.bottomTitles.sideTitles.reservedSize
      : 0.0;
  final plot = Rect.fromLTRB(
    left,
    top,
    size.width - right,
    size.height - bottom,
  );
  if (!plot.contains(position) || data.barGroups.isEmpty) return null;
  final groups = data.barGroups;
  final sum = groups.fold(0.0, (total, group) => total + group.width);
  final around = data.alignment == BarChartAlignment.spaceAround;
  final gap =
      (plot.width - sum) / (around ? groups.length * 2 : groups.length + 1);
  var cursor = plot.left;
  BarSelection? nearest;
  var distance = double.infinity;
  for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    final group = groups[groupIndex];
    cursor += gap;
    var rodX = cursor;
    for (var rodIndex = 0; rodIndex < group.barRods.length; rodIndex++) {
      final rod = group.barRods[rodIndex];
      final difference = (position.dx - rodX - rod.width / 2).abs();
      if (difference < distance) {
        distance = difference;
        nearest = BarSelection(groupIndex, rodIndex);
      }
      rodX += rod.width + group.barsSpace;
    }
    cursor += group.width + (around ? gap : 0);
  }
  return nearest;
}

class ViewportBarChart extends StatelessWidget {
  final BarChartData data;
  final ChartInfo Function(int group, int rod) info;
  final ScrollController? controller;
  final double? contentWidth;
  const ViewportBarChart({
    super.key,
    required this.data,
    required this.info,
    this.controller,
    this.contentWidth,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        contentWidth ?? constraints.maxWidth,
        constraints.maxHeight,
      );
      final chart = SizedBox(
        width: size.width,
        height: size.height,
        child: BarChart(
          data.copyWith(
            barTouchData: BarTouchData(
              enabled: false,
              handleBuiltInTouches: false,
            ),
          ),
          swapAnimationDuration: const Duration(milliseconds: 350),
          swapAnimationCurve: Curves.easeOutCubic,
        ),
      );
      return ChartInfoRegion(
        changes: controller,
        resolve: (position, _) {
          final offset = controller?.hasClients == true
              ? controller!.offset
              : 0.0;
          final selection = barSelectionAt(
            data,
            size,
            position.translate(offset, 0),
          );
          return selection == null
              ? null
              : info(selection.group, selection.rod);
        },
        child: controller == null
            ? chart
            : Scrollbar(
                controller: controller,
                thumbVisibility: size.width > constraints.maxWidth,
                child: SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: chart,
                ),
              ),
      );
    },
  );
}
