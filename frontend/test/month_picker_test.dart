import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/month_page_header.dart';
import 'package:mysold/widgets/month_year_picker.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Month selector retains its dimensions across months $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var september = false, opened = 0;
          late StateSetter update;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppThemes.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (_, setState) {
                    update = setState;
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: MonthPageHeader(
                        title: 'Budget mensuel',
                        subtitle: 'Vos opérations',
                        eyebrow: 'Budget',
                        monthLabel: september ? 'septembre 2026' : 'mai 2026',
                        compactMonthLabel: september
                            ? 'sept. 2026'
                            : 'mai 2026',
                        previousLabel: 'Mois précédent',
                        nextLabel: 'Mois suivant',
                        onPrevious: () {},
                        onNext: () {},
                        onChoose: () => opened++,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          final first = tester.getSize(
            find.byKey(const ValueKey('month-selector')),
          );
          update(() => september = true);
          await tester.pump();
          expect(
            tester.getSize(find.byKey(const ValueKey('month-selector'))),
            first,
          );
          await tester.tap(find.byKey(const ValueKey('month-selector-choose')));
          expect(opened, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final theme in AppThemes.themes.entries) {
    for (final width in [320.0, 1200.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${theme.key}: direct month/year choice works at $width/$scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            DateTime? chosen;
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
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        chosen = await showMonthYearPicker(
                          context,
                          DateTime(2026, 10, 1),
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
              find.byKey(const ValueKey('month-picker-year')),
              '2020',
            );
            final month = find.byKey(const ValueKey('month-picker-9'));
            await tester.ensureVisible(month);
            await tester.tap(month);
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Afficher'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Afficher'));
            await tester.pumpAndSettle();
            expect(chosen, DateTime(2020, 9, 1));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'Invalid year does not close; cancel preserves the current month',
    (tester) async {
      DateTime? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  chosen = await showMonthYearPicker(
                    context,
                    DateTime(2026, 10),
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
        find.byKey(const ValueKey('month-picker-year')),
        'nope',
      );
      await tester.ensureVisible(find.text('Afficher'));
      await tester.tap(find.text('Afficher'));
      await tester.pumpAndSettle();
      expect(find.text('Saisissez une année entre 1 et 9999.'), findsOneWidget);
      await tester.ensureVisible(find.text('Annuler'));
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
