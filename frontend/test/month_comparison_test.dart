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
      expect(equal.previous.expense, 40);
      expect(equal.values(MonthlySeries.expense).length, 15);
      expect(equal.values(MonthlySeries.expense, previous: true).length, 15);
      expect(equal.values(MonthlySeries.expense, cumulative: false)[13], 25);
      expect(equal.values(MonthlySeries.expense)[13], 75);
      final full = MonthComparison(a, b, sameDay: false);
      expect(full.previous.expense, 140);
      expect(full.previousDays, 31);
      expect(b.current.expense, 140);
      expect(a.current.expense, 75);
      expect(a.projectedAvailable, -150);
    },
  );
  test(
    'Equal-date comparison bounds both historical months to February, including leap years',
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
      expect(equal.elapsedDays, 29);
      expect(equal.previousDays, 29);
      expect(equal.current.expense, 0);
      expect(equal.previous.expense, 20);
      expect(MonthComparison(a, b, sameDay: false).current.expense, 100);
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
      final data = MonthComparison(a, b, sameDay: false);
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
      expect(data.equalDates, false);
      expect(data.previousDays, 0);
      expect(data.values(MonthlySeries.expense, previous: true), isEmpty);
      expect(data.hasActivity, false);
    },
  );
}
