import 'package:mysold/models/transaction_model.dart';

const chartInvestmentTypes = ['etf', 'stock', 'crypto', 'bond', 'other'];

class MonthCategoryTotal {
  final String? id;
  final int cents, count;
  const MonthCategoryTotal(this.id, this.cents, this.count);
}

class InvestmentWeek {
  final DateTime start, end; // Inclusive, clipped to the selected month.
  final Map<String, int> amounts;
  const InvestmentWeek(this.start, this.end, this.amounts);
  int get total => amounts.values.fold(0, (a, b) => a + b);
  List<DateTime> get days => [
    for (var day = start.day; day <= end.day; day++)
      DateTime(start.year, start.month, day),
  ];
}

class TransferFlow {
  final String source, target;
  final int cents, count;
  const TransferFlow(this.source, this.target, this.cents, this.count);
}

class TransferDiagram {
  final List<String> sources, targets;
  final Map<String, int> sourceTotals, targetTotals;
  final List<TransferFlow> flows;
  final int groupedSources, groupedTargets;
  const TransferDiagram(
    this.sources,
    this.targets,
    this.sourceTotals,
    this.targetTotals,
    this.flows,
    this.groupedSources,
    this.groupedTargets,
  );

  factory TransferDiagram.fromFlows(
    List<TransferFlow> flows, {
    int maximumNodes = 4,
  }) {
    assert(maximumNodes >= 2);
    Map<String, int> totals(bool source) {
      final result = <String, int>{};
      for (final flow in flows) {
        final key = source ? flow.source : flow.target;
        result[key] = (result[key] ?? 0) + flow.cents;
      }
      return result;
    }

    final sourceTotals = totals(true), targetTotals = totals(false);
    List<String> sorted(Map<String, int> values) =>
        values.keys.toList()..sort((a, b) {
          final order = values[b]!.compareTo(values[a]!);
          return order == 0 ? a.compareTo(b) : order;
        });
    final sources = sorted(sourceTotals), targets = sorted(targetTotals);
    final keepSources = sources
        .take(sources.length > maximumNodes ? maximumNodes - 1 : maximumNodes)
        .toSet();
    final keepTargets = targets
        .take(targets.length > maximumNodes ? maximumNodes - 1 : maximumNodes)
        .toSet();
    final grouped = <(String, String), (int, int)>{};
    for (final flow in flows) {
      final key = (
        keepSources.contains(flow.source) ? flow.source : 'group:source',
        keepTargets.contains(flow.target) ? flow.target : 'group:target',
      );
      final previous = grouped[key] ?? (0, 0);
      grouped[key] = (previous.$1 + flow.cents, previous.$2 + flow.count);
    }
    final result = [
      for (final entry in grouped.entries)
        TransferFlow(
          entry.key.$1,
          entry.key.$2,
          entry.value.$1,
          entry.value.$2,
        ),
    ]..sort((a, b) => b.cents.compareTo(a.cents));
    Map<String, int> aggregate(bool source) {
      final values = <String, int>{};
      for (final flow in result) {
        final key = source ? flow.source : flow.target;
        values[key] = (values[key] ?? 0) + flow.cents;
      }
      return values;
    }

    return TransferDiagram(
      [...keepSources, if (sources.length > keepSources.length) 'group:source'],
      [...keepTargets, if (targets.length > keepTargets.length) 'group:target'],
      aggregate(true),
      aggregate(false),
      result,
      sources.length - keepSources.length,
      targets.length - keepTargets.length,
    );
  }
}

class MonthChartData {
  final DateTime month;
  final Map<String, List<MonthCategoryTotal>> categories;
  final List<InvestmentWeek> weeks;
  final Map<int, Map<String, int>> investmentDays;
  final List<TransferFlow> transfers;
  const MonthChartData._(
    this.month,
    this.categories,
    this.weeks,
    this.investmentDays,
    this.transfers,
  );

  factory MonthChartData.build(
    DateTime date,
    List<TransactionModel> transactions, {
    Map<String, String> investmentTypes = const {},
  }) {
    final month = DateTime(date.year, date.month);
    final last = DateTime(date.year, date.month + 1, 0);
    final categoryTotals = <String, Map<String?, (int, int)>>{
      'expense': {},
      'income': {},
    };
    final days = <int, Map<String, int>>{};
    final flows = <(String, String), (int, int)>{};
    for (final tx in transactions) {
      if (tx.date.year != month.year ||
          tx.date.month != month.month ||
          !tx.amount.isFinite)
        continue;
      final cents = (tx.amount.abs() * 100).round();
      if (cents <= 0) continue;
      if (tx.type == 'expense' || tx.type == 'income') {
        final items = categoryTotals[tx.type]!;
        final previous = items[tx.categoryId] ?? (0, 0);
        items[tx.categoryId] = (previous.$1 + cents, previous.$2 + 1);
      } else if (tx.type == 'investment') {
        final value = investmentTypes[tx.investmentId];
        final type = chartInvestmentTypes.contains(value) ? value! : 'other';
        final values = days.putIfAbsent(tx.date.day, () => {});
        values[type] = (values[type] ?? 0) + cents;
      } else if (tx.type == 'transfer') {
        final source = tx.investmentId != null && tx.investmentId!.isNotEmpty
            ? 'investment:${tx.investmentId}'
            : 'account:${tx.fromAccountId ?? ''}';
        final key = (source, 'account:${tx.toAccountId ?? ''}');
        final previous = flows[key] ?? (0, 0);
        flows[key] = (previous.$1 + cents, previous.$2 + 1);
      }
    }
    final weeks = <InvestmentWeek>[];
    var start = month;
    while (!start.isAfter(last)) {
      final proposed = DateTime(
        start.year,
        start.month,
        start.day + (7 - start.weekday),
      );
      final end = proposed.isAfter(last) ? last : proposed;
      final amounts = <String, int>{};
      for (var day = start.day; day <= end.day; day++) {
        for (final entry in (days[day] ?? const <String, int>{}).entries) {
          amounts[entry.key] = (amounts[entry.key] ?? 0) + entry.value;
        }
      }
      weeks.add(InvestmentWeek(start, end, Map.unmodifiable(amounts)));
      start = DateTime(end.year, end.month, end.day + 1);
    }
    return MonthChartData._(
      month,
      {
        for (final entry in categoryTotals.entries)
          entry.key:
              [
                for (final item in entry.value.entries)
                  MonthCategoryTotal(item.key, item.value.$1, item.value.$2),
              ]..sort((a, b) {
                final order = b.cents.compareTo(a.cents);
                return order == 0 ? (a.id ?? '').compareTo(b.id ?? '') : order;
              }),
      },
      List.unmodifiable(weeks),
      Map.unmodifiable(days),
      [
        for (final entry in flows.entries)
          TransferFlow(
            entry.key.$1,
            entry.key.$2,
            entry.value.$1,
            entry.value.$2,
          ),
      ]..sort((a, b) => b.cents.compareTo(a.cents)),
    );
  }

  int get investmentTotal => weeks.fold(0, (total, week) => total + week.total);
  int get transferTotal =>
      transfers.fold(0, (total, flow) => total + flow.cents);
}
