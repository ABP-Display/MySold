import 'monthly_analytics.dart';

/// Thirteen months are grouped once; each transaction participates in at most
/// two monthly comparisons. The chart itself always contains twelve points.
class StatsYear {
  final int year;
  final DateTime now;
  final bool sameDay;
  final List<MonthlyAnalytics> months;
  final MonthlyTotals totals;
  const StatsYear._(
    this.year,
    this.now,
    this.sameDay,
    this.months,
    this.totals,
  );
  bool get isFuture => year > now.year;
  MonthlyAnalytics get projection =>
      months[year == now.year ? now.month - 1 : 11];

  List<double?> values(
    MonthlySeries series, {
    bool previous = false,
    bool dailyAverage = false,
  }) => [
    for (final month in months)
      if (month.isFuture)
        null
      else
        (previous ? month.previous : month.current).value(series) /
            (dailyAverage
                ? (previous ? month.previousDays : month.elapsedDays)
                : 1),
  ];
  factory StatsYear.build({
    required int year,
    required DateTime now,
    required Iterable<MonthlyOperation> transactions,
    bool sameDay = true,
  }) {
    final grouped = <int, List<MonthlyOperation>>{};
    for (final tx in transactions) {
      grouped.putIfAbsent(tx.date.year * 12 + tx.date.month, () => []).add(tx);
    }
    final months = [
      for (var month = 1; month <= 12; month++)
        MonthlyAnalytics.build(
          month: DateTime(year, month),
          now: now,
          sameDayComparison: sameDay,
          transactions: [
            ...?grouped[year * 12 + month],
            ...?grouped[year * 12 + month - 1],
          ],
        ),
    ];
    double sum(double Function(MonthlyTotals) value) =>
        months
            .where((m) => !m.isFuture)
            .fold(0, (total, m) => total + (value(m.current) * 100).round()) /
        100;
    return StatsYear._(
      year,
      now,
      sameDay && year == now.year,
      List.unmodifiable(months),
      MonthlyTotals(
        income: sum((t) => t.income),
        expense: sum((t) => t.expense),
        investment: sum((t) => t.investment),
        transfer: sum((t) => t.transfer),
      ),
    );
  }
}
