import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/app_loading_screen.dart';
import 'package:mysold/widgets/app_workspace.dart';
import 'package:mysold/widgets/lazy_section_list.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Loader stays black and supports reduced motion in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: const AppLoadingScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          Colors.black,
        );
        expect(find.byType(Image), findsOneWidget);
        expect(tester.hasRunningAnimations, false);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final inset in [0.0, 34.0]) {
    testWidgets('Mobile menu centers content and keeps gesture inset $inset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(bottom: inset),
              viewPadding: EdgeInsets.only(bottom: inset),
            ),
            child: child!,
          ),
          home: AppWorkspace(
            selectedIndex: 0,
            onSelected: (_) {},
            onPrivacy: () {},
            hidden: false,
            destinations: const [
              WorkspaceDestination('Mois', Icons.calendar_month),
              WorkspaceDestination('Stats mensuelles', Icons.query_stats),
              WorkspaceDestination('Stats annuelles', Icons.dashboard),
              WorkspaceDestination('Profil', Icons.person),
            ],
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = tester.getRect(
        find.byKey(const ValueKey('bottom-navigation')),
      );
      final content = tester.getRect(
        find.byKey(const ValueKey('bottom-navigation-content')),
      );
      final surface = tester.getRect(
        find.byKey(const ValueKey('bottom-navigation-surface')),
      );
      expect(content.top - surface.top, closeTo(6, 1));
      expect(surface.bottom - content.bottom, closeTo(6, 1));
      expect(bar.bottom - surface.bottom, closeTo(12 + inset, 1));
      expect(surface.left, 12);
      expect(surface.right, 378);
      final sizes = [
        for (var i = 0; i < 4; i++)
          tester.getSize(find.byKey(ValueKey('destination-$i'))),
      ];
      expect(sizes.map((s) => s.height).toSet(), hasLength(1));
      for (var i = 0; i < 4; i++) {
        final button = find.byKey(ValueKey('destination-$i'));
        final rect = tester.getRect(button);
        final icon = tester.getRect(
          find.descendant(of: button, matching: find.byType(Icon)).first,
        );
        final label = tester.getRect(
          find.descendant(of: button, matching: find.byType(Text)).first,
        );
        expect(icon.top - rect.top, closeTo(rect.bottom - label.bottom, 1));
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Visited lazy sections keep their state when scrolled out and back',
    (tester) async {
      final created = List.filled(6, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LazySectionList(
              gaps: List.filled(5, 16),
              sections: [
                for (var i = 0; i < 6; i++) (_) => _Section(i, created),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(created[5], 0);
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      scroll.jumpTo(2100);
      await tester.pumpAndSettle();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(created[0], 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Section extends StatefulWidget {
  final int index;
  final List<int> created;
  const _Section(this.index, this.created);
  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  @override
  void initState() {
    super.initState();
    widget.created[widget.index]++;
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 650, child: Text('Section ${widget.index}'));
}
