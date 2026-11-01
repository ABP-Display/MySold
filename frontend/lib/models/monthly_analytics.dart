double _round(double value) => (value * 100).round() / 100;

class MonthlyOperation {
  final String id, type, description;
  final String? categoryId;
  final double amount;
  final DateTime date;
  const MonthlyOperation({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.categoryId,
    this.description = '',
  });
}

class MonthlyTotals {
  final double income, expense, investment;
  const MonthlyTotals({this.income = 0, this.expense = 0, this.investment = 0});
  double get available => _round(income - expense - investment);
}

class MonthlyCategoryTotal {
  final String id, name;
  final double amount;
  const MonthlyCategoryTotal(this.id, this.name, this.amount);
}

enum MonthlyOperationOrder { amount, latest }

/// One pass over at most two months. No account snapshots or annual history.
class MonthlyAnalytics {
  final DateTime month, previousMonth;
  final int elapsedDays, daysInMonth, previousDays;
  final bool isCurrent, isFuture, sameDayComparison;
  final MonthlyTotals current, previous;
  final List<double> dailyExpense, previousDailyExpense;
  final List<MonthlyCategoryTotal> categories;
  final List<MonthlyOperation> operations;
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
    required this.dailyExpense,
    required this.previousDailyExpense,
    required this.categories,
    required this.operations,
  });

  int get expenseCount => operations.where((tx) => tx.type == 'expense').length;
  int get daysWithoutExpense =>
      elapsedDays -
      dailyExpense.take(elapsedDays).where((value) => value > 0).length;
  double get averagePurchase =>
      expenseCount == 0 ? 0 : current.expense / expenseCount;
  double get dailyAverage =>
      elapsedDays == 0 ? 0 : current.expense / elapsedDays;
  double? get projectedAvailable => isFuture || operations.isEmpty
      ? null
      : isCurrent
      ? _round(current.income - current.investment - dailyAverage * daysInMonth)
      : current.available;
  List<double> get cumulativeExpense =>
      _cumulative(dailyExpense.take(elapsedDays));
  List<double> get previousCumulativeExpense =>
      _cumulative(previousDailyExpense.take(previousDays));
  static List<double> _cumulative(Iterable<double> values) {
    var total = 0.0;
    return [for (final value in values) total = _round(total + value)];
  }

  List<MonthlyOperation> ranked(String type, MonthlyOperationOrder order) {
    final result = operations.where((tx) => tx.type == type).toList();
    result.sort((a, b) {
      final primary = order == MonthlyOperationOrder.amount
          ? b.amount.compareTo(a.amount)
          : b.date.compareTo(a.date);
      return primary == 0 ? a.id.compareTo(b.id) : primary;
    });
    return result.take(5).toList();
  }

  factory MonthlyAnalytics.build({
    required DateTime month,
    required DateTime now,
    required Iterable<MonthlyOperation> transactions,
    Map<String, String> categoryNames = const {},
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
    var income = 0.0, expense = 0.0, investment = 0.0;
    var oldIncome = 0.0, oldExpense = 0.0, oldInvestment = 0.0;
    final daily = List<double>.filled(days, 0),
        oldDaily = List<double>.filled(previousLength, 0);
    final grouped = <String, double>{};
    final operations = <MonthlyOperation>[];
    for (final tx in transactions) {
      if (tx.type != 'income' &&
          tx.type != 'expense' &&
          tx.type != 'investment')
        continue;
      final value = tx.amount.abs();
      if (!tx.date.isBefore(month) &&
          tx.date.isBefore(nextMonth) &&
          tx.date.isBefore(cutoff)) {
        operations.add(tx);
        if (tx.type == 'income') income += value;
        if (tx.type == 'investment') investment += value;
        if (tx.type == 'expense') {
          expense += value;
          daily[tx.date.day - 1] += value;
          final key = tx.categoryId ?? '';
          grouped[key] = (grouped[key] ?? 0) + value;
        }
      } else if (!tx.date.isBefore(previousMonth) &&
          tx.date.isBefore(month) &&
          tx.date.isBefore(previousCutoff)) {
        if (tx.type == 'income') oldIncome += value;
        if (tx.type == 'investment') oldInvestment += value;
        if (tx.type == 'expense') {
          oldExpense += value;
          oldDaily[tx.date.day - 1] += value;
        }
      }
    }
    final categories = [
      for (final row in grouped.entries)
        MonthlyCategoryTotal(
          row.key,
          categoryNames[row.key] ?? '',
          _round(row.value),
        ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    return MonthlyAnalytics._(
      month: month,
      previousMonth: previousMonth,
      elapsedDays: elapsed,
      daysInMonth: days,
      previousDays: previousDays,
      isCurrent: isCurrent,
      isFuture: future,
      sameDayComparison: equal,
      current: MonthlyTotals(
        income: _round(income),
        expense: _round(expense),
        investment: _round(investment),
      ),
      previous: MonthlyTotals(
        income: _round(oldIncome),
        expense: _round(oldExpense),
        investment: _round(oldInvestment),
      ),
      dailyExpense: daily.map(_round).toList(),
      previousDailyExpense: oldDaily.map(_round).toList(),
      categories: categories,
      operations: operations,
    );
  }
}
