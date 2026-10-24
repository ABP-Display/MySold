import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/settings/settings_overview.dart';

const _titles = [
  'Sécurité et confidentialité',
  'Données personnelles',
  'Préférences avancées',
  'Mettre à jour l’application',
  'À propos',
];

void main() {
  for (final theme in AppThemes.themes.entries) {
    for (final width in [320.0, 768.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${theme.key}: settings groups, selectors and actions remain usable at $width/$scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final opened = <int>[];
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
                  body: SettingsOverview(
                    quickPreferences: [
                      for (final label in ['Thème', 'Langue', 'Devise'])
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: label,
                          decoration: InputDecoration(labelText: label),
                          items: [
                            DropdownMenuItem(value: label, child: Text(label)),
                          ],
                          onChanged: (_) {},
                        ),
                    ],
                    actions: [
                      for (var i = 0; i < _titles.length; i++)
                        SettingsAction(
                          title: _titles[i],
                          subtitle: i == 2
                              ? 'Notifications et mode discret'
                              : 'Personnalisez votre application et vos préférences.',
                          icon: Icons.tune,
                          onTap: () => opened.add(i),
                        ),
                    ],
                    footer: TextButton(
                      onPressed: () {},
                      child: const Text('Déconnexion'),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Préférences rapides'), findsOneWidget);
            expect(find.text('Double authentification'), findsNothing);
            expect(find.text('Notifications'), findsNothing);
            for (var i = 0; i < _titles.length; i++) {
              final row = find.text(_titles[i]);
              await tester.scrollUntilVisible(
                row,
                250,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.ensureVisible(row);
              await tester.pumpAndSettle();
              await tester.tap(row);
              expect(opened.last, i);
              expect(tester.takeException(), isNull);
            }
            expect(opened, [0, 1, 2, 3, 4]);
          },
        );
      }
    }
    testWidgets(
      '${theme.key}: notifications and privacy are grouped in advanced preferences',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var hide = false, shake = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.value,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => AdvancedPreferencesContent(
                  notifications: false,
                  budgetAlerts: true,
                  hideAmounts: hide,
                  shakeEnabled: shake,
                  requestingMotion: false,
                  loading: false,
                  onNotifications: (_) {},
                  onBudgetAlerts: (_) {},
                  onHideAmounts: (value) => setState(() => hide = value),
                  onShake: (value) => setState(() => shake = value),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Notifications'), findsOneWidget);
        final alerts = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Alertes budgétaires'),
        );
        expect(alerts.onChanged, isNull);
        for (final title in ['Masquer les montants', 'Secouer pour cacher']) {
          await tester.scrollUntilVisible(find.text(title), 250);
          await tester.ensureVisible(find.text(title));
          await tester.pumpAndSettle();
          await tester.tap(find.text(title));
          await tester.pumpAndSettle();
        }
        expect(hide, isTrue);
        expect(shake, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
