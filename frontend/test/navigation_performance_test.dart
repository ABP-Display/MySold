import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/app_choice_tabs.dart';
import 'package:mysold/widgets/app_workspace.dart';
import 'package:mysold/widgets/lazy_section_list.dart';
import 'package:mysold/widgets/page_activity_listener.dart';

void main() {
  testWidgets('Resuming a retained page does not rebuild its content', (
    tester,
  ) async {
    var active = true, resumes = 0, builds = 0;
    late StateSetter update;
    final page = PageActivityListener(
      onResume: () => resumes++,
      child: Builder(
        builder: (_) {
          builds++;
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return TickerMode(enabled: active, child: page);
          },
        ),
      ),
    );
    expect(resumes, 1);
    update(() => active = false);
    await tester.pump();
    update(() => active = true);
    await tester.pump();
    expect(resumes, 2);
    expect(builds, 1);
  });

  testWidgets('Offscreen sections are constructed only when needed', (
    tester,
  ) async {
    final built = <int>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LazySectionList(
            sections: List.generate(
              8,
              (index) => (_) {
                built.add(index);
                return SizedBox(height: 500, child: Text('Section $index'));
              },
            ),
            gaps: List.filled(7, 16),
          ),
        ),
      ),
    );
    expect(built, contains(0));
    expect(built, isNot(contains(7)));
    await tester.scrollUntilVisible(find.text('Section 7'), 500);
    expect(built, contains(7));
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1200.0]) {
    testWidgets('Navigation selects immediately at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) => AppWorkspace(
              selectedIndex: selected,
              destinations: const [
                WorkspaceDestination('Mois', Icons.calendar_month),
                WorkspaceDestination('Stats', Icons.bar_chart),
                WorkspaceDestination('Profil', Icons.person),
              ],
              onSelected: (index) => setState(() => selected = index),
              onPrivacy: () {},
              hidden: false,
              child: Text('Contenu $selected'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Contenu 2'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Operation tabs support pointer and keyboard without animation', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) => AppChoiceTabs(
              labels: const ['Dépenses', 'Revenus'],
              icons: const [Icons.money_off, Icons.attach_money],
              selectedIndex: selected,
              onSelected: (index) => setState(() => selected = index),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Revenus'));
    await tester.pump();
    await tester.pump();
    expect(selected, 1);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, 0);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });
}
