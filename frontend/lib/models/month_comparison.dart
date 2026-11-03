import 'dart:math' as math;
import 'monthly_analytics.dart';

/// Compare two independently loaded months. Summary/projection keep the full
/// observed month; only this comparison is truncated by the equal-date filter.
class MonthComparison {
  final MonthlyAnalytics selected, reference;
  final bool sameDayComparison;
  const MonthComparison(this.selected, this.reference, {bool sameDay = true})
    : sameDayComparison = sameDay;

  DateTime get month => selected.month;
  DateTime get previousMonth => reference.month;
  bool get canCompare => !selected.isFuture && !reference.isFuture;
  bool get equalDates => sameDayComparison && canCompare;
  int get _commonDays => math.min(selected.elapsedDays, reference.elapsedDays);
  int get elapsedDays => equalDates ? _commonDays : selected.elapsedDays;
  int get previousDays => equalDates ? _commonDays : reference.elapsedDays;
  List<int> get dailyCount => selected.dailyCount.take(elapsedDays).toList();
  List<int> get previousDailyCount =>
      reference.dailyCount.take(previousDays).toList();
  bool get hasActivity =>
      dailyCount.any((v) => v > 0) || previousDailyCount.any((v) => v > 0);

  List<double> values(
    MonthlySeries series, {
    bool previous = false,
    bool cumulative = true,
  }) => (previous ? reference : selected)
      .values(series, cumulative: cumulative)
      .take(previous ? previousDays : elapsedDays)
      .toList(growable: false);

  MonthlyTotals _totals(bool previous) {
    double last(MonthlySeries series) {
      final points = values(series, previous: previous);
      return points.isEmpty ? 0 : points.last;
    }

    return MonthlyTotals(
      income: last(MonthlySeries.income),
      expense: last(MonthlySeries.expense),
      investment: last(MonthlySeries.investment),
      transfer: last(MonthlySeries.transfer),
    );
  }

  MonthlyTotals get current => _totals(false);
  MonthlyTotals get previous => _totals(true);
}
