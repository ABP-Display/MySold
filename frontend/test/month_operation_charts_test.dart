import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/models/month_chart_series.dart';
import 'package:mysold/models/month_operation_charts.dart';

void main() {
  test('Four sections cover 28, 29, 30 and 31 days without gaps', () {
    for (final date in [
      DateTime(2026, 2),
      DateTime(2024, 2),
      DateTime(2026, 11),
      DateTime(2026, 12),
    ]) {
      final sections = investmentSections(
        date,
        [
          for (
            var day = 1;
            day <= DateTime(date.year, date.month + 1, 0).day;
            day++
          )
            MonthChartEntry(DateTime(date.year, date.month, day), 1, 'a'),
        ],
        {'a': 'etf'},
      );
      expect(sections.length, 4);
      expect(sections.map((s) => s.firstDay), [1, 8, 15, 22]);
      expect(sections.take(3).map((s) => s.lastDay), [7, 14, 21]);
      expect(sections.last.lastDay, DateTime(date.year, date.month + 1, 0).day);
      expect(sections.map((s) => s.total), [
        700,
        700,
        700,
        (sections.last.lastDay - 21) * 100,
      ]);
    }
  });
  test('Section percentages use money, assets and cents are conserved', () {
    final sections = investmentSections(
      DateTime(2026, 11),
      [
        MonthChartEntry(DateTime(2026, 11, 7), 29.14, 'a'),
        MonthChartEntry(DateTime(2026, 11, 7), 48.3, 'a'),
        MonthChartEntry(DateTime(2026, 11, 7), 22.56, 'b'),
        MonthChartEntry(DateTime(2026, 11, 8), 10, 'missing'),
        MonthChartEntry(DateTime(2026, 10, 7), 900, 'a'),
        MonthChartEntry(DateTime(2026, 11, 7), double.nan, 'a'),
      ],
      {'a': 'etf', 'b': 'crypto'},
    );
    expect(sections.first.total, 10000);
    expect(sections.first.types, {'etf': 7744, 'crypto': 2256});
    expect(sections.first.assets, {'a': 7744, 'b': 2256});
    expect(sections[1].types, {'other': 1000});
    expect(sections[2].total, 0);
    expect(() => sections.first.types['etf'] = 0, throwsUnsupportedError);
  });
  test(
    'Transfers group by IDs and direction, assets never collide with accounts',
    () {
      final date = DateTime(2026, 11);
      final routes = transferRoutes(date, [
        TransferChartEntry('a', 'b', false, DateTime(2026, 11, 1), 29.14),
        TransferChartEntry('a', 'b', false, DateTime(2026, 11, 2), 48.3),
        TransferChartEntry('b', 'a', false, DateTime(2026, 11, 3), 5),
        TransferChartEntry('a', 'b', true, DateTime(2026, 11, 4), 8),
        TransferChartEntry('a', 'b', false, DateTime(2026, 10, 4), 200),
        TransferChartEntry(
          'a',
          'b',
          false,
          DateTime(2026, 11, 4),
          double.infinity,
        ),
      ]);
      expect(routes.length, 3);
      expect(routes.first.total, 7744);
      expect(routes.first.entries.map((e) => e.date.day), [2, 1]);
      expect(routes.fold(0, (sum, r) => sum + r.total), 9044);
      expect(routes.where((r) => r.sourceIsAsset).single.total, 800);
      expect(() => routes.first.entries.clear(), throwsUnsupportedError);
    },
  );
}
