import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysold/widgets/graphiques/chart_info_region.dart';

class SimulationSeries {
  final String label;
  final List<double> values;
  final Color color;
  const SimulationSeries(this.label, this.values, this.color);
}

String simulationMoney(double value, String currency) =>
    NumberFormat.currency(locale: 'fr_FR', symbol: currency).format(value);

/// One responsive chart style for projections: explicit time units, zero-safe
/// axes and a shared tooltip contained inside the visible chart area.
class SimulationLineChart extends StatelessWidget {
  final List<SimulationSeries> series;
  final String currency;
  final bool annual;
  const SimulationLineChart({
    super.key,
    required this.series,
    required this.currency,
    this.annual = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final values = series.expand((line) => line.values);
    final low = math.min(0.0, values.reduce(math.min));
    final high = math.max(0.0, values.reduce(math.max));
    final range = math.max(1.0, high - low);
    final minY = low < 0 ? low - range * .08 : 0.0;
    final maxY = high + range * .12;
    final end = series.first.values.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            for (final line in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: line.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      line.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 260,
          child: ChartInfoRegion(
            resolve: (position, viewport) {
              const left = 48.0, right = 12.0;
              if (position.dx < left ||
                  position.dx > viewport.width - right ||
                  position.dy > viewport.height - 28)
                return null;
              final index =
                  (((position.dx - left) / (viewport.width - left - right)) *
                          end)
                      .round()
                      .clamp(0, end);
              return ChartInfo(
                annual ? 'Année $index' : 'Mois $index',
                series
                    .map(
                      (line) =>
                          '${line.label} : ${simulationMoney(line.values[index], currency)}',
                    )
                    .join('\n'),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 12, top: 8),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: end.toDouble(),
                  minY: minY,
                  maxY: maxY,
                  clipData: FlClipData.all(),
                  lineTouchData: LineTouchData(enabled: false),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: (maxY - minY) / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: colors.outline.withValues(alpha: .2),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: (maxY - minY) / 4,
                        getTitlesWidget: (value, _) => Text(
                          NumberFormat.compact(locale: 'fr_FR').format(value),
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
                        reservedSize: 28,
                        interval: math.max(1, (end / 4).ceil()).toDouble(),
                        getTitlesWidget: (value, _) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    for (final line in series)
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < line.values.length; i++)
                            FlSpot(i.toDouble(), line.values[i]),
                        ],
                        color: line.color,
                        barWidth: 2.5,
                        isCurved: false,
                        dotData: FlDotData(show: false),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Text(
          '${annual ? 'Durée en années' : 'Durée en mois'} · Montants en $currency',
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class SimulationCostPart {
  final String label;
  final double amount;
  final Color color;
  const SimulationCostPart(this.label, this.amount, this.color);
}

class SimulationCostChart extends StatelessWidget {
  final List<SimulationCostPart> parts;
  final String currency;
  const SimulationCostChart({
    super.key,
    required this.parts,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final visible = parts.where((part) => part.amount > 0).toList();
    final total = visible.fold(0.0, (sum, part) => sum + part.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: ChartInfoRegion(
            resolve: (position, viewport) {
              final delta =
                  position - Offset(viewport.width / 2, viewport.height / 2);
              if (delta.distance < 50 || delta.distance > 94 || total <= 0)
                return null;
              final angle =
                  (math.atan2(delta.dy, delta.dx) + math.pi / 2) %
                  (2 * math.pi);
              var boundary = 0.0;
              for (final part in visible) {
                boundary += part.amount / total * 2 * math.pi;
                if (angle <= boundary)
                  return ChartInfo(
                    part.label,
                    '${simulationMoney(part.amount, currency)} · ${(part.amount / total * 100).toStringAsFixed(1)} %',
                    color: part.color,
                  );
              }
              return null;
            },
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 50,
                sectionsSpace: 1,
                startDegreeOffset: -90,
                pieTouchData: PieTouchData(enabled: false),
                sections: [
                  for (final part in visible)
                    PieChartSectionData(
                      value: part.amount,
                      color: part.color,
                      radius: 40,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final part in parts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: part.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(part.label)),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    simulationMoney(part.amount, currency),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
