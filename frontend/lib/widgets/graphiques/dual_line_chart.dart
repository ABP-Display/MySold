import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'package:mysold/screens/settings/currency_provider.dart';

class DualLineChart extends StatelessWidget {
  final List<double> brute; // épargne sans rendement
  final List<double> rendement; // épargne avec rendement

  const DualLineChart({
    super.key,
    required this.brute,
    required this.rendement,
  });

  @override
  Widget build(BuildContext context) {
    final all = [...brute, ...rendement];
    final minY = all.reduce((a, b) => a < b ? a : b);
    final maxY = all.reduce((a, b) => a > b ? a : b);
    // ignore: unused_local_variable
    final currency = Provider.of<CurrencyProvider>(context).currency;

    String formatValue(double value) {
      if (value >= 1000000) {
        return '${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
      } else if (value >= 1000) {
        return '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
      } else {
        return value.toStringAsFixed(0);
      }
    }

    return AspectRatio(
      aspectRatio: 1.8, // 👈 Choisis la proportion qui te convient
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                // ───────── AXES ─────────
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (maxY - minY) / 4,
                      reservedSize: 42,
                      getTitlesWidget:
                          (v, _) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              formatValue(v), //'${formatValue(v)} $currency'
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval:
                          (brute.length / 5)
                              .clamp(1, double.infinity)
                              .floorToDouble(),
                      getTitlesWidget:
                          (v, _) => Text(
                            '${v.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          ),
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                // ───────── COURBES ─────────
                lineBarsData: [
                  _bar(
                    brute,
                    Color(0xff0052ff),
                  ), //Theme.of(context).colorScheme.secondary
                  _bar(
                    rendement,
                    Color(0xff00c47a),
                  ), //Theme.of(context).colorScheme.primary
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LegendDot(color: Color(0xff0052ff), label: 'Épargne'),
              SizedBox(width: 12),
              _LegendDot(color: Color(0xff00c47a), label: 'Rendement'),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _bar(List<double> data, Color color) => LineChartBarData(
    spots: [
      for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i]),
    ],
    isCurved: true,
    dotData: FlDotData(show: false),
    belowBarData: BarAreaData(show: false),
    color: color,
    barWidth: 3,
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
