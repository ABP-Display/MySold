import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/app_choice_tabs.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/app_select_field.dart';
import 'package:mysold/screens/settings/theme_settings.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(768, 700),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Amounts stay centered right; selector searches and validates at $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final form = GlobalKey<FormState>();
          String? selected;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppThemes.forest,
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
                    AppOperationCard(
                      title: 'Une opération avec un libellé assez long',
                      subtitle: 'Compte courant · Alimentation · 24/10/2026',
                      amount: '-123 456,78 €',
                      icon: Icons.payments_outlined,
                      color: Colors.green,
                      onTap: () {},
                    ),
                    Form(
                      key: form,
                      child: AppSelectField<String>(
                        label: 'Compte',
                        icon: Icons.account_balance_wallet_outlined,
                        options: const [
                          AppSelectOption(
                            value: 'courant',
                            label: 'Compte courant',
                          ),
                          AppSelectOption(
                            value: 'livret',
                            label: 'Livret épargne',
                          ),
                        ],
                        onChanged: (value) => selected = value,
                        validator: (value) =>
                            value == null ? 'Choisir un compte' : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final card = tester.getRect(find.byType(AppOperationCard));
          final amount = tester.getRect(find.text('-123 456,78 €'));
          expect(amount.center.dy, closeTo(card.center.dy, 1));
          expect(amount.right, closeTo(card.right - 14, 1));
        await tester.scrollUntilVisible(find.byType(Form), 180);
        await tester.pumpAndSettle();
        expect(form.currentState!.validate(), isFalse);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(AppSelectField<String>));
          await tester.tap(find.byType(AppSelectField<String>));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.enterText(find.byType(TextField), 'epargne');
          await tester.pumpAndSettle();
          expect(find.text('Compte courant'), findsNothing);
          await tester.ensureVisible(find.text('Livret épargne'));
          await tester.tap(find.text('Livret épargne'));
          await tester.pumpAndSettle();
          expect(selected, 'livret');
          expect(form.currentState!.validate(), isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('PC operation tabs have equal widths and preserve selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.light,
        home: Scaffold(
          body: AppChoiceTabs(
            labels: const [
              'Dépenses',
              'Revenus',
              'Investissements',
              'Transferts',
            ],
            icons: const [
              Icons.money_off,
              Icons.attach_money,
              Icons.trending_up,
              Icons.sync_alt,
            ],
            selectedIndex: 0,
            onSelected: (index) => selected = index,
          ),
        ),
      ),
    );
    final widths = [
      for (var i = 0; i < 4; i++)
        tester.getSize(find.byKey(ValueKey('operation-type-$i'))).width,
    ];
    for (final width in widths) {
      expect(width, closeTo(widths.first, 0.01));
    }
    await tester.tap(find.text('Investissements'));
    expect(selected, 2);
  });
  testWidgets(
    'Selecting all accounts emits null; external changes update field',
    (tester) async {
      String? selected = 'courant';
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                refresh = setState;
                return AppSelectField<String?>(
                  label: 'Compte',
                  icon: Icons.account_balance_wallet,
                  value: selected,
                  options: const [
                    AppSelectOption(value: null, label: 'Tous les comptes'),
                    AppSelectOption(value: 'courant', label: 'Compte courant'),
                  ],
                  onChanged: (value) => setState(() => selected = value),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AppSelectField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tous les comptes'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.text('Tous les comptes'), findsOneWidget);
      refresh(() => selected = 'courant');
      await tester.pumpAndSettle();
      expect(find.text('Compte courant'), findsOneWidget);
    },
  );
}
