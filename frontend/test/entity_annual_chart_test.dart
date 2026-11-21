import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/graphiques/entity_annual_chart.dart';
import 'package:mysold/widgets/web_scroll_scope.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  testWidgets(
    'January opening is a fixed dashed baseline, not a second month',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntityAnnualChart(
              year: 2026,
              opening: 1000,
              values: const [1010, 980, 1040, null],
              currency: 'EUR',
              hidden: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(chart.minX, 0);
      expect(chart.lineBarsData.length, 2);
      expect(chart.lineBarsData.first.dashArray, isNotEmpty);
      expect(
        chart.lineBarsData.first.spots.map((s) => s.y),
        everyElement(1000),
      );
      expect(chart.lineBarsData.last.spots.first.x, 0);
      expect(chart.lineBarsData.last.spots.first.y, 1000);
      expect(chart.lineBarsData.last.spots.last.x, 3);
      expect(chart.maxY, greaterThan(1040));
      expect(chart.minY, lessThan(980));
      expect(find.byKey(const ValueKey('entity-chart-delta')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Missing historical months remain gaps instead of invented movements',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntityAnnualChart(
              year: 2026,
              opening: 1000,
              values: const [null, null, 1200],
              currency: 'EUR',
              hidden: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final spots = tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineBarsData
          .last
          .spots;
      expect(spots.length, 4);
      expect(spots[1].x.isNaN, isTrue);
      expect(spots[2].x.isNaN, isTrue);
      expect(spots.last.y, 1200);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Zero opening categories and negative account balances never divide by zero',
    (tester) async {
      for (final opening in [0.0, -100.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EntityAnnualChart(
                year: 2026,
                opening: opening,
                zeroBased: opening == 0,
                values: const [10, 25, 50],
                currency: 'EUR',
                hidden: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('entity-chart-delta')))
              .data,
          isNot(contains('%')),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Annual chart $width / $scale selects horizontally and scrolls vertically',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('fr'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: WebScrollScope(child: child!),
              ),
              home: Scaffold(
                body: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(20),
                  children: [
                    EntityAnnualChart(
                      year: 2026,
                      currency: 'EUR',
                      hidden: false,
                      opening: 1000,
                      values: [
                        for (var i = 0; i < 12; i++)
                          i < 9 ? 1000 + i * 10.37 : null,
                      ],
                    ),
                    const SizedBox(height: 1200),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final plot = tester.getRect(
            find.byKey(const ValueKey('entity-annual-plot')),
          );
          final label = find.byKey(const ValueKey('entity-chart-month'));
          final before = tester.widget<Text>(label).data;
          await tester.dragFrom(
            Offset(plot.left + 60, plot.center.dy),
            Offset((plot.width - 90) * .35, 2),
          );
          await tester.pumpAndSettle();
          expect(tester.widget<Text>(label).data, isNot(before));
          expect(
            tester
                .getRect(find.byKey(const ValueKey('entity-annual-plot')))
                .top,
            plot.top,
          );
          expect(scroll.offset, 0);
          await tester.dragFrom(plot.center, const Offset(2, -180));
          await tester.pumpAndSettle();
          expect(scroll.offset, greaterThan(50));
          expect(tester.takeException(), isNull);
          expect(
            find.text('janvier'),
            findsNothing,
          ); // No monthly table under the plot.
        },
      );
    }
  }
  testWidgets(
    'Privacy removes chart values and a single known month remains readable',
    (tester) async {
      for (final hidden in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EntityAnnualChart(
                year: 2026,
                values: const [1234.56, null],
                opening: 1000,
                currency: 'EUR',
                hidden: hidden,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('entity-chart-value')),
          hidden ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
