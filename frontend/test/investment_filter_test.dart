import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/investment_type.dart';
import 'package:mysold/screens/profile/investment_filter_dialog.dart';

void main() {
  const custom = InvestmentTypeOption(
    value: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    label: 'Métaux précieux',
    icon: Icons.diamond_outlined,
    color: Colors.amber,
  );
  const options = [...investmentTypeOptions, custom];

  Future<void> mount(
    WidgetTester tester, {
    Set<String> selected = const {},
    List<InvestmentTypeOption> categories = options,
    Locale locale = const Locale('fr'),
    double width = 390,
    double scale = 1,
    required ValueChanged<Set<String>?> onResult,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(
                await showDialog<Set<String>>(
                  context: context,
                  builder: (_) => InvestmentFilterDialog(
                    options: categories,
                    selected: selected,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(ValueKey('investment-filter-$id'));
  bool checked(WidgetTester tester, String id) =>
      tester.widget<CheckboxListTile>(row(id)).value!;

  testWidgets('Select multiple categories and apply without mutating input', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final initial = <String>{};
    Set<String>? result;
    await mount(tester, selected: initial, onResult: (value) => result = value);
    expect(checked(tester, 'all'), isTrue);
    for (final id in ['etf', custom.value]) {
      await tester.ensureVisible(row(id));
      await tester.tap(row(id));
      await tester.pumpAndSettle();
    }
    expect(checked(tester, 'all'), isFalse);
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();
    expect(result, {'etf', custom.value});
    expect(initial, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('All resets selection; cancelling does not apply draft', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    Set<String>? result = {'sentinel'};
    await mount(tester, selected: {'etf'}, onResult: (value) => result = value);
    await tester.tap(row('all'));
    await tester.pumpAndSettle();
    expect(checked(tester, 'etf'), isFalse);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await mount(tester, selected: {'etf'}, onResult: (value) => result = value);
    await tester.tap(row('all'));
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();
    expect(result, isEmpty);
  });

  testWidgets(
    'Removing final choice or selecting every category restores all',
    (tester) async {
      addTearDown(tester.view.reset);
      await mount(tester, selected: {'etf'}, onResult: (_) {});
      await tester.tap(row('etf'));
      await tester.pumpAndSettle();
      expect(checked(tester, 'all'), isTrue);
      for (final option in options) {
        await tester.ensureVisible(row(option.value));
        await tester.tap(row(option.value));
        await tester.pumpAndSettle();
      }
      expect(checked(tester, 'all'), isTrue);
    },
  );

  testWidgets('Translated controls preserve custom names, icons and colors', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(tester, locale: const Locale('en'), onResult: (_) {});
    expect(find.text('Show all'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
    expect(find.text(custom.label), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(custom.icon)).color, custom.color);
  });

  testWidgets(
    'Long catalogs scroll at mobile and desktop sizes with large text',
    (tester) async {
      addTearDown(tester.view.reset);
      final many = [
        for (var i = 0; i < 40; i++)
          InvestmentTypeOption(
            value: '$i',
            label: 'Catégorie personnalisée avec un nom très long $i',
            icon: Icons.category,
          ),
      ];
      for (final width in [320.0, 1440.0]) {
        await mount(
          tester,
          width: width,
          scale: 2,
          categories: many,
          onResult: (_) {},
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          row('39'),
          500,
          maxScrolls: 100,
          scrollable: find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(row('39'));
        await tester.pumpAndSettle();
        expect(checked(tester, '39'), isTrue);
        await tester.tap(find.text('Appliquer'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
