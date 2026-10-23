import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/month_page_header.dart';
import 'package:mysold/widgets/graphiques/chart_info_region.dart';
import 'package:mysold/widgets/graphiques/viewport_bar_chart.dart';

BarChartData sampleData({
  BarChartAlignment alignment = BarChartAlignment.spaceEvenly,
}) => BarChartData(
  alignment: alignment,
  minY: -40,
  maxY: 160,
  titlesData: FlTitlesData(show: false),
  borderData: FlBorderData(show: false),
  barGroups: List.generate(
    12,
    (group) => BarChartGroupData(
      x: group,
      barsSpace: 5,
      barRods: [
        BarChartRodData(toY: 100 + group.toDouble(), width: 16),
        BarChartRodData(toY: -20, width: 16),
      ],
    ),
  ),
);

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Month title stays left of the month on one row at $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var previous = 0, next = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppThemes.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MonthPageHeader(
                    title: 'Budget mensuel',
                    subtitle: 'Vos opérations, simplement.',
                    eyebrow: 'Votre budget',
                    monthLabel: 'septembre 2026',
                    compactMonthLabel: 'sept. 2026',
                    previousLabel: 'Mois précédent',
                    nextLabel: 'Mois suivant',
                    onPrevious: () => previous++,
                    onNext: () => next++,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final title = tester.getRect(
            find.byKey(const ValueKey('month-page-title')),
          );
          final selector = tester.getRect(
            find.byKey(const ValueKey('month-selector')),
          );
          expect(title.left, 16);
          expect(title.right, lessThan(selector.left));
          expect(title.center.dy, closeTo(selector.center.dy, 0.5));
          expect(selector.right, closeTo(width - 16, 0.5));
          await tester.tap(find.byTooltip('Mois précédent'));
          await tester.tap(find.byTooltip('Mois suivant'));
          expect(previous, 1);
          expect(next, 1);
        },
      );
    }
  }

  for (final theme in AppThemes.themes.entries) {
    testWidgets(
      '${theme.key}: tooltip remains inside the viewport at both scroll edges during a finger slide',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.value,
            home: Scaffold(
              body: ListView(
                children: [
                  const Text('Graphique avec axe fixe'),
                  SizedBox(
                    height: 250,
                    child: Row(
                      children: [
                        const SizedBox(width: 50, child: Text('Axe Y')),
                        Expanded(
                          child: ViewportBarChart(
                            controller: controller,
                            contentWidth: 900,
                            data: sampleData(),
                            info: (group, rod) => ChartInfo(
                              'Mois ${group + 1}',
                              'Série $rod : 123 456,78 €',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 600),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final region = tester.getRect(find.byType(ChartInfoRegion));
        final finger = await tester.startGesture(
          Offset(region.right - 5, region.center.dy),
        );
        await tester.pump();
        Rect tooltip() =>
            tester.getRect(find.byKey(const ValueKey('chart-info-card')));
        void expectInside() {
          expect(tooltip().left, greaterThanOrEqualTo(region.left));
          expect(tooltip().right, lessThanOrEqualTo(region.right));
          expect(tooltip().top, greaterThanOrEqualTo(region.top));
          expect(tooltip().bottom, lessThanOrEqualTo(region.bottom));
        }

        expectInside();
        await finger.moveTo(Offset(region.center.dx, region.center.dy));
        await tester.pump();
        await finger.moveTo(Offset(region.left + 8, region.center.dy));
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0));
        expectInside();
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expectInside();
        await finger.moveTo(Offset(region.right - 5, region.center.dy));
        await tester.pumpAndSettle();
        expectInside();
        await finger.up();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('chart-info-card')), findsNothing);
        // Vertical page scrolling is still possible over the chart.
        await tester.drag(find.byType(ChartInfoRegion), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(ChartInfoRegion)).top,
          lessThan(region.top),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Long labels, enlarged text and mouse hover stay inside a small chart',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  height: 190,
                  child: ChartInfoRegion(
                    resolve: (_, __) => const ChartInfo(
                      'Catégorie avec un nom très long pour la répartition mensuelle',
                      'Investissements : 123 456,78 €',
                    ),
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(ChartInfoRegion));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: rect.bottomRight - const Offset(2, 2));
      await mouse.moveTo(rect.bottomRight - const Offset(3, 3));
      await tester.pumpAndSettle();
      final tooltip = tester.getRect(
        find.byKey(const ValueKey('chart-info-card')),
      );
      expect(rect.contains(tooltip.topLeft), isTrue);
      expect(rect.contains(tooltip.bottomRight), isTrue);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
    },
  );

  test(
    'Nearest bar uses chart spacing, rejects axes and handles negative rods',
    () {
      final data = BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 30),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [BarChartRodData(toY: -20, width: 20)],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [BarChartRodData(toY: 30, width: 20)],
          ),
        ],
      );
      expect(
        barSelectionAt(
          data,
          const Size(240, 200),
          const Offset(90, 100),
        )!.group,
        0,
      );
      expect(
        barSelectionAt(
          data,
          const Size(240, 200),
          const Offset(190, 100),
        )!.group,
        1,
      );
      expect(
        barSelectionAt(data, const Size(240, 200), const Offset(20, 100)),
        isNull,
      );
      expect(
        barSelectionAt(data, const Size(240, 200), const Offset(90, 190)),
        isNull,
      );
    },
  );
}
