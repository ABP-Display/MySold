import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/models/category_filter.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/category_amount_filter.dart';
import 'package:mysold/widgets/category_filter_bar.dart';

void main() {
  for (final theme in AppThemes.themes.entries) {
    for (final width in [320.0, 1200.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${theme.key}: category controls fit $width/$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = TextEditingController();
          addTearDown(controller.dispose);
          var searched = '', selected = CategoryOrder.nameAscending;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.value,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    StatefulBuilder(
                      builder: (context, refresh) => CategoryFilterBar(
                        controller: controller,
                        order: selected,
                        amountFiltered: true,
                        onSearch: (value) => refresh(() => searched = value),
                        onOrder: (value) => refresh(() => selected = value),
                        onAmount: () => showAppSheet<CategoryAmountRange>(
                          context: context,
                          builder: (_) => const CategoryAmountFilter(),
                        ),
                        onClearAmount: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.enterText(
            find.byKey(const ValueKey('category-name-filter')),
            'gaz',
          );
          await tester.pump();
          expect(searched, 'gaz');
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(const ValueKey('category-amount-filter')),
          );
          await tester.tap(
            find.byKey(const ValueKey('category-amount-filter')),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('category-minimum')),
            '50,25',
          );
          await tester.enterText(
            find.byKey(const ValueKey('category-maximum')),
            '10',
          );
          await tester.ensureVisible(find.text('Appliquer'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Appliquer'));
          await tester.pumpAndSettle();
          expect(
            find.text('Le maximum doit être supérieur ou égal au minimum.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
    'French decimals and spaces parse; reset returns unbounded range',
    (tester) async {
      CategoryAmountRange? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showAppSheet<CategoryAmountRange>(
                    context: context,
                    builder: (_) => const CategoryAmountFilter(),
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-minimum')),
        '1 000,25',
      );
      await tester.enterText(
        find.byKey(const ValueKey('category-maximum')),
        '2000',
      );
      await tester.ensureVisible(find.text('Appliquer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      expect(result, (minimum: 1000.25, maximum: 2000.0));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Réinitialiser'));
      await tester.tap(find.text('Réinitialiser'));
      await tester.pumpAndSettle();
      expect(result, (minimum: null, maximum: null));
      expect(tester.takeException(), isNull);
    },
  );
}
