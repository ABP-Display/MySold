import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/models/month_chart_series.dart';

void main() {
  test('Daily, grouped and weekly totals agree to the cent', () {
    final data = MonthChartSeries.build(DateTime(2026, 11), [
      MonthChartEntry(DateTime(2026, 11, 1), 29.14, 'a'),
      MonthChartEntry(DateTime(2026, 11, 9), 48.3, 'a'),
      MonthChartEntry(DateTime(2026, 11, 9), .1 + .2, 'b'),
      MonthChartEntry(DateTime(2026, 10, 9), 100, 'a'),
      MonthChartEntry(DateTime(2026, 11, 3), double.nan, 'a'),
      MonthChartEntry(DateTime(2026, 11, 4), double.infinity, 'a'),
      MonthChartEntry(DateTime(2026, 11, 5), 0, null),
    ], now: DateTime(2026, 11, 18));
    expect(data.total, 7774);
    expect(data.count, 3);
    expect(data.groups, {'a': 7744, 'b': 30});
    expect(data.daily[8], 4860);
    expect(data.cumulative.last, data.total);
    expect(data.weeks.fold(0, (n, w) => n + w.total), data.total);
    expect(data.visibleDays, 18);
  });
  test(
    'Calendar weeks cover each day once, including leap and six-week months',
    () {
      for (final month in [
        DateTime(2021, 2),
        DateTime(2024, 2),
        DateTime(2026, 8),
        DateTime(2026, 11),
      ]) {
        final data = MonthChartSeries.build(
          month,
          [],
          now: DateTime(2026, 11, 18),
        );
        final days = [
          for (final w in data.weeks)
            for (var d = w.start.day; d <= w.end.day; d++) d,
        ];
        expect(days.length, DateTime(month.year, month.month + 1, 0).day);
        expect(days.toSet().length, days.length);
        expect(
          data.weeks.skip(1).every((w) => w.start.weekday == DateTime.monday),
          isTrue,
        );
      }
    },
  );
  test(
    'A recorded future contribution is visible without fabricating a projection',
    () {
      final data = MonthChartSeries.build(DateTime(2026, 11), [
        MonthChartEntry(DateTime(2026, 11, 25), 120, 'fund'),
      ], now: DateTime(2026, 11, 18));
      expect(data.visibleDays, 25);
      expect(data.cumulative[23], 0);
      expect(data.cumulative[24], 12000);
    },
  );
  test('Distinct IDs and missing references stay separate and sorted', () {
    final data = MonthChartSeries.build(DateTime(2026, 6), [
      MonthChartEntry(DateTime(2026, 6, 3), 10, 'a'),
      MonthChartEntry(DateTime(2026, 6, 3), 20, 'b'),
      MonthChartEntry(DateTime(2026, 6, 3), 5, null),
    ], now: DateTime(2026, 11, 18));
    expect(data.groups.keys.toList(), ['b', 'a', null]);
    expect(data.visibleDays, 30);
    expect(() => data.daily[0] = 100, throwsUnsupportedError);
    expect(() => data.weeks.first.amounts['a'] = 100, throwsUnsupportedError);
  });
}
