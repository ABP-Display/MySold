import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/graphiques/entity_annual_chart.dart';
import 'package:mysold/widgets/web_scroll_scope.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
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
