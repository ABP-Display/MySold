import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/app_page_tab_menu.dart';
import 'package:mysold/widgets/app_selection_button.dart';

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final labels in [
        ['Dépenses', 'Revenus'],
        ['Budget', 'Investissement', 'Prêt'],
        ['Tous', 'Actions', 'ETF', 'Crypto', 'Obligations', 'Autres'],
      ]) {
        testWidgets('Bottom menu ${labels.length}: $width/$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selected = 0, underlyingTaps = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppThemes.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  extendBody: true,
                  body: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => underlyingTaps++,
                    child: const SizedBox.expand(),
                  ),
                  bottomNavigationBar: AppPageTabMenu(
                    keyPrefix: 'test',
                    labels: labels,
                    icons: [for (final _ in labels) Icons.category_outlined],
                    selectedIndex: selected,
                    scrollable: labels.length > 3,
                    onSelected: (value) => setState(() => selected = value),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final menu = tester.getRect(find.byType(AppMenuSurface));
          expect(menu.top, greaterThan(650));
          expect(menu.bottom, lessThanOrEqualTo(888));
          final surface = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(AppMenuSurface),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          expect((surface.decoration as BoxDecoration).color!.a, 1);
          // The transparent gutter remains interactive, unlike the menu itself.
          await tester.tapAt(Offset(2, menu.center.dy));
          expect(underlyingTaps, 1);
          for (var i = 0; i < labels.length; i++) {
            final target = find.byKey(ValueKey('test-tab-$i'));
            await tester.ensureVisible(target);
            await tester.tap(target);
            await tester.pump();
            expect(selected, i);
            expect(tester.widget<AppSelectionButton>(target).selected, isTrue);
            expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
          }
          expect(underlyingTaps, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
