import 'monthly_analytics.dart';

List<DateTime> yearToDateReferenceMonths(DateTime selected, DateTime now) {
  final current = DateTime(now.year, now.month);
  return List.unmodifiable([
    for (var month = 1; month < selected.month; month++)
      if (DateTime(selected.year, month).isBefore(current))
        DateTime(selected.year, month),
  ]);
}

/// Compare two independently loaded months. Summary/projection keep the full
/// observed month; both periods retain all their observed days.
class MonthComparison {
  final MonthlyAnalytics selected, reference;
  final Map<MonthlySeries, List<double>>? _meanDaily, _meanCumulative;
  final List<double>? _meanCounts;
  final List<DateTime> averageMonths;
  const MonthComparison(this.selected, this.reference)
    : _meanDaily = null,
      _meanCumulative = null,
      _meanCounts = null,
      averageMonths = const [];

  const MonthComparison._average(
    this.selected,
    this._meanDaily,
    this._meanCumulative,
    this._meanCounts,
    this.averageMonths,
  ) : reference = selected;

  factory MonthComparison.yearToDate(
    MonthlyAnalytics selected,
    Iterable<MonthlyAnalytics> months,
  ) {
    final unique = <DateTime, MonthlyAnalytics>{
      for (final month in months)
        if (month.month.year == selected.month.year &&
            month.month.isBefore(selected.month) &&
            !month.isCurrent &&
            !month.isFuture)
          month.month: month,
    };
    final dates = unique.keys.toList()..sort();
    final sources = [for (final date in dates) unique[date]!];
    final days = sources.fold(
      0,
      (max, month) => month.elapsedDays > max ? month.elapsedDays : max,
    );
    Map<MonthlySeries, List<double>> mean(bool cumulative) => {
      for (final series in MonthlySeries.values)
        series: List.unmodifiable(
          List.generate(days, (day) {
            var cents = 0;
            for (final source in sources) {
              final values = source.values(series, cumulative: cumulative);
              // Shorter months contribute no extra daily movement; their final
              // cumulative value remains part of the monthly average.
              final value = day < values.length
                  ? values[day]
                  : cumulative && values.isNotEmpty
                  ? values.last
                  : 0.0;
              cents += (value * 100).round();
            }
            return cents / sources.length / 100;
          }),
        ),
    };
    final counts = List<double>.unmodifiable(
      List.generate(
        days,
        (day) =>
            sources.fold(
              0,
              (sum, source) =>
                  sum +
                  (day < source.dailyCount.length ? source.dailyCount[day] : 0),
            ) /
            sources.length,
      ),
    );
    return MonthComparison._average(
      selected,
      Map.unmodifiable(mean(false)),
      Map.unmodifiable(mean(true)),
      counts,
      List.unmodifiable(dates),
    );
  }

  bool get isAverage => _meanDaily != null;

  DateTime get month => selected.month;
  DateTime get previousMonth => reference.month;
  bool get canCompare =>
      !selected.isFuture &&
      (isAverage ? averageMonths.isNotEmpty : !reference.isFuture);
  int get elapsedDays => selected.elapsedDays;
  int get previousDays =>
      isAverage ? _meanCounts!.length : reference.elapsedDays;
  List<int> get dailyCount => selected.dailyCount.take(elapsedDays).toList();
  List<num> get previousDailyCount => isAverage
      ? _meanCounts!
      : reference.dailyCount.take(previousDays).toList();
  bool get hasActivity =>
      dailyCount.any((v) => v > 0) || previousDailyCount.any((v) => v > 0);

  List<double> values(
    MonthlySeries series, {
    bool previous = false,
    bool cumulative = true,
  }) {
    if (previous && isAverage) {
      return (cumulative ? _meanCumulative : _meanDaily)![series]!;
    }
    return (previous ? reference : selected)
        .values(series, cumulative: cumulative)
        .take(previous ? previousDays : elapsedDays)
        .toList(growable: false);
  }

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
