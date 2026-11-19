import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/month_chart_series.dart';
import 'package:mysold/models/month_operation_charts.dart';
import 'package:mysold/widgets/graphiques/investment_sections_chart.dart';
import 'package:mysold/widgets/graphiques/month_breakdown_chart.dart';
import 'package:mysold/widgets/graphiques/month_money_axis.dart';
import 'package:mysold/widgets/graphiques/chart_info_region.dart';

const slices = [
  MonthPieSlice('salary', 'Salaire', 75000, Colors.green),
  MonthPieSlice('other', 'Autres', 25000, Colors.blue),
];
String money(int cents) => '${(cents / 100).toStringAsFixed(2)} €';

void main() {
  test(
    'Money axis uses the exact maximum, including cents and small amounts',
    () {
      for (final maximum in [1, 29, 12345, 119000, 99999999]) {
        final axis = MonthMoneyAxis([maximum, 0, maximum ~/ 2]);
        expect(axis.maximumCents, maximum);
        expect(axis.maximum, maximum / 100);
        expect(axis.interval, greaterThan(0));
        expect(axis.interval.isFinite, isTrue);
      }
      expect(MonthMoneyAxis([]).maximum, .01);
      expect(MonthMoneyAxis([0, 0]).maximum, .01);
    },
  );

  Future<void> mount(
    WidgetTester tester,
    Widget chart, {
    double width = 390,
    double scale = 1,
    bool reduced = false,
    bool dark = true,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: width - 58,
                    height: 172.5 * scale + 28,
                    child: chart,
                  ),
                  const SizedBox(height: 1500),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  PieChart pie(WidgetTester tester) =>
      tester.widget<PieChart>(find.byType(PieChart));

  testWidgets(
    'Tapping a slice grows it, shows its amount and toggles it back',
    (tester) async {
      addTearDown(tester.view.reset);
      await mount(tester, MonthBreakdownChart(slices: slices, money: money));
      final initial = pie(tester).data.sections.first.radius;
      final rect = tester.getRect(find.byType(PieChart));
      await tester.tapAt(rect.center + Offset(rect.width * .37, 0));
      await tester.pump();
      expect(pie(tester).data.sections.first.radius, greaterThan(initial));
      expect(pie(tester).data.sections.last.radius, initial);
      expect(pie(tester).duration, const Duration(milliseconds: 180));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('month-pie-center-amount')))
            .data,
        '750.00 €',
      );
      await tester.pumpAndSettle();
      await tester.tapAt(rect.center + Offset(rect.width * .37, 0));
      await tester.pumpAndSettle();
      expect(pie(tester).data.sections.first.radius, initial);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('month-pie-center-amount')))
            .data,
        '1000.00 €',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Selection respects reduced motion and keyboard activation', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(
      tester,
      MonthBreakdownChart(slices: slices, money: money),
      reduced: true,
    );
    await tester.tap(find.text('Salaire'));
    await tester.pumpAndSettle();
    expect(pie(tester).duration, Duration.zero);
    expect(
      pie(tester).data.sections.first.radius,
      greaterThan(pie(tester).data.sections.last.radius),
    );
    await mount(tester, MonthBreakdownChart(slices: slices, money: money));
    final detector = find.byType(FocusableActionDetector).last;
    Focus.of(
      tester.element(
        find.descendant(of: detector, matching: find.byType(Listener)).first,
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(pie(tester).duration, Duration.zero);
    expect(
      pie(tester).data.sections.last.radius,
      greaterThan(pie(tester).data.sections.first.radius),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Investment bars and stacks show euros rather than percentages', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final sections = investmentSections(
      DateTime(2026, 11),
      [
        MonthChartEntry(DateTime(2026, 11, 1), 120.1, 'stock'),
        MonthChartEntry(DateTime(2026, 11, 4), 80.2, 'etf'),
        MonthChartEntry(DateTime(2026, 11, 10), 50, 'etf'),
        MonthChartEntry(DateTime(2026, 11, 30), 75, 'stock'),
      ],
      {'stock': 'stock', 'etf': 'etf'},
    );
    await mount(
      tester,
      InvestmentSectionsChart(
        sections: sections,
        money: money,
        detailBuilder: (_, i) => MonthBreakdownChart(
          slices: [
            MonthPieSlice('s', 'Actions', sections[i].total, Colors.green),
          ],
          money: money,
        ),
      ),
    );
    final data = tester.widget<BarChart>(find.byType(BarChart)).data;
    expect(data.maxY, 200.3);
    expect(data.barGroups.map((g) => g.barRods.single.toY), [200.3, 50, 0, 75]);
    final stacks = data.barGroups.first.barRods.single.rodStackItems;
    expect(stacks.map((s) => (s.fromY, s.toY)), [(0.0, 120.1), (120.1, 200.3)]);
    expect(find.text('200.30 €'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    await tester.tapAt(
      tester.getTopLeft(find.byType(BarChart)) + const Offset(90, 60),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retour aux sections'), findsOneWidget);
    expect(find.byType(MonthBreakdownChart), findsOneWidget);
    await tester.tap(find.byTooltip('Retour aux sections'));
    await tester.pumpAndSettle();
    expect(find.byType(BarChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Vertical gestures on pie slices still scroll the page', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(tester, MonthBreakdownChart(slices: slices, money: money));
    final pieFinder = find.byType(PieChart);
    final rect = tester.getRect(pieFinder);
    await tester.dragFrom(
      rect.center + Offset(rect.width * .37, 0),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(pieFinder).dy, lessThan(rect.top - 40));
    expect(
      pie(tester).data.sections.first.radius,
      pie(tester).data.sections.last.radius,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hovering the chart grows its slice and preserves its tooltip', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(tester, MonthBreakdownChart(slices: slices, money: money));
    final rect = tester.getRect(find.byType(PieChart));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump();
    await mouse.moveTo(rect.center + Offset(rect.width * .37, 0));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .any(
            (t) =>
                (t.message ?? '').contains('750.00 €') &&
                (t.message ?? '').contains('%'),
          ),
      isTrue,
    );
    expect(
      pie(tester).data.sections.first.radius,
      greaterThan(pie(tester).data.sections.last.radius),
    );
    expect(pie(tester).duration, const Duration(milliseconds: 180));
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Legend hover previews its slice without an annotation', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(tester, MonthBreakdownChart(slices: slices, money: money));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.text('Autres')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      pie(tester).data.sections.last.radius,
      greaterThan(pie(tester).data.sections.first.radius),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('month-pie-center-amount')))
          .data,
      '250.00 €',
    );
    expect(
      tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .where((t) => (t.message ?? '').isNotEmpty),
      isEmpty,
    );
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(
      pie(tester).data.sections.last.radius,
      pie(tester).data.sections.first.radius,
    );
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Touching a legend previews immediately but vertical dragging scrolls',
    (tester) async {
      addTearDown(tester.view.reset);
      await mount(tester, MonthBreakdownChart(slices: slices, money: money));
      final rect = tester.getRect(find.byType(PieChart));
      final finger = await tester.startGesture(
        tester.getCenter(find.text('Autres')),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        pie(tester).data.sections.last.radius,
        greaterThan(pie(tester).data.sections.first.radius),
      );
      await finger.moveBy(const Offset(0, -24));
      await tester.pump();
      await finger.moveBy(const Offset(0, -76));
      await tester.pump();
      await finger.up();
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(PieChart)).dy,
        lessThan(rect.top - 30),
      );
      expect(
        pie(tester).data.sections.last.radius,
        pie(tester).data.sections.first.radius,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Compact chart tooltip stays near the bar and inside all edges', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final scale in [1.0, 2.0]) {
      await mount(
        tester,
        ChartInfoRegion(
          compact: true,
          resolve: (position, _) =>
              ChartInfo('Dépenses de logement', '1050.01 €', anchor: position),
          child: const ColoredBox(color: Colors.green),
        ),
        width: 320,
        scale: scale,
      );
      final area = tester.getRect(find.byType(ChartInfoRegion));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await tester.pump();
      for (final point in [
        area.topLeft + const Offset(3, 3),
        area.topRight + const Offset(-3, 3),
        area.bottomLeft + const Offset(3, -3),
        area.bottomRight - const Offset(3, 3),
      ]) {
        await mouse.moveTo(point);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('chart-info-tooltip')),
          findsOneWidget,
          reason: '$scale / $point / $area',
        );
        final tooltip = tester.getRect(
          find.byKey(const ValueKey('chart-info-tooltip')),
        );
        expect(area.contains(tooltip.topLeft), isTrue);
        expect(area.contains(tooltip.bottomRight), isTrue);
        expect(tooltip.width, lessThanOrEqualTo(240));
        expect(find.byKey(const ValueKey('chart-info-card')), findsNothing);
      }
      await mouse.removePointer();
      await tester.pumpAndSettle();
      await tester.tapAt(area.center);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chart-info-tooltip')), findsOneWidget);
      await tester.dragFrom(area.center, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(ChartInfoRegion)).dy,
        lessThan(area.top - 30),
      );
      expect(find.byKey(const ValueKey('chart-info-tooltip')), findsNothing);
      expect(tester.takeException(), isNull);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'New financial data clears selection without animating the values',
    (tester) async {
      addTearDown(tester.view.reset);
      await mount(tester, MonthBreakdownChart(slices: slices, money: money));
      await tester.tap(find.text('Salaire'));
      await tester.pumpAndSettle();
      await mount(
        tester,
        MonthBreakdownChart(
          slices: [
            const MonthPieSlice('salary', 'Salaire', 50000, Colors.green),
            slices.last,
          ],
          money: money,
        ),
      );
      expect(pie(tester).duration, Duration.zero);
      expect(
        pie(tester).data.sections.first.radius,
        pie(tester).data.sections.last.radius,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('month-pie-center-amount')))
            .data,
        '750.00 €',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Compact layout survives six long labels, both themes and large text',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final width in [320.0, 390.0, 1440.0]) {
        for (final scale in [1.0, 2.0]) {
          for (final dark in [true, false]) {
            await mount(
              tester,
              MonthBreakdownChart(
                slices: [
                  for (var i = 0; i < 6; i++)
                    MonthPieSlice(
                      '$i',
                      'Revenu avec un intitulé extrêmement long $i',
                      (math.pow(10, i + 1) * 100).round(),
                      Colors.green,
                    ),
                ],
                money: money,
              ),
              width: width,
              scale: scale,
              dark: dark,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '$width/$scale/$dark',
            );
          }
        }
      }
    },
  );
}
