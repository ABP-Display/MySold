import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/app_workspace.dart';
import 'package:mysold/widgets/app_typography.dart';
import 'package:mysold/widgets/app_choice_tabs.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('Workspace header and privacy reveal at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var hidden = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(top: 24)),
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return AppWorkspace(
                selectedIndex: 0,
                destinations: const [
                  WorkspaceDestination('Mois', Icons.calendar_month),
                  WorkspaceDestination('Statistiques', Icons.query_stats),
                  WorkspaceDestination('Annuel', Icons.dashboard),
                  WorkspaceDestination('Profil', Icons.person),
                ],
                hidden: hidden,
                onPrivacy: () => setState(() => hidden = !hidden),
                onSelected: (_) {},
                child: const SizedBox.expand(key: ValueKey('page-content')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mobile = width < 760;
      expect(
        find.byKey(const ValueKey('workspace-header')),
        mobile ? findsNothing : findsOneWidget,
      );
      expect(find.byKey(const ValueKey('privacy-reveal-tab')), findsNothing);
      if (mobile)
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('page-content'))).dy,
          24,
        );
      update(() => hidden = true);
      await tester.pumpAndSettle();
      if (mobile) {
        final tab = find.byKey(const ValueKey('privacy-reveal-tab'));
        expect(tab, findsOneWidget);
        final rect = tester.getRect(tab);
        expect(rect.top, 24);
        expect(rect.height, 44);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('page-content'))).dy,
          greaterThanOrEqualTo(rect.bottom),
        );
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pumpAndSettle();
        expect(hidden, false);
        expect(tab, findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Reading size respects system scale $scale at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        double? size;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Builder(
                builder: (context) => AppTypography.readable(context, child!),
              ),
            ),
            home: Builder(
              builder: (context) {
                size = MediaQuery.textScalerOf(context).scale(13);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(
          size,
          closeTo(13 * (width < 760 && scale == 1 ? 1.15 : scale), .001),
        );
      });
    }
  }

  for (final width in [296.0, 366.0]) {
    for (final scale in [1.15, 2.0, 3.0]) {
      testWidgets(
        'All four floating operation buttons fit at $width / $scale',
        (tester) async {
          var selected = 0;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: AppChoiceTabs(
                      floating: true,
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
                      selectedIndex: selected,
                      onSelected: (index) => selected = index,
                    ),
                  ),
                ),
              ),
            ),
          );
          final buttons = [
            for (var index = 0; index < 4; index++)
              tester.getRect(find.byKey(ValueKey('operation-type-$index'))),
          ];
          expect(buttons.map((rect) => rect.width).toSet(), hasLength(1));
          for (var index = 1; index < 4; index++)
            expect(buttons[index].left, buttons[index - 1].right);
          await tester.tap(find.byKey(const ValueKey('operation-type-3')));
          expect(selected, 3);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
