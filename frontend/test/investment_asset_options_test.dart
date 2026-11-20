import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/investment_type.dart';
import 'package:mysold/widgets/app_select_field.dart';
import 'package:mysold/widgets/investment_asset_options.dart';

const custom = InvestmentTypeOption(
  value: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  label: 'Métaux précieux',
  color: Color(0xffffb74d),
  icon: Icons.diamond_outlined,
);
const names = {
  'gold': 'Or personnalisé',
  'etf': 'ETF Monde',
  'old': 'Ancien actif',
};
const types = {'gold': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'etf': 'etf'};

void main() {
  testWidgets(
    'Asset options use category identity without changing asset IDs or names',
    (tester) async {
      late List<AppSelectOption<String>> options;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              options = investmentAssetOptions(
                context,
                investments: names,
                assetTypes: types,
                categories: [...investmentTypeOptions, custom],
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(options.map((o) => o.value), names.keys);
      expect(options.map((o) => o.label), names.values);
      expect(options.first.subtitle, 'Métaux précieux');
      expect(options.first.icon, Icons.diamond_outlined);
      expect(options.first.color, const Color(0xffffb74d));
      expect(options[1].icon, investmentTypeOption('etf').icon);
      expect(options[1].color, investmentTypeOption('etf').color);
      expect(options.last.icon, investmentTypeOption('other').icon);
      expect(options.last.subtitle, 'Other');
    },
  );

  for (final width in [320.0, 1440.0]) {
    for (final dark in [true, false]) {
      testWidgets(
        'Closed field and menu preserve category styles at $width/$dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var selected = 'gold';
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              locale: const Locale('fr'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppSelectField<String>(
                      label: 'Actif',
                      icon: Icons.trending_up,
                      value: selected,
                      options: investmentAssetOptions(
                        context,
                        investments: names,
                        assetTypes: types,
                        categories: [...investmentTypeOptions, custom],
                      ),
                      onChanged: (value) => setState(() => selected = value!),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Icon prefix() =>
              tester
                      .widget<InputDecorator>(find.byType(InputDecorator))
                      .decoration
                      .prefixIcon!
                  as Icon;
          expect(prefix().icon, custom.icon);
          expect(prefix().color, custom.color);
          await tester.tap(find.text('Or personnalisé'));
          await tester.pumpAndSettle();
          expect(find.text('Métaux précieux'), findsOneWidget);
          final icon = tester.widget<Icon>(
            find.descendant(
              of: find.byType(ListTile),
              matching: find.byIcon(Icons.diamond_outlined),
            ),
          );
          expect(icon.color, custom.color);
          await tester.tap(find.text('ETF Monde'));
          await tester.pumpAndSettle();
          expect(selected, 'etf');
          expect(prefix().icon, investmentTypeOption('etf').icon);
          expect(prefix().color, investmentTypeOption('etf').color);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
