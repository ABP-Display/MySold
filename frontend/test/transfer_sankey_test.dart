import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/month_operation_charts.dart';
import 'package:mysold/widgets/graphiques/transfer_sankey_chart.dart';
import 'package:mysold/widgets/graphiques/transfer_sankey_layout.dart';

List<TransferRoute> sample() => transferRoutes(DateTime(2026, 11), [
  TransferChartEntry('a', 'b', false, DateTime(2026, 11, 2), 200),
  TransferChartEntry('a', 'b', false, DateTime(2026, 11, 8), 150),
  TransferChartEntry('a', 'c', false, DateTime(2026, 11, 10), 125),
]);

void main() {
  test('Ribbons conserve cents, proportion and direction at every width', () {
    for (final width in [262.0, 332.0, 1080.0]) {
      final layout = TransferSankeyLayout.build(Size(width, 190), sample(), 1);
      expect(layout.sources.single.cents, 47500);
      expect(layout.targets.map((n) => n.cents), [35000, 12500]);
      expect(
        layout.bands[0].thickness / layout.bands[1].thickness,
        closeTo(350 / 125, .0001),
      );
      for (final node in [...layout.sources, ...layout.targets]) {
        expect(node.rect.left, greaterThanOrEqualTo(0));
        expect(node.rect.right, lessThanOrEqualTo(width));
        expect(node.rect.top, greaterThanOrEqualTo(0));
        expect(node.rect.bottom, lessThanOrEqualTo(layout.size.height));
      }
      for (final band in layout.bands) {
        expect(band.start.dx, lessThan(band.end.dx));
        expect(layout.hitTest(band.point(.65)), band.routeIndex);
        expect(band.path.contains(band.point(.65)), isTrue);
      }
      expect(layout.hitTest(const Offset(-20, -20)), isNull);
    }
  });

  test('Reciprocal transfers and asset withdrawals keep distinct nodes', () {
    final routes = transferRoutes(DateTime(2026, 11), [
      TransferChartEntry('a', 'b', false, DateTime(2026, 11, 1), 100),
      TransferChartEntry('b', 'a', false, DateTime(2026, 11, 1), 50),
      TransferChartEntry('a', 'b', true, DateTime(2026, 11, 1), 25),
    ]);
    final layout = TransferSankeyLayout.build(const Size(262, 230), routes, 1);
    expect(layout.sources.map((n) => n.key).toSet(), {
      (false, 'a'),
      (false, 'b'),
      (true, 'a'),
    });
    expect(layout.targets.map((n) => n.key).toSet(), {
      (false, 'a'),
      (false, 'b'),
    });
    expect(layout.sources.fold(0, (sum, n) => sum + n.cents), 17500);
    expect(layout.targets.fold(0, (sum, n) => sum + n.cents), 17500);
  });

  test(
    'Many accounts reserve enough canvas height without overlapping nodes',
    () {
      final routes = transferRoutes(DateTime(2026, 11), [
        for (var i = 0; i < 30; i++)
          TransferChartEntry('s$i', 't$i', false, DateTime(2026, 11, 1), i + 1),
      ]);
      for (final scale in [1.0, 2.0]) {
        final height = TransferSankeyLayout.requiredHeight(routes, scale);
        final layout = TransferSankeyLayout.build(
          Size(262, height),
          routes,
          scale,
        );
        for (final side in [layout.sources, layout.targets]) {
          for (var i = 0; i < side.length - 1; i++) {
            expect(side[i].rect.bottom, lessThan(side[i + 1].rect.top));
          }
        }
        expect(layout.bands.every((b) => b.thickness > 0), isTrue);
      }
      final empty = TransferSankeyLayout.build(const Size(262, 190), [], 1);
      expect(empty.bands, isEmpty);
      expect(empty.hitTest(const Offset(100, 100)), isNull);
    },
  );

  Future<void> showChart(
    WidgetTester tester,
    double width, {
    bool dark = true,
    double scale = 1,
    List<TransferRoute>? routes,
  }) async {
    tester.view.reset();
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
        ),
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: math.min(width - 58, 1080),
                    height: 226,
                    child: TransferSankeyChart(
                      routes: routes ?? sample(),
                      accounts: const {
                        'a': 'Compte courant avec un nom très long',
                        'b': 'Livret A',
                        'c': 'Épargne de précaution',
                      },
                      investments: const {},
                      money: (cents) => '${(cents / 100).toStringAsFixed(2)} €',
                    ),
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

  testWidgets('Canvas is responsive with large text and both themes', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final width in [320.0, 390.0, 1440.0]) {
      for (final dark in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          await showChart(tester, width, dark: dark, scale: scale);
          expect(
            find.byKey(const ValueKey('transfer-sankey-paint')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull, reason: '$width/$dark/$scale');
        }
      }
    }
  });

  testWidgets('Tapping a painted ribbon opens grouped operations and back', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await showChart(tester, 390);
    final canvas = find.byKey(const ValueKey('transfer-sankey-paint'));
    final size = tester.getSize(canvas);
    final layout = TransferSankeyLayout.build(size, sample(), 1);
    await tester.tapAt(
      tester.getTopLeft(canvas) + layout.bands.first.point(.5),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 opérations'), findsOneWidget);
    expect(find.text('350.00 €'), findsOneWidget);
    expect(find.text('200.00 €'), findsOneWidget);
    expect(find.text('150.00 €'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour au graphique'));
    await tester.pumpAndSettle();
    expect(canvas, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Vertical drag on a ribbon scrolls the page, not its details', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await showChart(tester, 390);
    final canvas = find.byKey(const ValueKey('transfer-sankey-paint'));
    final top = tester.getTopLeft(canvas).dy;
    await tester.dragFrom(tester.getCenter(canvas), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(canvas).dy, lessThan(top - 40));
    expect(find.byTooltip('Retour au graphique'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
