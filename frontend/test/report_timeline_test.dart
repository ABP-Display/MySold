import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/services/report_timeline.dart';

({DateTime date, String type, double amount}) tx(
  DateTime date,
  String type,
  double amount,
) => (date: date, type: type, amount: amount);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M-1 handles January and leap February', () {
    expect(previousReportMonth(DateTime(2026, 1, 15)), DateTime(2025, 12));
    expect(previousReportMonth(DateTime(2024, 3, 31)), DateTime(2024, 2));
    expect(
      DateTime(
        2024,
        3,
      ).difference(previousReportMonth(DateTime(2024, 3))).inDays,
      29,
    );
  });

  test('daily cents, empty days, limits and transfers are correct', () {
    final timeline = ReportTimeline.build(
      start: DateTime(2026, 10),
      end: DateTime(2026, 11),
      transactions: [
        tx(DateTime(2026, 10), 'income', 100),
        tx(DateTime(2026, 10, 2), 'expense', 0.1),
        tx(DateTime(2026, 10, 2, 23), 'expense', 0.2),
        tx(DateTime(2026, 10, 2), 'investment', 20),
        tx(DateTime(2026, 10, 2), 'transfer', 500),
        tx(DateTime(2026, 9, 30), 'expense', 999),
        tx(DateTime(2026, 11), 'income', 999),
      ],
    );
    expect(timeline.monthly, isFalse);
    expect(timeline.points.length, 31);
    expect(timeline.points[1].amount('expense'), 0.3);
    expect(timeline.points[1].amount('transfer'), 500);
    expect(timeline.points.last.available, 79.7);
    expect(timeline.points[2].amount('income'), 0);
  });

  test('annual, partial monthly periods and negative available', () {
    final timeline = ReportTimeline.build(
      start: DateTime(2026, 1, 15),
      end: DateTime(2027),
      transactions: [
        tx(DateTime(2026, 1, 14), 'income', 999),
        tx(DateTime(2026, 1, 15), 'expense', 50),
        tx(DateTime(2026, 12, 31), 'income', 10),
      ],
    );
    expect(timeline.monthly, isTrue);
    expect(timeline.points.length, 12);
    expect(timeline.points.first.available, -50);
    expect(timeline.points.last.available, -40);
  });

  test('empty day and invalid period', () {
    final timeline = ReportTimeline.build(
      transactions: [],
      start: DateTime(2026, 5),
      end: DateTime(2026, 5, 2),
    );
    expect(timeline.points.single.available, 0);
    expect(
      () => ReportTimeline.build(
        transactions: [],
        start: DateTime(2026),
        end: DateTime(2026),
      ),
      throwsArgumentError,
    );
  });
}
