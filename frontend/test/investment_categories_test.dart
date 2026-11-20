import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/investment_type.dart';
import 'package:mysold/models/month_chart_series.dart';
import 'package:mysold/models/month_operation_charts.dart';
import 'package:mysold/screens/profile/investment_categories_page.dart';
import 'package:mysold/widgets/graphiques/investment_sections_chart.dart';

void main() {
  test('Legacy defaults and custom presentation survive serialization', () {
    expect(investmentCategoriesFromProfile(null), investmentTypeOptions);
    const custom = InvestmentTypeOption(
      value: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      label: 'Métaux précieux',
      color: Colors.amber,
      icon: Icons.diamond_outlined,
    );
    final options = investmentCategoriesFromProfile([
      ...investmentTypeOptions.map((o) => o.toMap()),
      custom.toMap(),
    ]);
    final value = investmentTypeOption(custom.value, options: options);
    expect(value.label, custom.label);
    expect(value.color.toARGB32(), custom.color.toARGB32());
    expect(value.icon.codePoint, custom.icon.codePoint);
    expect(value.builtInLabel, isFalse);
    expect(
      investmentTypeOption('legacy-unknown', options: options).value,
      'other',
    );
    expect(() => options.clear(), throwsUnsupportedError);
  });

  test('Custom categories remain distinct in monthly stacked bars', () {
    const id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final sections = investmentSections(
      DateTime(2026, 11),
      [
        MonthChartEntry(DateTime(2026, 11, 1), 29.14, 'gold'),
        MonthChartEntry(DateTime(2026, 11, 1), 48.3, 'gold'),
        MonthChartEntry(DateTime(2026, 11, 9), 10, 'old'),
      ],
      {'gold': id, 'old': 'missing'},
      categoryTypes: ['other', id],
    );
    expect(sections.first.types, {id: 7744});
    expect(sections[1].types, {'other': 1000});
    expect(
      investmentSectionColor(
        id,
        options: [
          investmentTypeOptions.last,
          const InvestmentTypeOption(
            value: id,
            label: 'Or',
            color: Colors.amber,
            icon: Icons.diamond,
          ),
        ],
      ),
      Colors.amber,
    );
  });

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    Locale locale = const Locale('fr'),
    Set<String> used = const {},
    required Future<void> Function(List<InvestmentTypeOption>) save,
  }) async {
    tester.view.physicalSize = Size(width, 900);
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
        home: InvestmentCategoriesPage(
          options: investmentTypeOptions,
          usedTypes: used,
          createId: () => 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          onSave: save,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Adding and deleting an unused category uses its stable ID', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    List<InvestmentTypeOption>? saved;
    await mount(tester, save: (options) async => saved = options);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Métaux précieux');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(saved!.last.label, 'Métaux précieux');
    expect(saved!.last.value, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    final row = find.byKey(
      const ValueKey('investment-category-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
    );
    await tester.ensureVisible(row);
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('Supprimer')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(saved!.length, investmentTypeOptions.length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Used categories and fallback cannot be deleted', (tester) async {
    addTearDown(tester.view.reset);
    await mount(
      tester,
      used: {'etf'},
      save: (_) async => fail('No write expected'),
    );
    final etf = find.byKey(const ValueKey('investment-category-etf'));
    final fallback = find.byKey(const ValueKey('investment-category-other'));
    for (final row in [etf, fallback]) {
      final buttons = tester.widgetList<IconButton>(
        find.descendant(of: row, matching: find.byType(IconButton)),
      );
      expect(buttons.last.onPressed, isNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Duplicate category names are rejected before writing', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(tester, save: (_) async => fail('No write expected'));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), ' ETF ');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Un nom unique est requis.'), findsOneWidget);
  });

  testWidgets('Rows and editor remain responsive with large text', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final width in [320.0, 1440.0]) {
      await mount(tester, width: width, scale: 2, save: (_) async {});
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(TextFormField))).pop();
      await tester.pumpAndSettle();
    }
  });
}
