import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/auth_layout.dart';

void main() {
  for (final size in [
    const Size(320, 400),
    const Size(768, 700),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Dark auth card and SVG fit $size at text scale $scale', (
        tester,
      ) async {
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
            home: AuthScaffold(
              formBuilder: (context, compact) => Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (compact) const AuthBrand(),
                    const SizedBox(height: 24),
                    const TextField(
                      decoration: InputDecoration(labelText: 'Adresse e-mail'),
                    ),
                    const SizedBox(height: 18),
                    const TextField(
                      decoration: InputDecoration(labelText: 'Mot de passe'),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Continuer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(
          Theme.of(tester.element(find.byType(TextField).first)).brightness,
          Brightness.dark,
        );
        await tester.ensureVisible(find.text('Continuer'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
