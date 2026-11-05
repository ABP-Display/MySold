import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/app_workspace.dart';
import 'package:mysold/widgets/app_typography.dart';
import 'package:mysold/widgets/app_choice_tabs.dart';
import 'package:mysold/widgets/app_design.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Floating menu keeps an opaque theme surface in $brightness', (
      tester,
    ) async {
      final theme = ThemeData(brightness: brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            backgroundColor: Colors.red,
            body: Center(
              child: AppMenuSurface(
                key: const ValueKey('opaque-menu'),
                floating: true,
                child: const SizedBox(width: 300, height: 80),
              ),
            ),
          ),
        ),
      );
      final background =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byKey(const ValueKey('opaque-menu')),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(background.color, theme.colorScheme.surface);
      expect(background.color!.a, 1);
    });
  }

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
      final pageBounds = tester.getRect(
        find.byKey(const ValueKey('page-content')),
      );
      update(() => hidden = true);
      await tester.pumpAndSettle();
      if (mobile) {
        final tab = find.byKey(const ValueKey('privacy-reveal-tab'));
        expect(tab, findsOneWidget);
        final rect = tester.getRect(tab);
        expect(rect.top, 24);
        expect(rect.height, 44);
        expect(rect.center.dx, width / 2);
        expect(
          tester.getRect(find.byKey(const ValueKey('page-content'))),
          pageBounds,
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('page-content'))).dy,
          24,
        );
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pumpAndSettle();
        expect(hidden, false);
        expect(tab, findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final inset in [0.0, 34.0]) {
    testWidgets('Footer gaps pass taps and drags to tiles with inset $inset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final tapped = <int>[];
      var navigations = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: EdgeInsets.only(bottom: inset)),
            child: child!,
          ),
          home: AppWorkspace(
            selectedIndex: 0,
            destinations: const [
              WorkspaceDestination('Mois', Icons.calendar_month),
              WorkspaceDestination('Stats', Icons.query_stats),
              WorkspaceDestination('Annuel', Icons.dashboard),
              WorkspaceDestination('Profil', Icons.person),
            ],
            hidden: false,
            onPrivacy: () {},
            onSelected: (_) => navigations++,
            child: Builder(
              builder: (context) => ListView.builder(
                controller: scroll,
                padding: EdgeInsets.only(
                  bottom: WorkspaceOverlayInsets.bottomOf(context),
                ),
                itemCount: 40,
                itemBuilder: (_, index) => SizedBox(
                  height: 52,
                  child: TextButton(
                    key: ValueKey('fixture-tile-$index'),
                    onPressed: () => tapped.add(index),
                    child: Text('Tile $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester.getRect(
        find.byKey(const ValueKey('bottom-navigation-surface')),
      );
      await tester.tapAt(Offset(4, surface.center.dy));
      await tester.pump();
      expect(tapped, hasLength(1));
      await tester.tapAt(Offset(surface.center.dx, surface.top - 2));
      await tester.pump();
      expect(tapped, hasLength(2));
      await tester.tap(find.byKey(const ValueKey('destination-3')));
      await tester.pump();
      expect(navigations, 1);
      expect(tapped, hasLength(2));
      await tester.dragFrom(
        Offset(4, surface.center.dy),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(80));
      expect(tapped, hasLength(2));
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final last = find.byKey(const ValueKey('fixture-tile-39'));
      expect(tester.getRect(last).bottom, lessThanOrEqualTo(surface.top));
      await tester.tap(last);
      expect(tapped.last, 39);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Only space outside the opaque menu passes through to a tile', (
    tester,
  ) async {
    var tileTaps = 0, selections = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tileTaps++,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 120,
                child: AppMenuSurface(
                  key: const ValueKey('floating-test-menu'),
                  floating: true,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: AppChoiceTabs(
                      floating: true,
                      selectedIndex: 0,
                      onSelected: (_) => selections++,
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
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final rect = tester.getRect(
      find.byKey(const ValueKey('floating-test-menu')),
    );
    await tester.tapAt(Offset(rect.center.dx, rect.top - 2));
    expect(tileTaps, 1);
    expect(selections, 0);
    await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
    expect(tileTaps, 1);
    await tester.tap(find.byKey(const ValueKey('operation-type-1')));
    expect(selections, 1);
    expect(tileTaps, 1);
  });

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
