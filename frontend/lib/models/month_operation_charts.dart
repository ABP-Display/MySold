import 'month_chart_series.dart';

const investmentChartTypes = ['stock', 'etf', 'crypto', 'bond', 'other'];

class InvestmentSection {
  final int firstDay, lastDay;
  final Map<String, int> types;
  final Map<String?, int> assets;
  const InvestmentSection(this.firstDay, this.lastDay, this.types, this.assets);
  int get total => types.values.fold(0, (sum, value) => sum + value);
}

List<InvestmentSection> investmentSections(
  DateTime month,
  Iterable<MonthChartEntry> entries,
  Map<String, String> assetTypes,
) {
  final typeTotals = List.generate(4, (_) => <String, int>{});
  final assetTotals = List.generate(4, (_) => <String?, int>{});
  for (final entry in entries) {
    if (entry.date.year != month.year ||
        entry.date.month != month.month ||
        !entry.amount.isFinite)
      continue;
    final cents = (entry.amount.abs() * 100).round();
    if (cents == 0) continue;
    final index = ((entry.date.day - 1) ~/ 7).clamp(0, 3);
    final rawType = assetTypes[entry.group];
    final type = investmentChartTypes.contains(rawType) ? rawType! : 'other';
    typeTotals[index][type] = (typeTotals[index][type] ?? 0) + cents;
    assetTotals[index][entry.group] =
        (assetTotals[index][entry.group] ?? 0) + cents;
  }
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return List.unmodifiable([
    for (var i = 0; i < 4; i++)
      InvestmentSection(
        i * 7 + 1,
        i == 3 ? lastDay : (i + 1) * 7,
        Map.unmodifiable(typeTotals[i]),
        Map.unmodifiable(assetTotals[i]),
      ),
  ]);
}

class TransferChartEntry {
  final String? source, target;
  final bool sourceIsAsset;
  final DateTime date;
  final double amount;
  const TransferChartEntry(
    this.source,
    this.target,
    this.sourceIsAsset,
    this.date,
    this.amount,
  );
}

class TransferRoute {
  final String? source, target;
  final bool sourceIsAsset;
  final List<({DateTime date, int cents})> entries;
  const TransferRoute(
    this.source,
    this.target,
    this.sourceIsAsset,
    this.entries,
  );
  int get total => entries.fold(0, (sum, entry) => sum + entry.cents);
  (bool, String?, String?) get key => (sourceIsAsset, source, target);
}

List<TransferRoute> transferRoutes(
  DateTime month,
  Iterable<TransferChartEntry> entries,
) {
  final grouped =
      <(bool, String?, String?), List<({DateTime date, int cents})>>{};
  for (final entry in entries) {
    if (entry.date.year != month.year ||
        entry.date.month != month.month ||
        !entry.amount.isFinite)
      continue;
    final cents = (entry.amount.abs() * 100).round();
    if (cents == 0) continue;
    grouped
        .putIfAbsent((
          entry.sourceIsAsset,
          entry.source,
          entry.target,
        ), () => [])
        .add((date: entry.date, cents: cents));
  }
  final result =
      [
        for (final entry in grouped.entries)
          TransferRoute(
            entry.key.$2,
            entry.key.$3,
            entry.key.$1,
            List.unmodifiable(
              entry.value..sort((a, b) => b.date.compareTo(a.date)),
            ),
          ),
      ]..sort((a, b) {
        final order = b.total.compareTo(a.total);
        if (order != 0) return order;
        return a.key.toString().compareTo(b.key.toString());
      });
  return List.unmodifiable(result);
}
