import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/models/month_comparison.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/analytics/monthly_analytics_sections.dart';
import 'package:mysold/widgets/analytics/monthly_analysis_chart.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';
import 'package:mysold/widgets/month_page_header.dart';
import 'package:mysold/widgets/lazy_section_list.dart';

MonthlyOperation operation(
  String id,
  double amount,
  DateTime date, {
  String type = 'expense',
}) => MonthlyOperation(id: id, type: type, amount: amount, date: date);
MonthlyAnalytics fixture({bool full = false}) => MonthlyAnalytics.build(
  month: DateTime(2026, 11),
  now: DateTime(2026, 11, 15),
  sameDayComparison: !full,
  transactions: [
    operation('income', 2000, DateTime(2026, 11, 1), type: 'income'),
    operation('expense', 150, DateTime(2026, 11, 2)),
    operation('recent', 50, DateTime(2026, 11, 14)),
    operation('investment', 300, DateTime(2026, 11, 3), type: 'investment'),
    operation('transfer', 400, DateTime(2026, 11, 4), type: 'transfer'),
    operation('old-expense', 180, DateTime(2026, 10, 2)),
    operation('old-income', 1800, DateTime(2026, 10, 1), type: 'income'),
    operation('old-investment', 100, DateTime(2026, 10, 3), type: 'investment'),
    operation('old-transfer', 200, DateTime(2026, 10, 4), type: 'transfer'),
    operation('old-late', 20, DateTime(2026, 10, 25)),
  ],
);

MonthComparison comparisonFixture() {
  final ops = [
    operation('income', 2000, DateTime(2026, 11, 1), type: 'income'),
    operation('expense', 2500, DateTime(2026, 11, 2)),
    operation('invest', 300, DateTime(2026, 11, 3), type: 'investment'),
    operation('transfer', 400, DateTime(2026, 11, 4), type: 'transfer'),
    operation('old', 180, DateTime(2026, 10, 2)),
  ];
  return MonthComparison(
    MonthlyAnalytics.build(
      month: DateTime(2026, 11),
      now: DateTime(2026, 11, 15),
      transactions: ops,
    ),
    MonthlyAnalytics.build(
      month: DateTime(2026, 10),
      now: DateTime(2026, 11, 15),
      transactions: ops,
    ),
  );
}

void main() {
  test(
    'All series include daily and cumulative amounts, with transfers outside the remainder',
    () {
      final data = fixture();
      expect(data.current.income, 2000);
      expect(data.current.expense, 200);
      expect(data.current.investment, 300);
      expect(data.current.available, 1500);
      expect(data.current.transfer, 400);
      expect(data.projectedAvailable, 1300);
      for (final series in MonthlySeries.values) {
        expect(data.values(series).last, data.current.value(series));
        expect(
          data.values(series, previous: true).last,
          data.previous.value(series),
        );
      }
      expect(data.values(MonthlySeries.remaining, cumulative: false)[1], -150);
      expect(data.values(MonthlySeries.transfer, cumulative: false)[3], 400);
      expect(data.dailyCount[3], 1);
      expect(data.dailyCount.fold(0, (a, b) => a + b), 5);
      expect(data.financialOperationCount, 4);
    },
  );
  test(
    'Equal-date and full-month modes apply to all M-1 series without fabricating missing days',
    () {
      final equal = fixture(), full = fixture(full: true);
      expect(equal.previous.expense, 180);
      expect(full.previous.expense, 200);
      expect(equal.values(MonthlySeries.expense, previous: true).length, 15);
      expect(full.values(MonthlySeries.expense, previous: true).length, 31);
      expect(full.values(MonthlySeries.expense).length, 15);
      final march = MonthlyAnalytics.build(
        month: DateTime(2024, 3),
        now: DateTime(2024, 3, 31),
        transactions: [],
      );
      expect(march.previousDays, 29);
      expect(march.values(MonthlySeries.income, previous: true).length, 29);
    },
  );
  test(
    'January includes December M-1, future operations are excluded, and cents stay exact',
    () {
      final data = MonthlyAnalytics.build(
        month: DateTime(2027, 1),
        now: DateTime(2027, 1, 5),
        transactions: [
          operation('a', .1, DateTime(2027, 1, 5, 23)),
          operation('b', .2, DateTime(2027, 1, 5)),
          operation('future', 999, DateTime(2027, 1, 6)),
          operation('december', 42, DateTime(2026, 12, 5)),
        ],
      );
      expect(data.current.expense, .3);
      expect(data.previous.expense, 42);
      expect(data.values(MonthlySeries.expense).last, .3);
    },
  );
  test(
    'Empty, transfer-only and future months do not invent a financial projection',
    () {
      final empty = MonthlyAnalytics.build(
        month: DateTime(2026, 11),
        now: DateTime(2026, 11, 1),
        transactions: [],
      );
      expect(empty.projectedAvailable, isNull);
      expect(empty.hasActivity, false);
      final transfer = MonthlyAnalytics.build(
        month: DateTime(2026, 11),
        now: DateTime(2026, 11, 5),
        transactions: [
          operation('t', 500, DateTime(2026, 11, 1), type: 'transfer'),
        ],
      );
      expect(transfer.hasActivity, true);
      expect(transfer.current.available, 0);
      expect(transfer.projectedAvailable, isNull);
      final future = MonthlyAnalytics.build(
        month: DateTime(2027, 1),
        now: DateTime(2026, 11, 1),
        transactions: [],
      );
      expect(future.isFuture, true);
      expect(future.values(MonthlySeries.remaining), isEmpty);
    },
  );
  for (final theme in AppThemes.themes.entries) {
    for (final width in [320.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${theme.key}: three monthly sections fit $width / $scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 1000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final data = fixture();
            await tester.pumpWidget(
              MaterialApp(
                theme: theme.value,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          MonthlyOverview(
                            data: data,
                            currency: '€',
                            hidden: false,
                          ),
                          MonthlyProjection(
                            data: data,
                            currency: '€',
                            hidden: false,
                          ),
                          MonthlyAnalysisChart(
                            data: comparisonFixture(),
                            currency: '€',
                            hidden: false,
                            onSameDay: (_) {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(Slider), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'Five series switch between daily amounts and running totals for two months',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyAnalysisChart(
                data: comparisonFixture(),
                currency: '€',
                hidden: false,
                onSameDay: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final series in MonthlySeries.values) {
        final control = find.byKey(ValueKey('analysis-${series.name}'));
        await tester.ensureVisible(control);
        await tester.tap(control);
        await tester.pumpAndSettle();
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.data.lineBarsData.last.spots.length, 15);
        expect(chart.data.lineBarsData.first.dashArray, isNotEmpty);
      }
      final total = tester.widget<LineChart>(find.byType(LineChart));
      expect(total.data.lineBarsData.last.spots.last.y, 400);
      await tester.ensureVisible(find.byKey(const ValueKey('analysis-daily')));
      await tester.tap(find.byKey(const ValueKey('analysis-daily')));
      await tester.pumpAndSettle();
      final average = tester.widget<LineChart>(find.byType(LineChart));
      expect(average.data.lineBarsData.last.spots[3].y, 400);
      await tester.ensureVisible(
        find.byKey(const ValueKey('analysis-remaining')),
      );
      await tester.tap(find.byKey(const ValueKey('analysis-remaining')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LineChart>(find.byType(LineChart)).data.minY,
        lessThan(0),
      );
      expect(find.byType(Slider), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Comparison filters align symmetrically and retain callbacks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthlyAnalysisChart(
              data: comparisonFixture(),
              currency: '€',
              hidden: false,
              onSameDay: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final keys = [
      'comparison-full-month',
      'comparison-same-day',
      'analysis-cumulative',
      'analysis-daily',
    ];
    final boxes = [
      for (final key in keys) tester.getRect(find.byKey(ValueKey(key))),
    ];
    for (final box in boxes) {
      expect(box.width, closeTo(boxes.first.width, .01));
      expect(box.top, closeTo(boxes.first.top, .01));
    }
    expect((boxes.first.left + boxes.last.right) / 2, closeTo(720, 1));
    await tester.tap(find.byKey(const ValueKey('comparison-full-month')));
    expect(selected, false);
    await tester.tap(find.byKey(const ValueKey('comparison-same-day')));
    expect(selected, true);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Hover and touch select days directly; the fixed readout stays outside the plot',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyAnalysisChart(
                data: comparisonFixture(),
                currency: '€',
                hidden: false,
                onSameDay: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final plot = find.byKey(const ValueKey('monthly-analysis-plot'));
      await tester.ensureVisible(plot);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(plot);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: Offset(bounds.left + 48, bounds.top + 50),
      );
      await mouse.moveTo(Offset(bounds.left + 48, bounds.top + 55));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('monthly-analysis-selected-day')),
            )
            .data,
        contains('Jour 1'),
      );
      await mouse.removePointer();
      await tester.tapAt(Offset(bounds.right - 18, bounds.top + 50));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('monthly-analysis-selected-day')),
            )
            .data,
        contains('Jour 15'),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('monthly-analysis-detail')))
            .dy,
        greaterThan(tester.getBottomLeft(plot).dy),
      );
      Focus.of(tester.element(find.byType(LineChart))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('monthly-analysis-selected-day')),
            )
            .data,
        contains('Jour 14'),
      );
      expect(find.byType(Slider), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Touch and mouse wheel still scroll the page across the chart', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              MonthlyAnalysisChart(
                data: comparisonFixture(),
                currency: '€',
                hidden: false,
                onSameDay: (_) {},
              ),
              const SizedBox(height: 1500),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(LineChart));
    await tester.pumpAndSettle();
    var before = scroll.offset;
    await tester.drag(find.byType(LineChart), const Offset(0, -130));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(before));
    await tester.ensureVisible(find.byType(LineChart));
    await tester.pumpAndSettle();
    before = scroll.offset;
    final position = tester.getCenter(find.byType(LineChart));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: position);
    await tester.sendEventToBinding(
      PointerScrollEvent(position: position, scrollDelta: const Offset(0, 130)),
    );
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(before));
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Discreet mode hides lines, values and transaction counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthlyAnalysisChart(
              data: comparisonFixture(),
              currency: '€',
              hidden: true,
              onSameDay: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyChartMask), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.byKey(const ValueKey('monthly-analysis-detail')), findsNothing);
    expect(find.textContaining('2,000'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Future months show unavailable summaries and no fabricated comparison delta',
    (tester) async {
      final future = MonthlyAnalytics.build(
        month: DateTime(2027, 1),
        now: DateTime(2026, 11, 15),
        transactions: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MonthlyOverview(data: future, currency: '€', hidden: false),
                  MonthlyProjection(data: future, currency: '€', hidden: false),
                  MonthlyAnalysisChart(
                    data: MonthComparison(future, fixture()),
                    currency: '€',
                    hidden: false,
                    onSameDay: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('—'), findsWidgets);
      expect(find.text('Écart : —'), findsNWidgets(6));
      expect(
        find.text('Une des périodes n’a pas encore commencé.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Month choice is its own accessible button in the lazy header', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var choices = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LazySectionList(
            gaps: const [16],
            sections: [
              (_) => MonthPageHeader(
                title: 'Stats mensuelles',
                subtitle: 'Votre mois',
                eyebrow: 'ANALYSE',
                monthLabel: 'novembre 2026',
                compactMonthLabel: 'nov. 2026',
                previousLabel: 'Mois précédent',
                nextLabel: 'Mois suivant',
                onPrevious: () {},
                onNext: () {},
                onChoose: () => choices++,
              ),
              (_) => const Text('Résumé'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('novembre 2026'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('month-selector-choose')));
    await tester.pumpAndSettle();
    expect(choices, 1);
    semantics.dispose();
  });
}
