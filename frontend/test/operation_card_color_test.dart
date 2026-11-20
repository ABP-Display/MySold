import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/app_design.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance(), second = b.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}

void main() {
  for (final entry in AppThemes.themes.entries) {
    testWidgets(
      '${entry.key}: whole tile uses category tint and readable text',
      (tester) async {
        for (final color in [
          Colors.red,
          Colors.green,
          Colors.blue,
          Colors.amber,
          Colors.purple,
          Colors.cyan,
          Colors.white,
          Colors.black,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: entry.value,
              home: Scaffold(
                body: AppOperationCard(
                  title: 'Courses',
                  subtitle: 'Compte courant - Alimentation - 20/11/2026',
                  amount: '-42,35 €',
                  icon: Icons.shopping_basket_outlined,
                  color: color,
                  onTap: () {},
                ),
              ),
            ),
          );
          final card = tester.widget<Card>(find.byType(Card));
          final expected = Color.alphaBlend(
            color.withValues(
              alpha: entry.value.brightness == Brightness.dark ? .18 : .10,
            ),
            entry.value.cardTheme.color ?? entry.value.colorScheme.surface,
          );
          expect(card.color, expected);
          expect(card.surfaceTintColor, Colors.transparent);
          expect(
            contrast(entry.value.colorScheme.onSurface, card.color!),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(
              tester
                  .widget<Text>(
                    find.text('Compte courant - Alimentation - 20/11/2026'),
                  )
                  .style!
                  .color!,
              card.color!,
            ),
            greaterThanOrEqualTo(4.5),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'Color changes preserve tile dimensions, amounts and tap action',
    (tester) async {
      var taps = 0;
      Size? original;
      for (final color in [Colors.red, Colors.blue, Colors.amber]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.dark,
            home: Scaffold(
              body: SizedBox(
                width: 390,
                child: AppOperationCard(
                  title: 'Courses',
                  subtitle: 'Compte courant - Alimentation - 20/11/2026',
                  amount: '-42,35 €',
                  icon: Icons.shopping_basket_outlined,
                  color: color,
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        );
        final size = tester.getSize(find.byType(AppOperationCard));
        original ??= size;
        expect(size, original);
        expect(find.text('-42,35 €'), findsOneWidget);
        await tester.tap(find.byType(AppOperationCard));
      }
      expect(taps, 3);
    },
  );
}
