import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/graphiques/simulation_chart.dart';
import 'package:mysold/widgets/graphiques/chart_info_region.dart';
import 'package:mysold/widgets/simulation/simulation_workspace.dart';

Future<void> setup(
  WidgetTester tester,
  ThemeData theme,
  double width,
  double scale,
) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const SimulationWorkspace(currency: '€'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Zero values and negative savings keep chart axes and touch information usable',
    (tester) async {
      for (final values in [
        [0.0, 0.0, 0.0],
        [100.0, 0.0, -100.0],
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.dark,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: SimulationLineChart(
                  currency: '€',
                  series: [SimulationSeries('Épargne', values, Colors.green)],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final area = tester.getRect(find.byType(ChartInfoRegion));
        final finger = await tester.startGesture(
          Offset(area.right - 16, area.center.dy),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('chart-info-card')), findsOneWidget);
        expect(find.text('Mois 2'), findsOneWidget);
        final info = tester.getRect(
          find.byKey(const ValueKey('chart-info-card')),
        );
        expect(area.contains(info.topLeft), isTrue);
        expect(area.contains(info.bottomRight), isTrue);
        await finger.up();
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    },
  );
  for (final theme in AppThemes.themes.entries) {
    for (final width in [320.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${theme.key}: three simulation tabs and graphs fit $width/$scale',
          (tester) async {
            await setup(tester, theme.value, width, scale);
            final labels = ['Budget', 'Investissement', 'Prêt'];
            for (var index = 0; index < labels.length; index++) {
              final label = find.descendant(
                of: find.byType(TabBar),
                matching: find.text(labels[index]),
              );
              expect(
                tester.getCenter(label).dx,
                closeTo(width * (index + .5) / 3, .5),
              );
              expect(tester.widget<Text>(label).textAlign, TextAlign.center);
            }
            for (final tab in labels) {
              final tabFinder = find.descendant(
                of: find.byType(TabBar),
                matching: find.text(tab),
              );
              await tester.ensureVisible(tabFinder);
              await tester.tap(tabFinder);
              await tester.pumpAndSettle();
              final pageKey = {
                'Budget': 'simulation-budget',
                'Investissement': 'simulation-investment',
                'Prêt': 'simulation-loan',
              }[tab]!;
              final page = find.byKey(PageStorageKey(pageKey));
              final graph = find.descendant(
                of: page,
                matching: find.byType(
                  tab == 'Prêt' ? SimulationCostChart : SimulationLineChart,
                ),
              );
              final scrollable = find
                  .descendant(of: page, matching: find.byType(Scrollable))
                  .first;
              final plot = find.descendant(
                of: graph,
                matching: find.byType(ChartInfoRegion),
              );
              await tester.scrollUntilVisible(
                plot,
                350,
                scrollable: scrollable,
                maxScrolls: 30,
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(graph, findsOneWidget);
              expect(plot.hitTestable(), findsOneWidget);
            }
          },
        );
      }
    }
  }

  testWidgets(
    'Horizontal gestures keep the current tab; an explicit tab press changes it',
    (tester) async {
      await setup(tester, AppThemes.forest, 390, 1);
      final tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      await tester.drag(find.byType(TabBarView), const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(tabs.index, 0);
      final loanTab = find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Prêt'),
      );
      await tester.ensureVisible(loanTab);
      await tester.tap(loanTab);
      await tester.pumpAndSettle();
      expect(tabs.index, 2);
      await tester.drag(find.byType(TabBarView), const Offset(320, 0));
      await tester.pumpAndSettle();
      expect(tabs.index, 2);
    },
  );

  testWidgets(
    'Loan validates comma decimals, deposit and duration without crashing',
    (tester) async {
      await setup(tester, AppThemes.dark, 1440, 1);
      final loanTab = find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Prêt'),
      );
      await tester.ensureVisible(loanTab);
      await tester.tap(loanTab);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('Taux d’intérêt annuel')),
        '3,5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('Durée du prêt en années')),
        '1,5',
      );
      final calculate = find.descendant(
        of: find.byKey(const PageStorageKey('simulation-loan')),
        matching: find.text('Calculer la simulation'),
      );
      await tester.ensureVisible(calculate);
      await tester.ensureVisible(calculate);
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      expect(find.text('Saisissez un nombre entier.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('Durée du prêt en années')),
        '20',
      );
      await tester.enterText(
        find.byKey(const ValueKey('Apport personnel')),
        '200000',
      );
      await tester.ensureVisible(calculate);
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      expect(
        find.text('L’apport doit être inférieur au montant du projet.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('Apport personnel')),
        '20 000',
      );
      await tester.ensureVisible(calculate);
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      expect(
        find.text('L’apport doit être inférieur au montant du projet.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
