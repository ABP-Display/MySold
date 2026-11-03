import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/data/transport_policy.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/models/stats_year.dart';
import 'package:mysold/widgets/stats_year_picker.dart';

void main() {
  test(
    'Year uses one input pass, December M-1, matching days and real daily averages',
    () {
      var passes = 0;
      Iterable<MonthlyOperation> operations() sync* {
        passes++;
        for (final (id, month, day, amount) in [
          ('dec', 12, 1, 310.0),
          ('jan', 1, 1, 62.0),
          ('oct', 10, 1, 150.0),
          ('late', 10, 29, 160.0),
          ('nov', 11, 1, 300.0),
          ('future', 12, 2, 999.0),
        ]) {
          yield MonthlyOperation(
            id: id,
            type: 'expense',
            amount: amount,
            date: DateTime(id == 'dec' ? 2025 : 2026, month, day),
          );
        }
      }

      final data = StatsYear.build(
        year: 2026,
        now: DateTime(2026, 11, 15),
        transactions: operations(),
      );
      expect(passes, 1);
      expect(data.values(MonthlySeries.expense).length, 12);
      expect(data.values(MonthlySeries.expense, previous: true).first, 310);
      expect(data.values(MonthlySeries.expense, previous: true)[10], 150);
      expect(data.values(MonthlySeries.expense, dailyAverage: true)[10], 20);
      expect(
        data.values(
          MonthlySeries.expense,
          dailyAverage: true,
          previous: true,
        )[10],
        10,
      );
      expect(data.values(MonthlySeries.expense).last, isNull);
      expect(data.totals.expense, 672);
      expect(data.projection.month, DateTime(2026, 11));
      final full = StatsYear.build(
        year: 2026,
        now: DateTime(2026, 11, 15),
        transactions: operations(),
        sameDay: false,
      );
      expect(full.values(MonthlySeries.expense, previous: true)[10], 310);
      expect(
        full.values(
          MonthlySeries.expense,
          previous: true,
          dailyAverage: true,
        )[10],
        10,
      );
      final past = StatsYear.build(
        year: 2026,
        now: DateTime(2027),
        transactions: operations(),
      );
      expect(past.sameDay, false);
      expect(past.projection.month, DateTime(2026, 12));
      expect(past.values(MonthlySeries.expense).last, 999);
    },
  );
  test('Remote HTTP cannot send credentials; localhost dev and HTTPS work', () {
    for (final origin in [
      'https://finances.example.test',
      'http://localhost:28085',
      'http://127.0.0.1:28085',
      'http://[::1]:28085',
    ]) {
      expect(isSecureApiOrigin(Uri.parse(origin)), true);
    }
    for (final origin in [
      'http://example.test',
      'http://192.168.1.2:28085',
      'http://localhost.evil.test',
      'ftp://localhost',
    ]) {
      expect(isSecureApiOrigin(Uri.parse(origin)), false);
    }
  });
  testWidgets(
    'Year picker accepts a distant year and rejects invalid input without month controls',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    selected = await chooseStatsYear(context, 2026),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('stats-year-input')),
        '0',
      );
      await tester.tap(find.text('Afficher'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('stats-year-input')),
        '2031',
      );
      await tester.tap(find.text('Afficher'));
      await tester.pumpAndSettle();
      expect(selected, 2031);
    },
  );
}
