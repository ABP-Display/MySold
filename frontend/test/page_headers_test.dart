import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/auth_layout.dart';

void main() {
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('PIN branding is centered and spaced at $width/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AuthPalette.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(40),
                child: AuthPinHeader(
                  title: 'Créer votre PIN',
                  description:
                      'Choisissez un code à 6 chiffres pour sécuriser votre espace.',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final logo = tester.getRect(find.byType(AuthLogo));
        final title = tester.getRect(find.text('Créer votre PIN'));
        final description = tester.getRect(find.textContaining('Choisissez'));
        expect(logo.center.dx, closeTo(width / 2, 0.5));
        expect(title.center.dx, closeTo(logo.center.dx, 0.5));
        expect(title.top - logo.bottom, 24);
        expect(description.top - title.bottom, 12);
        expect(
          (tester.widget<Image>(find.byType(Image)).image as AssetImage)
              .assetName,
          'assets/icons/logo.png',
        );
      });

      testWidgets(
        'Long page title and selector remain usable at $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selected = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppThemes.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: DefaultTabController(
                length: 2,
                child: Builder(
                  builder: (context) => Scaffold(
                    appBar: appPageBar(
                      context,
                      leading: const BackButton(),
                      title: const Text('Gestion des investissements'),
                      bottom: TabBar(
                        onTap: (index) => selected = index,
                        tabs: const [
                          Tab(text: 'Tous'),
                          Tab(text: 'Actions'),
                        ],
                      ),
                    ),
                    body: ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [
                        PageIntro(
                          title: 'Vue globale',
                          subtitle: 'Votre patrimoine.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final title = tester.getRect(
            find.text('Gestion des investissements'),
          );
          final tab = tester.getRect(find.text('Actions'));
          expect(title.bottom, lessThan(tab.top));
          final barStyle = tester
              .widget<AppBar>(find.byType(AppBar))
              .titleTextStyle!;
          final pageStyle = tester
              .widget<Text>(find.text('Vue globale'))
              .style!;
          expect(barStyle.fontSize, pageStyle.fontSize);
          expect(pageStyle.fontSize, 28);
          await tester.tap(find.text('Actions'));
          await tester.pumpAndSettle();
          expect(selected, 1);
        },
      );
    }
  }
}
