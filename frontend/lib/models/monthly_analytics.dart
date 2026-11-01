double _round(double value) => (value * 100).round() / 100;

enum MonthlySeries { income, expense, investment, remaining, transfer }

class MonthlyOperation {
  final String id, type;
  final double amount;
  final DateTime date;
  const MonthlyOperation({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
  });
}

class MonthlyTotals {
  final double income, expense, investment, transfer;
  const MonthlyTotals({
    this.income = 0,
    this.expense = 0,
    this.investment = 0,
    this.transfer = 0,
  });
  double get available => _round(income - expense - investment);
  double value(MonthlySeries series) => switch (series) {
    MonthlySeries.income => income,
    MonthlySeries.expense => expense,
    MonthlySeries.investment => investment,
    MonthlySeries.remaining => available,
    MonthlySeries.transfer => transfer,
  };
}

/// One bounded pass over the selected month and M-1; all chart data is local.
class MonthlyAnalytics {
  final DateTime month, previousMonth;
  final int elapsedDays, daysInMonth, previousDays, financialOperationCount;
  final bool isCurrent, isFuture, sameDayComparison;
  final MonthlyTotals current, previous;
  final Map<MonthlySeries, List<double>> _daily, _previousDaily;
  final Map<MonthlySeries, List<double>> _cumulative, _previousCumulative;
  final List<int> dailyCount, previousDailyCount;
  const MonthlyAnalytics._({
    required this.month,
    required this.previousMonth,
    required this.elapsedDays,
    required this.daysInMonth,
    required this.previousDays,
    required this.isCurrent,
    required this.isFuture,
    required this.sameDayComparison,
    required this.current,
    required this.previous,
    required this.financialOperationCount,
    required Map<MonthlySeries, List<double>> daily,
    required Map<MonthlySeries, List<double>> previousDaily,
    required Map<MonthlySeries, List<double>> cumulative,
    required Map<MonthlySeries, List<double>> previousCumulative,
    required this.dailyCount,
    required this.previousDailyCount,
  }) : _daily = daily,
       _previousDaily = previousDaily,
       _cumulative = cumulative,
       _previousCumulative = previousCumulative;

  bool get hasActivity =>
      dailyCount.any((count) => count > 0) ||
      previousDailyCount.any((count) => count > 0);
  double? get projectedAvailable => isFuture || financialOperationCount == 0
      ? null
      : isCurrent
      ? _round(
          current.income -
              current.investment -
              current.expense / elapsedDays * daysInMonth,
        )
      : current.available;
  List<double> values(
    MonthlySeries series, {
    bool previous = false,
    bool cumulative = true,
  }) => (cumulative
      ? (previous ? _previousCumulative : _cumulative)
      : (previous ? _previousDaily : _daily))[series]!;

  factory MonthlyAnalytics.build({
    required DateTime month,
    required DateTime now,
    required Iterable<MonthlyOperation> transactions,
    bool sameDayComparison = true,
  }) {
    month = DateTime(month.year, month.month);
    final previousMonth = DateTime(month.year, month.month - 1);
    final nextMonth = DateTime(month.year, month.month + 1);
    final currentMonth = DateTime(now.year, now.month);
    final isCurrent = month == currentMonth,
        future = month.isAfter(currentMonth);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final previousLength = DateTime(month.year, month.month, 0).day;
    final elapsed = future
        ? 0
        : isCurrent
        ? now.day
        : days;
    final equal = sameDayComparison && isCurrent;
    final previousDays = equal
        ? elapsed.clamp(0, previousLength)
        : previousLength;
    final cutoff = DateTime(month.year, month.month, elapsed + 1);
    final previousCutoff = DateTime(
      previousMonth.year,
      previousMonth.month,
      previousDays + 1,
    );
    final daily = {
      for (final series in MonthlySeries.values)
        series: List<double>.filled(elapsed, 0),
    };
    final oldDaily = {
      for (final series in MonthlySeries.values)
        series: List<double>.filled(previousDays, 0),
    };
    final counts = List<int>.filled(elapsed, 0),
        oldCounts = List<int>.filled(previousDays, 0);
    var financialCount = 0;
    for (final tx in transactions) {
      final series = switch (tx.type) {
        'income' => MonthlySeries.income,
        'expense' => MonthlySeries.expense,
        'investment' => MonthlySeries.investment,
        'transfer' => MonthlySeries.transfer,
        _ => null,
      };
      if (series == null) continue;
      final value = tx.amount.abs();
      if (!tx.date.isBefore(month) &&
          tx.date.isBefore(nextMonth) &&
          tx.date.isBefore(cutoff)) {
        daily[series]![tx.date.day - 1] += value;
        counts[tx.date.day - 1]++;
        if (series != MonthlySeries.transfer) financialCount++;
      } else if (!tx.date.isBefore(previousMonth) &&
          tx.date.isBefore(month) &&
          tx.date.isBefore(previousCutoff)) {
        oldDaily[series]![tx.date.day - 1] += value;
        oldCounts[tx.date.day - 1]++;
      }
    }
    void complete(Map<MonthlySeries, List<double>> values, int length) {
      for (var day = 0; day < length; day++) {
        for (final series in MonthlySeries.values.where(
          (s) => s != MonthlySeries.remaining,
        )) {
          values[series]![day] = _round(values[series]![day]);
        }
        values[MonthlySeries.remaining]![day] = _round(
          values[MonthlySeries.income]![day] -
              values[MonthlySeries.expense]![day] -
              values[MonthlySeries.investment]![day],
        );
      }
    }

    complete(daily, elapsed);
    complete(oldDaily, previousDays);
    Map<MonthlySeries, List<double>> cumulative(
      Map<MonthlySeries, List<double>> values,
    ) => {
      for (final entry in values.entries) entry.key: _accumulate(entry.value),
    };
    final sums = cumulative(daily), oldSums = cumulative(oldDaily);
    MonthlyTotals totals(Map<MonthlySeries, List<double>> values) {
      double last(MonthlySeries series) =>
          values[series]!.isEmpty ? 0 : values[series]!.last;
      return MonthlyTotals(
        income: last(MonthlySeries.income),
        expense: last(MonthlySeries.expense),
        investment: last(MonthlySeries.investment),
        transfer: last(MonthlySeries.transfer),
      );
    }

    return MonthlyAnalytics._(
      month: month,
      previousMonth: previousMonth,
      elapsedDays: elapsed,
      daysInMonth: days,
      previousDays: previousDays,
      isCurrent: isCurrent,
      isFuture: future,
      sameDayComparison: equal,
      current: totals(sums),
      previous: totals(oldSums),
      financialOperationCount: financialCount,
      daily: daily,
      previousDaily: oldDaily,
      cumulative: sums,
      previousCumulative: oldSums,
      dailyCount: counts,
      previousDailyCount: oldCounts,
    );
  }
  static List<double> _accumulate(List<double> values) {
    var total = 0.0;
    return List.unmodifiable([
      for (final value in values) total = _round(total + value),
    ]);
  }
}
