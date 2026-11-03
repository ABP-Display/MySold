import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/app_selection_button.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/graphiques/app_charts.dart';

void main() {
  testWidgets('Mouse hover still shows button help and a tap activates once', (
    tester,
  ) async {
    var clicks = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.dark,
        home: Scaffold(
          body: Center(
            child: IconButton(
              tooltip: 'Action',
              onPressed: () => clicks++,
              icon: const Icon(Icons.tune),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(5, 5));
    await mouse.moveTo(tester.getCenter(find.byType(IconButton)));
    await tester.pumpAndSettle();
    expect(find.text('Action'), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(clicks, 1);
  });
  for (final kind in ['chart', 'tooltip button', 'selection', 'operation']) {
    for (final hold in [Duration.zero, const Duration(milliseconds: 30)]) {
      testWidgets(
        'Scroll starting on $kind after $hold does not activate or lock it',
        (tester) async {
          var clicks = 0;
          final controller = ScrollController();
          addTearDown(controller.dispose);
          final child = switch (kind) {
            'chart' => AppLineChart(
              LineChartData(
                minX: 0,
                maxX: 2,
                minY: 0,
                maxY: 20,
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [FlSpot(0, 5), FlSpot(1, 10), FlSpot(2, 15)],
                  ),
                ],
              ),
            ),
            'tooltip button' => Center(
              child: IconButton(
                tooltip: 'Action',
                onPressed: () => clicks++,
                icon: const Icon(Icons.tune),
              ),
            ),
            'selection' => AppSelectionButton(
              onPressed: () => clicks++,
              selected: false,
              child: const Text('Choisir'),
            ),
            _ => Center(
              child: AppOperationCard(
                title: 'Opération',
                subtitle: 'Compte',
                amount: '42 €',
                icon: Icons.payments,
                color: Colors.green,
                onTap: () => clicks++,
              ),
            ),
          };
          await tester.pumpWidget(
            MaterialApp(
              theme: AppThemes.dark,
              home: Scaffold(
                body: ListView(
                  controller: controller,
                  children: [
                    SizedBox(
                      key: const ValueKey('target'),
                      height: 250,
                      child: child,
                    ),
                    const SizedBox(height: 1500),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final finger = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('target'))),
          );
          await tester.pump(hold);
          for (var i = 0; i < 8; i++) {
            await finger.moveBy(const Offset(1, -12));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await finger.up();
          await tester.pumpAndSettle();
          expect(controller.offset, greaterThan(50));
          expect(clicks, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
