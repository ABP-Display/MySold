import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/models/month_comparison.dart';

MonthlyOperation tx(
  String id,
  int month,
  int day,
  double amount, {
  int year = 2026,
  String type = 'expense',
}) => MonthlyOperation(
  id: id,
  type: type,
  amount: amount,
  date: DateTime(year, month, day),
);
MonthlyAnalytics month(
  int month,
  Iterable<MonthlyOperation> ops, {
  int year = 2026,
  DateTime? now,
}) => MonthlyAnalytics.build(
  month: DateTime(year, month),
  now: now ?? DateTime(2026, 11, 15),
  transactions: ops,
);

void main() {
  test(
    'Year-to-date window excludes selected, current, future and other-year months',
    () {
      final now = DateTime(2026, 4, 15);
      expect(yearToDateReferenceMonths(DateTime(2026, 4), now), [
        DateTime(2026, 1),
        DateTime(2026, 2),
        DateTime(2026, 3),
      ]);
      expect(yearToDateReferenceMonths(DateTime(2026, 1), now), isEmpty);
      expect(yearToDateReferenceMonths(DateTime(2026, 7), now).length, 3);
      expect(yearToDateReferenceMonths(DateTime(2027, 7), now), isEmpty);
      expect(yearToDateReferenceMonths(DateTime(2025, 12), now).length, 11);
    },
  );

  test(
    'Monthly average includes empty months and leaves the selected summary unchanged',
    () {
      final selected = month(3, [tx('selected', 3, 2, 120)]);
      final data = MonthComparison.yearToDate(selected, [
        month(1, [tx('january', 1, 2, 300)]),
        month(2, []),
      ]);
      expect(data.isAverage, isTrue);
      expect(data.canCompare, isTrue);
      expect(data.averageMonths, [DateTime(2026, 1), DateTime(2026, 2)]);
      expect(data.previous.expense, 150);
      expect(data.previousDailyCount[1], .5);
      expect(data.values(MonthlySeries.expense, previous: true)[1], 150);
      expect(data.current.expense, 120);
      expect(selected.current.expense, 120);
      expect(() => data.averageMonths.clear(), throwsUnsupportedError);
    },
  );

  test(
    'Short months contribute zero daily movement and keep their final cumulative amount',
    () {
      final data = MonthComparison.yearToDate(month(3, []), [
        month(1, [tx('jan-last', 1, 31, 100)]),
        month(2, [tx('feb-last', 2, 28, 60)]),
      ]);
      final daily = data.values(
        MonthlySeries.expense,
        previous: true,
        cumulative: false,
      );
      final cumulative = data.values(MonthlySeries.expense, previous: true);
      expect(daily.length, 31);
      expect(daily[27], 30);
      expect(daily[28], 0);
      expect(daily[30], 50);
      expect(cumulative[28], 30);
      expect(cumulative.last, 80);
      expect(data.previous.expense, 80);
    },
  );

  test('Mean keeps cents, negative remainder and transfers separate', () {
    final data = MonthComparison.yearToDate(month(3, []), [
      month(1, [
        tx('salary', 1, 1, 100, type: 'income'),
        tx('expense', 1, 1, 200.1),
        tx('invest', 1, 1, 50, type: 'investment'),
        tx('transfer', 1, 1, 400, type: 'transfer'),
      ]),
      month(2, [tx('expense', 2, 1, .2)]),
    ]);
    expect(data.previous.income, 50);
    expect(data.previous.expense, 100.15);
    expect(data.previous.investment, 25);
    expect(data.previous.transfer, 200);
    expect(data.previous.available, -75.15);
    expect(data.values(MonthlySeries.remaining, previous: true).last, -75.15);
  });

  test(
    'No history, duplicate months and uncompleted periods are handled safely',
    () {
      final now = DateTime(2026, 3, 15);
      final selected = month(4, [], now: now);
      final january = month(1, [tx('january', 1, 1, 10)], now: now);
      final mean = MonthComparison.yearToDate(selected, [
        january,
        january,
        month(2, [], now: now),
        month(3, [], now: now),
        selected,
        month(12, [], year: 2025, now: now),
      ]);
      expect(mean.averageMonths.length, 2);
      expect(mean.previous.expense, 5);
      expect(mean.canCompare, isFalse);
      final empty = MonthComparison.yearToDate(month(1, []), []);
      expect(empty.previousDays, 0);
      expect(empty.previous.expense, 0);
      expect(empty.canCompare, isFalse);
      for (final series in MonthlySeries.values) {
        expect(empty.values(series, previous: true), isEmpty);
      }
      final leap = MonthComparison.yearToDate(month(3, [], year: 2024), [
        month(2, [tx('leap', 2, 29, 42, year: 2024)], year: 2024),
      ]);
      expect(leap.values(MonthlySeries.expense, previous: true).length, 29);
      expect(leap.previous.expense, 42);
    },
  );

  test(
    'Arbitrary months compare actual daily and running totals, without changing the summary',
    () {
      final a = month(11, [
        tx('a', 11, 1, 50),
        tx('b', 11, 14, 25),
        tx('future', 11, 16, 999),
      ]);
      final b = month(3, [tx('old', 3, 1, 40), tx('late', 3, 30, 100)]);
      final equal = MonthComparison(a, b);
      expect(equal.current.expense, 75);
      expect(equal.previous.expense, 140);
      expect(equal.values(MonthlySeries.expense).length, 15);
      expect(equal.values(MonthlySeries.expense, previous: true).length, 31);
      expect(equal.values(MonthlySeries.expense, cumulative: false)[13], 25);
      expect(equal.values(MonthlySeries.expense)[13], 75);
      final full = MonthComparison(a, b);
      expect(full.previous.expense, 140);
      expect(full.previousDays, 31);
      expect(b.current.expense, 140);
      expect(a.current.expense, 75);
      expect(a.projectedAvailable, -150);
    },
  );
  test(
    'Complete historical months keep their own length, including leap years',
    () {
      final now = DateTime(2025);
      final a = month(
        3,
        [tx('last', 3, 31, 100, year: 2024)],
        year: 2024,
        now: now,
      );
      final b = month(
        2,
        [tx('leap', 2, 29, 20, year: 2024)],
        year: 2024,
        now: now,
      );
      final equal = MonthComparison(a, b);
      expect(equal.elapsedDays, 31);
      expect(equal.previousDays, 29);
      expect(equal.current.expense, 100);
      expect(equal.previous.expense, 20);
      expect(MonthComparison(a, b).current.expense, 100);
    },
  );
  test(
    'Same month, cross-year reference, transfer counts and negative remaining values are supported',
    () {
      final a = month(1, [
        tx('salary', 1, 1, 100, type: 'income'),
        tx('cost', 1, 2, 200),
        tx('transfer', 1, 3, 50, type: 'transfer'),
      ]);
      final b = month(12, [tx('old', 12, 1, 20, year: 2025)], year: 2025);
      final data = MonthComparison(a, b);
      expect(data.current.available, -100);
      expect(data.current.transfer, 50);
      expect(data.dailyCount.fold(0, (a, b) => a + b), 3);
      expect(data.previous.expense, 20);
      expect(
        MonthComparison(a, a).current.expense,
        MonthComparison(a, a).previous.expense,
      );
    },
  );
  test(
    'Future periods and empty data do not invent observed days or amounts',
    () {
      final current = month(11, []),
          future = month(12, [tx('future', 12, 1, 500)]);
      final data = MonthComparison(current, future);
      expect(data.canCompare, false);
      expect(data.previousDays, 0);
      expect(data.values(MonthlySeries.expense, previous: true), isEmpty);
      expect(data.hasActivity, false);
    },
  );
}
