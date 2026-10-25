import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/graphiques/annual_flow_chart.dart';
import 'package:mysold/widgets/graphiques/app_charts.dart';

List<AnnualFlowSeries> fixture({bool zero = false}) => [
  for (var series = 0; series < 4; series++)
    AnnualFlowSeries(
      label: ['Revenus', 'Dépenses', 'Investissements', 'Reste'][series],
      color: [Colors.green, Colors.red, Colors.blue, Colors.purple][series],
      values: [
        for (var month = 0; month < 12; month++)
          zero ? 0 : month * 100.0 + (series == 3 ? -300 : series * 100),
      ],
      dashed: series == 3,
    ),
];

Future<void> mount(
  WidgetTester tester,
  ThemeData theme,
  double width,
  double scale, {
  bool zero = false,
  int year = 2000,
}) async {
  tester.view.physicalSize = Size(width, 1000);
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
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: AnnualFlowChart(
              year: year,
              currency: '€',
              locale: 'en_US',
              series: fixture(zero: zero),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final theme in AppThemes.themes.entries) {
    for (final width in [320.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${theme.key}: all months fit without horizontal scroll $width/$scale',
          (tester) async {
            await mount(tester, theme.value, width, scale);
            expect(tester.takeException(), isNull);
            for (var month = 1; month <= 12; month++) {
              expect(
                find.text(
                  DateFormat.MMM('en_US').format(DateTime(2000, month)),
                ),
                findsOneWidget,
              );
            }
            expect(
              tester
                  .widgetList<Scrollable>(find.byType(Scrollable))
                  .where(
                    (s) =>
                        s.axisDirection == AxisDirection.left ||
                        s.axisDirection == AxisDirection.right,
                  ),
              isEmpty,
            );
            final charts = tester
                .widgetList<AppLineChart>(find.byType(AppLineChart))
                .toList();
            expect(
              charts.length,
              width == 320 ? (scale == 2 ? 4 : 2) : (scale == 2 ? 2 : 1),
            );
            final data = charts.first.data;
            expect(data.minY, lessThan(-300));
            for (final chart in charts) {
              expect(chart.data.minY, data.minY);
              expect(chart.data.maxY, data.maxY);
              expect(chart.data.lineBarsData.length, 4);
            }
            final last = find.byKey(
              ValueKey(
                'annual-flow-plot-${width == 320 ? (scale == 2 ? 9 : 6) : (scale == 2 ? 6 : 0)}',
              ),
            );
            await tester.ensureVisible(last);
            final rect = tester.getRect(last);
            await tester.tapAt(Offset(rect.right - 18, rect.center.dy));
            await tester.pump();
            expect(find.text('December 2000'), findsOneWidget);
            final details = find.byKey(const ValueKey('annual-flow-detail'));
            await tester.ensureVisible(details);
            expect(tester.takeException(), isNull);
            expect(
              find.descendant(of: details, matching: find.text('€1,100.00')),
              findsOneWidget,
            );
            expect(tester.hasRunningAnimations, isFalse);
          },
        );
      }
    }
  }
  testWidgets('Zero values keep a finite axis and keyboard selection works', (
    tester,
  ) async {
    await mount(tester, AppThemes.dark, 1200, 1, zero: true);
    final data = tester.widget<AppLineChart>(find.byType(AppLineChart)).data;
    expect(data.maxY.isFinite, isTrue);
    expect(data.maxY, greaterThan(data.minY));
    expect(
      data.lineBarsData.every(
        (line) => line.spots.every((spot) => spot.y == 0),
      ),
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('February 2000'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('January 2000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
