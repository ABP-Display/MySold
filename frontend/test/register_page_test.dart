// MySold imports browser APIs: run with flutter test --platform chrome.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/register_page.dart';

void main() {
  Future<void> open(WidgetTester tester, Size size, {double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Register(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> profile(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    for (final entry in [
      'Alice',
      'Martin',
      'alice@example.test',
      '0601020304',
    ].indexed) {
      await tester.enterText(fields.at(entry.$1), entry.$2);
    }
    await tap(tester, 'Continuer');
  }

  for (final size in [
    const Size(360, 640),
    const Size(768, 700),
    const Size(1440, 900),
  ]) {
    testWidgets('Registration fits $size through all steps', (tester) async {
      await open(tester, size);
      expect(tester.takeException(), isNull);
      await profile(tester);
      expect(find.text('Protégez votre espace'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'MySold-Test-123!');
      await tester.enterText(fields.at(1), 'MySold-Test-123!');
      await tester.enterText(fields.at(2), '123456');
      await tap(tester, 'Continuer');
      expect(find.text('À votre image'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tap(tester, 'Retour');
      expect(find.text('123456'), findsOneWidget);
      await tap(tester, 'Retour');
      expect(find.text('alice@example.test'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Required fields prevent advancing', (tester) async {
    await open(tester, const Size(360, 640));
    await tap(tester, 'Continuer');
    expect(find.text('Faisons connaissance'), findsOneWidget);
    expect(find.text('Ce champ est requis.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text and short viewport remain scrollable', (
    tester,
  ) async {
    await open(tester, const Size(320, 400), scale: 2);
    expect(tester.takeException(), isNull);
    await profile(tester);
    await tap(tester, 'Continuer');
    expect(find.text('Protégez votre espace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
