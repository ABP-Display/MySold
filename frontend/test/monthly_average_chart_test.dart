import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/models/month_comparison.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/analytics/monthly_analysis_chart.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';

MonthlyAnalytics source(int month, double amount) => MonthlyAnalytics.build(
  month: DateTime(2026, month),
  now: DateTime(2026, 3, 15),
  transactions: [
    MonthlyOperation(
      id: '$month',
      type: 'expense',
      amount: amount,
      date: DateTime(2026, month, 2),
    ),
  ],
);
final selected = source(3, 120);
final reference = source(2, 200);
final mean = MonthComparison.yearToDate(selected, [source(1, 100), reference]);

void main() {
  testWidgets(
    'Compact comparator keeps previous month, date picker and average one menu away',
    (tester) async {
      var choices = 0, resets = 0;
      final modes = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyAnalysisChart(
                data: MonthComparison(selected, reference),
                currency: '€',
                hidden: false,
                onAverageChanged: modes.add,
                onChooseReference: () => choices++,
                onResetReference: () => resets++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in [
        'comparison-reference-month',
        'comparison-reference-previous',
        'comparison-reference-average',
      ]) {
        await tester.tap(
          find.byKey(const ValueKey('comparison-reference-menu')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
      }
      expect(choices, 1);
      expect(resets, 1);
      expect(modes, [false, false, true]);
      expect(find.byKey(const ValueKey('comparison-summary')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Comparison mode changes reference without changing selected amounts or chart controls',
    (tester) async {
      var average = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => MonthlyAnalysisChart(
                  data: average ? mean : MonthComparison(selected, reference),
                  currency: '€',
                  hidden: false,
                  onAverageChanged: (value) => setState(() => average = value),
                  onChooseReference: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Comparaison'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('comparison-reference-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('comparison-reference-average')),
      );
      await tester.pumpAndSettle();
      expect(average, isTrue);
      expect(
        find.byKey(const ValueKey('comparison-month-reference')),
        findsNothing,
      );
      expect(find.textContaining('Moyenne sur 2 mois'), findsOneWidget);
      var chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.length, 2);
      expect(chart.data.lineBarsData.first.spots.last.y, 150);
      expect(chart.data.lineBarsData.last.spots.last.y, 120);
      await tester.ensureVisible(find.byKey(const ValueKey('analysis-daily')));
      await tester.tap(find.byKey(const ValueKey('analysis-daily')));
      await tester.pumpAndSettle();
      chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.spots[1].y, 150);
      expect(chart.data.lineBarsData.first.spots[2].y, 0);
      await tester.ensureVisible(
        find.byKey(const ValueKey('comparison-reference-menu')),
      );
      await tester.tap(find.byKey(const ValueKey('comparison-reference-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('comparison-reference-month')),
      );
      await tester.pumpAndSettle();
      expect(average, isFalse);
      expect(
        find.byKey(const ValueKey('comparison-reference-menu')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Loading or failed references do not draw fake zero-value comparisons',
    (tester) async {
      for (final failed in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MonthlyAnalysisChart(
                  data: MonthComparison(selected, reference),
                  currency: '€',
                  hidden: false,
                  referenceLoading: !failed,
                  referenceFailed: failed,
                  onRetryReference: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester
              .widget<LineChart>(find.byType(LineChart))
              .data
              .lineBarsData
              .length,
          1,
        );
        if (failed)
          expect(
            find.text('Impossible de charger la comparaison.'),
            findsOneWidget,
          );
        else
          expect(
            find.byKey(const ValueKey('comparison-loading')),
            findsOneWidget,
          );
      }
    },
  );

  testWidgets(
    'January explains missing history and privacy hides both curves',
    (tester) async {
      final january = MonthComparison.yearToDate(source(1, 100), []);
      for (final hidden in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MonthlyAnalysisChart(
                  data: january,
                  currency: '€',
                  hidden: hidden,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Aucun mois terminé à comparer dans cette année.'),
          findsOneWidget,
        );
        if (hidden) {
          expect(find.byType(LineChart), findsNothing);
          expect(find.byType(PrivacyChartMask), findsOneWidget);
        } else
          expect(
            tester
                .widget<LineChart>(find.byType(LineChart))
                .data
                .lineBarsData
                .length,
            1,
          );
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final theme in [AppThemes.dark, AppThemes.light]) {
    for (final width in [320.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Average chart fits ${theme.brightness} $width/$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MonthlyAnalysisChart(
                    data: mean,
                    currency: '€',
                    hidden: false,
                    onAverageChanged: (_) {},
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
}
