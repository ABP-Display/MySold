import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MonthMoneyAxis {
  final int maximumCents;
  MonthMoneyAxis(Iterable<int> totals)
    : maximumCents = totals.fold(1, math.max);

  double get maximum => maximumCents / 100;
  double get interval {
    final raw = math.max(.01, maximum / 3);
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    return [1, 2, 5, 10].firstWhere((n) => n * magnitude >= raw) * magnitude;
  }

  TextStyle _style(BuildContext context) =>
      DefaultTextStyle.of(context).style.copyWith(
        fontSize: 9,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  double width(BuildContext context, String Function(int) money) {
    var width = 0.0;
    for (final value in [
      maximum,
      for (var v = 0.0; v < maximum; v += interval) v,
    ]) {
      final painter = TextPainter(
        text: TextSpan(
          text: money((value * 100).round()),
          style: _style(context),
        ),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      width = math.max(width, painter.width);
      painter.dispose();
    }
    return width + 8;
  }

  AxisTitles titles(
    BuildContext context,
    String Function(int) money,
  ) => AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: width(context, money),
      interval: interval,
      getTitlesWidget: (value, meta) {
        // Keep the exact maximum without crowding it with a nearby rounded tick.
        if (value < maximum - .000001 && maximum - value < interval * .5) {
          return const SizedBox.shrink();
        }
        return SideTitleWidget(
          axisSide: meta.axisSide,
          space: 4,
          fitInside: SideTitleFitInsideData.fromTitleMeta(
            meta,
            distanceFromEdge: 0,
          ),
          child: Text(money((value * 100).round()), style: _style(context)),
        );
      },
    ),
  );
}
