import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/models/annual_evolution.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/annual_evolution_section.dart';

void main() {
  test('Rates handle zero baselines, losses, overdrafts and cents', () {
    EvolutionEntry row(double start, double end) =>
        EvolutionEntry(id: 'x', name: 'Test', beginning: start, ending: end);
    expect(row(0, 100).percent, isNull);
    expect(row(0, 0).percent, 0);
    expect(row(100, 80).percent, -20);
    expect(row(-100, 50).percent, 150);
    expect(row(.1, .3).change, .2);
  });
  test('Server report retains category types and archived amounts', () {
    final report = AnnualEvolution.fromMap({
      'year': 2026,
      'asOf': '2026-11-01',
      'source': 'rollover',
      'future': false,
      'accounts': [
        {'id': 'a', 'name': 'Cash', 'beginning': 100, 'ending': 120},
      ],
      'categories': [
        {
          'id': 'expense:x',
          'type': 'expense',
          'name': 'Food',
          'beginning': 80,
          'ending': 100,
        },
        {
          'id': 'income:y',
          'type': 'income',
          'name': 'Salary',
          'beginning': 200,
          'ending': 400,
        },
      ],
    });
    expect(report.accounts.single.percent, 20);
    expect(report.expenses.single.name, 'Food');
    expect(report.income.single.ending, 400);
  });
  const entries = [
    EvolutionEntry(
      id: 'a',
      name: 'Compte courant avec un nom particulièrement long',
      beginning: 12345678.12,
      ending: 23456789.34,
    ),
    EvolutionEntry(id: 'b', name: 'Découvert', beginning: -100, ending: -50),
    EvolutionEntry(id: 'c', name: 'Sans historique', beginning: 0, ending: 200),
    EvolutionEntry(id: 'd', name: 'Vide', beginning: 0, ending: 0),
  ];
  for (final theme in AppThemes.themes.entries) {
    for (final width in [320.0, 390.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${theme.key} evolution fits $width / $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
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
                  padding: const EdgeInsets.all(20),
                  children: [
                    const AnnualEvolutionSection(
                      title: 'Évolution des comptes',
                      subtitle: 'Référence annuelle conservée.',
                      beginningLabel: '1 janvier 2026',
                      endingLabel: '1 novembre 2026',
                      entries: entries,
                      currency: '€',
                      icon: Icons.account_balance,
                      emptyLabel: 'Vide',
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('Privacy hides amounts, rates and the zero-baseline hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnnualEvolutionSection(
              title: 'Evolution',
              subtitle: 'Annual',
              beginningLabel: 'Start',
              endingLabel: 'End',
              entries: entries,
              currency: '€',
              icon: Icons.account_balance,
              emptyLabel: 'Empty',
              hideAmounts: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Base nulle'), findsNothing);
    expect(find.textContaining('12345678'), findsNothing);
    expect(find.text('** %'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
  testWidgets('All rows can be displayed; empty future report stays explicit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnnualEvolutionSection(
              title: 'Evolution',
              subtitle: 'Annual',
              beginningLabel: 'Start',
              endingLabel: 'End',
              entries: [
                for (var i = 0; i < 8; i++)
                  EvolutionEntry(
                    id: '$i',
                    name: 'Row $i',
                    beginning: 0,
                    ending: 0,
                  ),
              ],
              currency: '€',
              icon: Icons.account_balance,
              emptyLabel: 'Empty',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Row 7'), findsNothing);
    await tester.ensureVisible(find.text('Afficher plus (2)'));
    await tester.tap(find.text('Afficher plus (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Row 7'), findsOneWidget);
  });
}
