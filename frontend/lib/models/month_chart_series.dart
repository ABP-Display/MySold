import 'dart:math' as math;

class MonthChartEntry {
  final DateTime date;
  final double amount;
  final String? group;
  const MonthChartEntry(this.date, this.amount, this.group);
}

class MonthChartWeek {
  final DateTime start, end;
  final Map<String?, int> amounts;
  const MonthChartWeek(this.start, this.end, this.amounts);
  int get total => amounts.values.fold(0, (sum, value) => sum + value);
}

/// Local chart aggregates. Integer cents keep grouped and daily totals equal.
class MonthChartSeries {
  final DateTime month;
  final List<int> daily, cumulative;
  final List<MonthChartWeek> weeks;
  final Map<String?, int> groups;
  final int total, count, visibleDays;
  const MonthChartSeries._(
    this.month,
    this.daily,
    this.cumulative,
    this.weeks,
    this.groups,
    this.total,
    this.count,
    this.visibleDays,
  );

  factory MonthChartSeries.build(
    DateTime month,
    Iterable<MonthChartEntry> entries, {
    required DateTime now,
  }) {
    month = DateTime(month.year, month.month);
    final length = DateTime(month.year, month.month + 1, 0).day;
    final daily = List<int>.filled(length, 0);
    final days = <int, Map<String?, int>>{};
    final groups = <String?, int>{};
    var count = 0, total = 0, lastActive = 1;
    for (final entry in entries) {
      if (entry.date.year != month.year ||
          entry.date.month != month.month ||
          !entry.amount.isFinite)
        continue;
      final cents = (entry.amount.abs() * 100).round();
      if (cents == 0) continue;
      final day = entry.date.day;
      daily[day - 1] += cents;
      total += cents;
      count++;
      lastActive = math.max(lastActive, day);
      groups[entry.group] = (groups[entry.group] ?? 0) + cents;
      final bucket = days.putIfAbsent(day, () => {});
      bucket[entry.group] = (bucket[entry.group] ?? 0) + cents;
    }
    final sorted = groups.entries.toList()
      ..sort((a, b) {
        final order = b.value.compareTo(a.value);
        return order == 0 ? (a.key ?? '').compareTo(b.key ?? '') : order;
      });
    final weeks = <MonthChartWeek>[];
    var start = 1;
    while (start <= length) {
      final date = DateTime(month.year, month.month, start);
      final end = math.min(length, start + DateTime.sunday - date.weekday);
      final amounts = <String?, int>{};
      for (var day = start; day <= end; day++) {
        for (final entry in (days[day] ?? const <String?, int>{}).entries) {
          amounts[entry.key] = (amounts[entry.key] ?? 0) + entry.value;
        }
      }
      weeks.add(
        MonthChartWeek(
          date,
          DateTime(month.year, month.month, end),
          Map.unmodifiable(amounts),
        ),
      );
      start = end + 1;
    }
    var running = 0;
    final cumulative = [for (final value in daily) running += value];
    final visibleDays = month.year == now.year && month.month == now.month
        ? math.max(now.day, lastActive)
        : length;
    return MonthChartSeries._(
      month,
      List.unmodifiable(daily),
      List.unmodifiable(cumulative),
      List.unmodifiable(weeks),
      Map.unmodifiable(Map.fromEntries(sorted)),
      total,
      count,
      visibleDays,
    );
  }
}
