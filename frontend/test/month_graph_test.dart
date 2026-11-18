@TestOn('browser')
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/screens/month/month_graph.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixtures/month_chart_fixture.dart';

void main() {
  setUpAll(initializeDateFormatting);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final transactions = monthChartFixture();
  Widget graph(
    String type, {
    PrivacyProvider? privacy,
    bool light = false,
    double scale = 1,
    String language = 'fr',
    ScrollController? scroll,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ChangeNotifierProvider.value(value: privacy ?? PrivacyProvider()),
    ],
    child: MaterialApp(
      theme: light ? AppThemes.light : AppThemes.dark,
      locale: Locale(language),
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
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          controller: scroll,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: MonthGraph(
                  month: DateTime(2026, 6),
                  transactions: transactions,
                  categories: chartFixtureCategories,
                  accountIds: chartFixtureAccounts,
                  investmentIds: chartFixtureInvestments,
                  investmentTypes: chartFixtureTypes,
                  type: type,
                ),
              ),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      ),
    ),
  );

  for (final width in [320.0, 390.0, 1280.0]) {
    for (final type in ['expense', 'income', 'investment', 'transfer']) {
      testWidgets(
        '$type layout at $width in both themes and enlarged German text',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          for (final light in [false, true]) {
            await tester.pumpWidget(
              graph(type, light: light, scale: 2, language: 'de'),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
  testWidgets(
    'Week selection shows daily bars and back restores monthly bars',
    (tester) async {
      await tester.pumpWidget(graph('investment'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<BarChart>(find.byType(BarChart)).data.barGroups.length,
        5,
      );
      await tester.tap(find.byKey(const ValueKey('investment-week-1')));
      await tester.pumpAndSettle();
      final bars = tester
          .widget<BarChart>(find.byType(BarChart))
          .data
          .barGroups;
      expect(bars.length, 7);
      expect(bars.map((b) => b.barRods.single.toY), [50, 20, 10, 50, 20, 0, 0]);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('investment-period-total')))
            .data,
        contains('150,00'),
      );
      await tester.tap(find.byKey(const ValueKey('investment-back-month')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<BarChart>(find.byType(BarChart)).data.barGroups.length,
        5,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Privacy removes amounts, chart painting and interactive week selection',
    (tester) async {
      final privacy = PrivacyProvider();
      await tester.pumpWidget(graph('investment', privacy: privacy));
      await tester.pumpAndSettle();
      await privacy.setHideAmounts(true);
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyChartMask), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
      expect(
        find.byKey(const ValueKey('investment-period-total')),
        findsNothing,
      );
      await privacy.setHideAmounts(false);
      await tester.pumpAndSettle();
      expect(find.byType(BarChart), findsOneWidget);
    },
  );
  for (final type in ['expense', 'income', 'investment', 'transfer']) {
    testWidgets(
      'Vertical touch starting on $type chart scrolls without selecting',
      (tester) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(graph(type, scroll: scroll));
        await tester.pumpAndSettle();
        final origin = type == 'investment'
            ? tester.getCenter(find.byKey(const ValueKey('investment-week-1')))
            : const Offset(230, 180);
        final gesture = await tester.startGesture(
          origin,
          kind: PointerDeviceKind.touch,
        );
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveBy(const Offset(0, -70));
        await tester.pump();
        expect(scroll.offset, greaterThan(40));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('investment-back-month')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('A mutable transaction edit invalidates cached graph totals', (
    tester,
  ) async {
    await tester.pumpWidget(graph('income'));
    await tester.pumpAndSettle();
    final tx = transactions.firstWhere((t) => t.type == 'income'),
        previous = tx.amount;
    addTearDown(() => tx.amount = previous);
    tx.amount += 100;
    await tester.pumpWidget(graph('income'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('month-chart-total'))).data,
      contains('538,30'),
    );
  });
}
