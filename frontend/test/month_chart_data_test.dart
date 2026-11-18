@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/models/month_chart_data.dart';
import 'package:mysold/models/transaction_model.dart';
import 'fixtures/month_chart_fixture.dart';

void main() {
  MonthChartData sample() => MonthChartData.build(
    DateTime(2026, 6),
    monthChartFixture(),
    investmentTypes: chartFixtureTypes,
  );
  test('Sorted categories and exact totals in cents', () {
    final data = sample();
    expect(data.categories['expense']!.map((v) => v.cents), [
      36000,
      17000,
      10700,
      7000,
      6500,
      5900,
    ]);
    expect(data.categories['expense']!.fold(0, (n, v) => n + v.cents), 83100);
    expect(data.categories['income']!.fold(0, (n, v) => n + v.cents), 143830);
    expect(data.investmentTotal, 45000);
    expect(data.transferTotal, 65000);
  });
  test(
    'Calendar weeks drill down to the same daily totals without losing zero days',
    () {
      final data = sample();
      expect(data.weeks.map((w) => w.total), [10000, 15000, 9000, 8000, 3000]);
      expect(data.weeks[1].days.map((d) => d.day), [8, 9, 10, 11, 12, 13, 14]);
      expect(data.investmentDays[11], {'etf': 3000, 'stock': 2000});
      expect(data.investmentDays[13], isNull);
      expect(data.weeks.last.days.length, 2);
    },
  );
  test(
    'Every day belongs to exactly one week, including 4/5/6 week and leap months',
    () {
      for (final date in [
        DateTime(2021, 2),
        DateTime(2024, 2),
        DateTime(2026, 3),
        DateTime(2026, 8),
        DateTime(2026, 10),
      ]) {
        final data = MonthChartData.build(date, []);
        final days = data.weeks.expand((w) => w.days).toList();
        expect(days.length, DateTime(date.year, date.month + 1, 0).day);
        expect(days.map((d) => d.day).toSet().length, days.length);
        expect(days.every((d) => d.month == date.month), isTrue);
        expect(
          data.weeks.skip(1).every((w) => w.start.weekday == DateTime.monday),
          isTrue,
        );
      }
      expect(MonthChartData.build(DateTime(2026, 8), []).weeks.length, 6);
      expect(MonthChartData.build(DateTime(2021, 2), []).weeks.length, 4);
    },
  );
  test(
    'Only selected month and finite nonzero values; IDs remain separate',
    () {
      TransactionModel tx(
        double amount, {
        String? category,
        int month = 6,
        String type = 'expense',
        String? asset,
      }) => TransactionModel(
        amount: amount,
        date: DateTime(2026, month, 1),
        description: 'same label',
        type: type,
        categoryId: category,
        investmentId: asset,
      );
      final data = MonthChartData.build(DateTime(2026, 6), [
        tx(29.14, category: 'a'),
        tx(48.3, category: 'a'),
        tx(.1 + .2, category: 'b'),
        tx(10, month: 5),
        tx(0),
        tx(double.nan),
        tx(double.infinity),
        tx(5, type: 'investment', asset: 'unknown'),
      ]);
      expect(data.categories['expense']!.map((v) => v.cents), [7744, 30]);
      expect(data.investmentTotal, 500);
      expect(data.weeks.first.amounts, {'other': 500});
    },
  );
  test(
    'Transfers preserve distinct sides, asset withdrawals and all totals after grouping',
    () {
      final transactions = monthChartFixture();
      transactions.add(
        TransactionModel(
          amount: 20,
          date: DateTime(2026, 6, 10),
          description: 'Retrait',
          type: 'transfer',
          investmentId: 'etf',
          toAccountId: 'current',
        ),
      );
      final data = MonthChartData.build(DateTime(2026, 6), transactions);
      expect(
        data.transfers.any(
          (f) => f.source == 'investment:etf' && f.target == 'account:current',
        ),
        isTrue,
      );
      final flows = [
        ...data.transfers,
        for (var i = 0; i < 12; i++)
          TransferFlow('account:$i', 'account:${(i + 1) % 12}', 100 + i, 1),
      ];
      final diagram = TransferDiagram.fromFlows(flows);
      final total = flows.fold(0, (n, v) => n + v.cents);
      expect(diagram.sources.length, lessThanOrEqualTo(4));
      expect(diagram.targets.length, lessThanOrEqualTo(4));
      expect(diagram.sourceTotals.values.fold(0, (n, v) => n + v), total);
      expect(diagram.targetTotals.values.fold(0, (n, v) => n + v), total);
      expect(diagram.flows.fold(0, (n, v) => n + v.count), flows.length);
      expect(diagram.groupedSources, greaterThan(0));
    },
  );
}
