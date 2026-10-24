import 'package:mysold/widgets/graphiques/app_charts.dart';
import 'dart:math' as math;
import 'package:mysold/widgets/graphiques/chart_info_region.dart';
import 'package:mysold/widgets/graphiques/viewport_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';

class MonthGraph extends StatelessWidget {
  final List<TransactionModel> transactions;
  final Map<String, Map<String, dynamic>>
  categories; // id -> {name, color, icon, type}
  final Map<String, String> accountIds; // id -> nom
  final Map<String, String> investmentIds; // id -> nom
  final String type;

  const MonthGraph({
    super.key,
    required this.transactions,
    required this.categories,
    required this.accountIds,
    required this.investmentIds,
    required this.type,
  });

  // 🔹 Formatage compact des montants
  String _formatAmount(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  // 🔹 Calcul automatique de l’intervalle des Y
  double _calculateYAxisInterval(double maxY) {
    if (maxY <= 0) return 1;

    double rawInterval = maxY / 7;
    if (rawInterval <= 0) return 1;

    double magnitude = rawInterval.floorToDouble();
    double factor = [
      1.0,
      2.0,
      5.0,
      10.0,
    ].firstWhere((f) => rawInterval <= f * 10, orElse: () => 10.0);
    final interval = (magnitude / factor).ceilToDouble() * factor;
    return interval <= 0 ? 1 : interval;
  }

  String _compactAxisLabel(String value) {
    final clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= 10) return clean;

    final words = clean.split(' ');
    if (words.length >= 2) {
      final initials = words
          .take(3)
          .map((word) => word.isEmpty ? '' : word[0].toUpperCase())
          .join();
      if (initials.length >= 2) return initials;
    }

    return '${clean.substring(0, 9)}…';
  }

  Widget _bottomLabel(String label, TitleMeta meta) {
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10,
      child: SizedBox(
        width: 64,
        child: Center(
          child: Transform.rotate(
            angle: -0.42,
            alignment: Alignment.center,
            child: Text(
              _compactAxisLabel(label),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _sortedKeysByAmount(Map<String, double> data) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((entry) => entry.key).toList();
  }

  Color _categoryColorForName(String catName, List<TransactionModel> txs) {
    for (final tx in txs) {
      final category = categories[tx.categoryId];
      if (category?['name'] == catName) {
        return Color(category?['color'] ?? Colors.grey.value);
      }
    }
    return Colors.grey;
  }

  /// === TRANSFERTS ===
  Widget buildTransferChart(BuildContext context, List<TransactionModel> txs) {
    final currency = Provider.of<CurrencyProvider>(context).currency;
    final privacy = Provider.of<PrivacyProvider>(context);
    final filtered = txs.where((t) => t.type == 'transfer').toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Aucune donnée pour ce graphique"),
      );
    }

    final data = <String, double>{};
    for (var tx in filtered) {
      final from = accountIds[tx.fromAccountId] ?? "De";
      final to = accountIds[tx.toAccountId] ?? "À";
      final label = "$from → $to";
      data[label] = (data[label] ?? 0) + tx.amount.abs();
    }

    final sortedKeys = _sortedKeysByAmount(data);
    final rawMaxY = data.values.reduce((a, b) => a > b ? a : b) * 1.2;
    final maxY = rawMaxY <= 0 ? 1.0 : rawMaxY;
    final interval = _calculateYAxisInterval(maxY);

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.red,
    ];

    final barGroups = [
      for (int i = 0; i < sortedKeys.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data[sortedKeys[i]]!,
              width: 20,
              color: colors[i % colors.length],
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ],
        ),
    ];

    return _buildBarChartBase(
      sortedKeys,
      barGroups,
      maxY,
      interval,
      currency,
      privacy,
    );
  }

  /// === INVESTISSEMENTS ===
  Widget buildInvestmentChart(
    BuildContext context,
    List<TransactionModel> txs,
  ) {
    final currency = Provider.of<CurrencyProvider>(context).currency;
    final privacy = Provider.of<PrivacyProvider>(context);
    final filtered = txs.where((t) => t.type == 'investment').toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Aucune donnée pour ce graphique"),
      );
    }

    final data = <String, double>{};
    for (var tx in filtered) {
      final name = investmentIds[tx.investmentId] ?? "Investissement";
      data[name] = (data[name] ?? 0) + tx.amount.abs();
    }

    final sortedKeys = _sortedKeysByAmount(data);
    final rawMaxY = data.values.reduce((a, b) => a > b ? a : b) * 1.2;
    final maxY = rawMaxY <= 0 ? 1.0 : rawMaxY;
    final interval = _calculateYAxisInterval(maxY);

    final colors = [
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.blue,
    ];

    final barGroups = [
      for (int i = 0; i < sortedKeys.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data[sortedKeys[i]]!,
              width: 20,
              color: colors[i % colors.length],
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ],
        ),
    ];

    return _buildBarChartBase(
      sortedKeys,
      barGroups,
      maxY,
      interval,
      currency,
      privacy,
    );
  }

  /// === INCOME / EXPENSE ===
  Widget buildBarChart(
    BuildContext context,
    List<TransactionModel> txs,
    String type,
  ) {
    final currency = Provider.of<CurrencyProvider>(context).currency;
    final privacy = Provider.of<PrivacyProvider>(context);
    final filtered = txs.where((t) => t.type == type).toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Aucune donnée pour ce graphique"),
      );
    }

    final data = <String, double>{};
    for (var tx in filtered) {
      final catName = categories[tx.categoryId]?['name'] ?? 'Autre';
      data[catName] = (data[catName] ?? 0) + tx.amount.abs();
    }

    final sortedKeys = _sortedKeysByAmount(data);
    final rawMaxY = data.values.reduce((a, b) => a > b ? a : b) * 1.2;
    final maxY = rawMaxY <= 0 ? 1.0 : rawMaxY;
    final interval = _calculateYAxisInterval(maxY);

    final barGroups = [
      for (int i = 0; i < sortedKeys.length; i++)
        () {
          final key = sortedKeys[i];
          final value = data[key]!;
          final color = _categoryColorForName(key, filtered);

          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: value,
                width: 20,
                color: color,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
            ],
          );
        }(),
    ];

    return _buildBarChartBase(
      sortedKeys,
      barGroups,
      maxY,
      interval,
      currency,
      privacy,
    );
  }

  /// === PIE CHART (Revenus) ===
  Widget buildPieChart(BuildContext context, List<TransactionModel> txs) {
    final currency = Provider.of<CurrencyProvider>(context).currency;
    final privacy = Provider.of<PrivacyProvider>(context);
    final filtered = txs.where((t) => t.type == 'income').toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Aucune donnée pour ce graphique"),
      );
    }

    final data = <String, double>{};
    for (var tx in filtered) {
      final catName = categories[tx.categoryId]?['name'] ?? 'Autre';
      data[catName] = (data[catName] ?? 0) + tx.amount;
    }

    final total = data.values.fold(0.0, (a, b) => a + b);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const maxVisibleCategories = 5;
    final visibleEntries = sortedEntries.take(maxVisibleCategories).toList();
    final hiddenEntries = sortedEntries.skip(maxVisibleCategories).toList();
    final hiddenTotal = hiddenEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );
    final slices = [
      ...visibleEntries.map(
        (entry) => _IncomeSlice(
          label: entry.key,
          amount: entry.value,
          color: _categoryColorForName(entry.key, filtered),
        ),
      ),
      if (hiddenTotal > 0)
        _IncomeSlice(
          label: 'Autres (${hiddenEntries.length})',
          amount: hiddenTotal,
          color: Colors.grey.shade500,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: ChartInfoRegion(
              resolve: (position, size) {
                final relative =
                    position - Offset(size.width / 2, size.height / 2);
                if (relative.distance < 40 ||
                    relative.distance > 100 ||
                    total <= 0)
                  return null;
                final angle =
                    (math.atan2(relative.dy, relative.dx) + 2 * math.pi) %
                    (2 * math.pi);
                var endAngle = 0.0;
                for (final slice in slices) {
                  endAngle += slice.amount / total * 2 * math.pi;
                  if (angle <= endAngle)
                    return ChartInfo(
                      slice.label,
                      '${privacy.money(slice.amount, currency)} · ${(slice.amount / total * 100).toStringAsFixed(1)} %',
                      color: slice.color,
                    );
                }
                return null;
              },
              child: AppPieChart(
                PieChartData(
                  pieTouchData: PieTouchData(enabled: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: slices.map((slice) {
                    final percentage = (slice.amount / total) * 100;
                    return PieChartSectionData(
                      color: slice.color,
                      value: slice.amount,
                      title: percentage >= 6
                          ? '${percentage.toStringAsFixed(1)}%'
                          : '',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _incomeLegend(context, slices, privacy, currency),
        ],
      ),
    );
  }

  Widget _incomeLegend(
    BuildContext context,
    List<_IncomeSlice> slices,
    PrivacyProvider privacy,
    String currency,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 420
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 8,
          children: slices.map((slice) {
            return SizedBox(
              width: itemWidth,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      slice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    privacy.money(slice.amount, currency),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// === BASE POUR LES BARCHART ===
  Widget _buildBarChartBase(
    List<String> labels,
    List<BarChartGroupData> barGroups,
    double maxY,
    double interval,
    String currency,
    PrivacyProvider privacy,
  ) {
    final bottomReservedSize = labels.length <= 4 ? 42.0 : 60.0;
    final chartHeight = labels.length <= 4 ? 190.0 : 218.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: chartHeight,
        child: ViewportBarChart(
          info: (groupIndex, rodIndex) => ChartInfo(
            labels[groupIndex],
            privacy.money(
              barGroups[groupIndex].barRods[rodIndex].toY,
              currency,
            ),
            color: barGroups[groupIndex].barRods[rodIndex].color,
          ),
          data: BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barGroups: barGroups,
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: interval,
                  getTitlesWidget: (v, m) => Text(
                    privacy.hideAmounts
                        ? '**** $currency'
                        : '${_formatAmount(v)} $currency',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: bottomReservedSize,
                  getTitlesWidget: (v, m) {
                    final index = v.toInt();
                    if (index < 0 || index >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return _bottomLabel(labels[index], m);
                  },
                ),
              ),
            ),
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final privacy = Provider.of<PrivacyProvider>(context);
    if (privacy.hideAmounts) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: PrivacyChartMask(height: 180),
      );
    }

    if (type == 'income') return buildPieChart(context, transactions);
    if (type == 'transfer') return buildTransferChart(context, transactions);
    if (type == 'investment')
      return buildInvestmentChart(context, transactions);
    return buildBarChart(context, transactions, type);
  }
}

class _IncomeSlice {
  final String label;
  final double amount;
  final Color color;

  const _IncomeSlice({
    required this.label,
    required this.amount,
    required this.color,
  });
}
