import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/annual_entity_row.dart';
import 'package:mysold/widgets/web_scroll_scope.dart';

void main() {
  testWidgets('Currency formatting preserves cents in all six languages', (
    tester,
  ) async {
    for (final locale in AppLocalizations.supportedLocales) {
      String? formatted;
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
          home: Builder(
            builder: (context) {
              formatted = annualEntityAmount(
                context,
                1250.37,
                'EUR',
                hidden: false,
              );
              return Text(formatted!);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(formatted, contains('37'), reason: locale.languageCode);
      expect(formatted, contains('EUR'));
    }
  });
  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Entity amount, rate and scrolling at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: WebScrollScope(child: child!),
            ),
            home: Scaffold(
              body: ListView.builder(
                controller: controller,
                itemCount: 40,
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, i) => AnnualEntityRow(
                  name: 'Un compte avec un nom particulièrement long $i',
                  subtitle: 'Compte de test',
                  amount: '1200.00 EUR',
                  percent: 20,
                  hidden: false,
                  icon: Icons.account_balance,
                  color: Colors.green,
                  onTap: () => opened++,
                  menu: EntityActionsMenu(onEdit: () {}, onDelete: () {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('1200.00 EUR'), findsWidgets);
        expect(find.text('+20.0%'), findsWidgets);
        await tester.drag(
          find.byType(AnnualEntityRow).first,
          const Offset(0, -220),
        );
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(50));
        expect(opened, 0);
        await tester.tap(find.byType(AnnualEntityRow).at(1));
        await tester.pump();
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('A menu action does not open the item detail', (tester) async {
    var opened = 0, edited = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnualEntityRow(
            name: 'Compte',
            subtitle: '',
            amount: '1200 EUR',
            percent: 20,
            hidden: false,
            icon: Icons.account_balance,
            color: Colors.green,
            onTap: () => opened++,
            menu: EntityActionsMenu(onEdit: () => edited++, onDelete: () {}),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(edited, 1);
    expect(opened, 0);
  });
  testWidgets('Unknown and hidden rates never imply a zero change', (
    tester,
  ) async {
    for (final hidden in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnualEntityRow(
              name: 'Compte',
              subtitle: '',
              amount: hidden ? '**** EUR' : '1200 EUR',
              percent: null,
              hidden: hidden,
              icon: Icons.account_balance,
              color: Colors.green,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text(hidden ? '••••' : '—'), findsOneWidget);
      expect(find.text('0.0%'), findsNothing);
    }
  });
}
