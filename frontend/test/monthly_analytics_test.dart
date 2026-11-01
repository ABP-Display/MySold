import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/analytics/monthly_analytics_sections.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';
import 'package:mysold/widgets/month_page_header.dart';
import 'package:mysold/widgets/lazy_section_list.dart';

MonthlyOperation operation(
  String id,
  double amount,
  DateTime date, {
  String type = 'expense',
  String? category = 'food',
  String? label,
}) => MonthlyOperation(
  id: id,
  type: type,
  amount: amount,
  date: date,
  categoryId: category,
  description: label ?? id,
);

MonthlyAnalytics fixture() => MonthlyAnalytics.build(
  month: DateTime(2026, 11),
  now: DateTime(2026, 11, 15),
  categoryNames: {'food': 'Alimentation et achats pour la maison'},
  transactions: [
    operation('Salaire reçu', 2000, DateTime(2026, 11, 1), type: 'income'),
    operation('Courses importantes', 150, DateTime(2026, 11, 2)),
    operation('Courses récentes', 50, DateTime(2026, 11, 14)),
    operation('Investissement', 300, DateTime(2026, 11, 3), type: 'investment'),
    operation('Ancien mois', 180, DateTime(2026, 10, 2)),
    operation('Salaire précédent', 1800, DateTime(2026, 10, 1), type: 'income'),
  ],
);

void main() {
  testWidgets(
    'Month choice is a separate accessible button inside a lazy stats header',
    (tester) async {
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
                  subtitle: 'Votre mois, comparé et expliqué.',
                  eyebrow: 'ANALYSE',
                  monthLabel: 'novembre 2026',
                  compactMonthLabel: 'nov. 2026',
                  previousLabel: 'Mois précédent',
                  nextLabel: 'Mois suivant',
                  onPrevious: () {},
                  onNext: () {},
                  onChoose: () => choices++,
                ),
                (_) => const Text('Résumé du mois'),
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
    },
  );
  testWidgets('The spending chart permits mouse-wheel page scrolling', (
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
              MonthlySpendingChart(
                data: fixture(),
                currency: '€',
                hidden: false,
              ),
              const SizedBox(height: 1500),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final position = tester.getCenter(find.byType(LineChart));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: position);
    await tester.sendEventToBinding(
      PointerScrollEvent(position: position, scrollDelta: const Offset(0, 180)),
    );
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  testWidgets('The spending chart permits vertical page scrolling on touch', (
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
              MonthlySpendingChart(
                data: fixture(),
                currency: '€',
                hidden: false,
              ),
              const SizedBox(height: 1500),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(LineChart), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
  test(
    'Equal dates exclude future operations and transfers; full comparison includes later M-1 days',
    () {
      final rows = [
        operation('today', .1, DateTime(2026, 11, 5, 23)),
        operation('second', .2, DateTime(2026, 11, 5)),
        operation('future', 999, DateTime(2026, 11, 6)),
        operation('transfer', 100, DateTime(2026, 11, 2), type: 'transfer'),
        operation('early', 10, DateTime(2026, 10, 5)),
        operation('late', 30, DateTime(2026, 10, 20)),
      ];
      final equal = MonthlyAnalytics.build(
        month: DateTime(2026, 11),
        now: DateTime(2026, 11, 5),
        transactions: rows,
      );
      expect(equal.current.expense, .3);
      expect(equal.previous.expense, 10);
      expect(equal.previousDays, 5);
      expect(equal.cumulativeExpense.last, .3);
      expect(equal.daysWithoutExpense, 4);
      final full = MonthlyAnalytics.build(
        month: DateTime(2026, 11),
        now: DateTime(2026, 11, 5),
        transactions: rows,
        sameDayComparison: false,
      );
      expect(full.previous.expense, 40);
      expect(full.current.expense, .3);
    },
  );
  test(
    'January includes December M-1; leap months and shorter previous months are capped',
    () {
      final january = MonthlyAnalytics.build(
        month: DateTime(2027, 1),
        now: DateTime(2027, 1, 15),
        transactions: [operation('december', 42, DateTime(2026, 12, 14))],
      );
      expect(january.previous.expense, 42);
      final march = MonthlyAnalytics.build(
        month: DateTime(2024, 3),
        now: DateTime(2024, 3, 31),
        transactions: [],
      );
      expect(march.previousDays, 29);
      final february = MonthlyAnalytics.build(
        month: DateTime(2024, 2),
        now: DateTime(2024, 2, 29),
        transactions: [],
      );
      expect(february.daysInMonth, 29);
    },
  );
  test(
    'Projection keeps received income and investments; completed months use their real result',
    () {
      final data = fixture();
      expect(data.current.available, 1500);
      expect(data.projectedAvailable, 1300);
      expect(data.averagePurchase, 100);
      expect(data.daysWithoutExpense, 13);
      expect(data.expenseCount, 2);
      expect(data.categories.single.amount, 200);
      final past = MonthlyAnalytics.build(
        month: DateTime(2026, 11),
        now: DateTime(2026, 12),
        transactions: data.operations,
      );
      expect(past.projectedAvailable, 1500);
      expect(past.previousDays, 31);
      expect(past.sameDayComparison, false);
      final empty = MonthlyAnalytics.build(
        month: DateTime(2026, 11),
        now: DateTime(2026, 11, 1),
        transactions: [],
      );
      expect(empty.projectedAvailable, isNull);
      final future = MonthlyAnalytics.build(
        month: DateTime(2027, 1),
        now: DateTime(2026, 11, 1),
        transactions: data.operations,
      );
      expect(future.elapsedDays, 0);
      expect(future.operations, isEmpty);
      expect(future.projectedAvailable, isNull);
    },
  );
  test(
    'Operation ranking switches between amount and date and excludes other types',
    () {
      final data = fixture();
      expect(
        data.ranked('expense', MonthlyOperationOrder.amount).first.id,
        'Courses importantes',
      );
      expect(
        data.ranked('expense', MonthlyOperationOrder.latest).first.id,
        'Courses récentes',
      );
      expect(
        data.ranked('income', MonthlyOperationOrder.amount).single.id,
        'Salaire reçu',
      );
    },
  );

  for (final theme in AppThemes.themes.entries) {
    for (final width in [320.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${theme.key}: monthly analysis fits $width / $scale', (
          tester,
        ) async {
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
                        MonthlyComparison(
                          data: data,
                          currency: '€',
                          hidden: false,
                          onSameDay: (_) {},
                        ),
                        MonthlyProjection(
                          data: data,
                          currency: '€',
                          hidden: false,
                        ),
                        MonthlySpendingChart(
                          data: data,
                          currency: '€',
                          hidden: false,
                        ),
                        MonthlyCategoryBreakdown(
                          data: data,
                          currency: '€',
                          hidden: false,
                        ),
                        MonthlyHabits(data: data, currency: '€', hidden: false),
                        MonthlyOperationRanking(
                          data: data,
                          currency: '€',
                          hidden: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('Discreet mode masks the chart, amounts and financial counts', (
    tester,
  ) async {
    final data = fixture();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                MonthlySpendingChart(data: data, currency: '€', hidden: true),
                MonthlyHabits(data: data, currency: '€', hidden: true),
                MonthlyCategoryBreakdown(
                  data: data,
                  currency: '€',
                  hidden: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyChartMask), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.textContaining('200,00'), findsNothing);
    expect(find.text('13 / 15'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Daily graph supports pointer selection with the info outside the plot',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlySpendingChart(
                data: fixture(),
                currency: '€',
                hidden: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final slider = find.byKey(const ValueKey('monthly-chart-day'));
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(slider).value, isNot(15));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Ranking selectors change the displayed type and sort order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthlyOperationRanking(
              data: fixture(),
              currency: '€',
              hidden: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('monthly-operation-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revenus').last);
    await tester.pumpAndSettle();
    expect(find.text('Salaire reçu'), findsOneWidget);
    expect(find.text('Courses importantes'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
