import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/app_workspace.dart';
import 'package:mysold/screens/settings/theme_settings.dart';

void main() {
  for (final entry in AppThemes.themes.entries) {
    for (final size in [
      const Size(320, 568),
      const Size(768, 700),
      const Size(1440, 900),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${entry.key}: workspace, privacy and modal at $size / $scale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var hidden = false;
            var selected = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: entry.value,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: StatefulBuilder(
                  builder: (context, setState) => AppWorkspace(
                    selectedIndex: selected,
                    destinations: const [
                      WorkspaceDestination('Mois', Icons.calendar_month),
                      WorkspaceDestination('Stats', Icons.query_stats),
                      WorkspaceDestination('Global', Icons.dashboard),
                      WorkspaceDestination('Profil', Icons.person),
                    ],
                    onSelected: (value) => setState(() => selected = value),
                    hidden: hidden,
                    onPrivacy: () => setState(() => hidden = !hidden),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const PageIntro(
                          title: 'Budget mensuel',
                          subtitle: 'Vos opérations, simplement.',
                        ),
                        const AppMetricGrid(
                          children: [
                            AppMetricCard(
                              label: 'Investissements annuels',
                              value: '123456.78 €',
                              icon: Icons.trending_up,
                              color: Colors.green,
                            ),
                            AppMetricCard(
                              label: 'Projection fin de mois',
                              value: '54321.00 €',
                              icon: Icons.timeline,
                              color: Colors.orange,
                            ),
                          ],
                        ),
                        AppOperationCard(
                          title:
                              'Courses de la semaine et fournitures pour la maison',
                          subtitle:
                              'Compte courant principal · Alimentation · 23/10/2026',
                          amount: '-123 456,78 €',
                          icon: Icons.shopping_basket_outlined,
                          color: Colors.orange,
                          onTap: () {},
                        ),
                        AppPanel(
                          child: FilledButton(
                            onPressed: () => showAppSheet(
                              context: context,
                              builder: (context) => Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const AppDialogHeader(
                                      title: 'Préférences du budget',
                                      icon: Icons.tune,
                                    ),
                                    for (var i = 0; i < 12; i++)
                                      TextField(
                                        decoration: InputDecoration(
                                          labelText: 'Champ $i',
                                        ),
                                      ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Terminer'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            child: const Text('Ouvrir'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byType(NavigationBar),
              size.width >= 1040 && scale == 1 ? findsNothing : findsOneWidget,
            );
            await tester.tap(find.byIcon(Icons.visibility_outlined));
            await tester.pumpAndSettle();
            expect(hidden, isTrue);
            await tester.tap(find.byIcon(Icons.person).first);
            await tester.pumpAndSettle();
            expect(selected, 3);
            await tester.scrollUntilVisible(
              find.text('Ouvrir'),
              180,
              scrollable: find.byType(Scrollable).first,
            );
            await Scrollable.ensureVisible(
              tester.element(find.text('Ouvrir')),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Ouvrir'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final dialogContext = tester.element(find.byType(AppDialogHeader));
            expect(
              Theme.of(dialogContext).colorScheme.surface,
              entry.value.colorScheme.surface,
            );
            expect(
              find.byType(Dialog),
              size.width >= 760 ? findsOneWidget : findsNothing,
            );
            await tester.ensureVisible(find.text('Terminer'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Terminer'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Terminer'), findsNothing);
          },
        );
      }
    }
  }
}
