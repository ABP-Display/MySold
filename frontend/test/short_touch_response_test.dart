import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/app_touch_policy.dart';
import 'package:mysold/widgets/app_selection_button.dart';
import 'package:mysold/widgets/graphiques/chart_pointer_region.dart';

void main() {
  testWidgets(
    'A short 9px movement starts scrolling over a button; a 3px tap still activates once',
    (tester) async {
      var taps = 0;
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      Future<void> mount(bool responsive) => tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final content = Scaffold(
                body: ListView(
                  controller: scroll,
                  dragStartBehavior: responsive
                      ? DragStartBehavior.down
                      : DragStartBehavior.start,
                  children: [
                    SizedBox(
                      height: 200,
                      child: AppSelectionButton(
                        onPressed: () => taps++,
                        selected: false,
                        child: const Text('Action'),
                      ),
                    ),
                    const SizedBox(height: 1600),
                  ],
                ),
              );
              return responsive ? AppTouchPolicy(child: content) : content;
            },
          ),
        ),
      );
      await mount(false);
      await tester.pumpAndSettle();
      var finger = await tester.startGesture(const Offset(150, 150));
      await tester.pump(const Duration(milliseconds: 30));
      await finger.moveBy(const Offset(0, -9));
      await tester.pump();
      expect(scroll.offset, 0);
      await finger.cancel();
      await tester.pumpAndSettle();
      await mount(true);
      await tester.pumpAndSettle();
      finger = await tester.startGesture(const Offset(150, 150));
      await tester.pump(const Duration(milliseconds: 30));
      await finger.moveBy(const Offset(0, -9));
      await tester.pump();
      expect(scroll.offset, greaterThan(0));
      await finger.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      finger = await tester.startGesture(const Offset(150, 150));
      await finger.moveBy(const Offset(1, -3));
      await finger.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Touch down and vertical moves perform no chart selection; a released tap selects',
    (tester) async {
      final selections = <Offset>[];
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppTouchPolicy(child: child!),
          home: Scaffold(
            body: ListView(
              controller: scroll,
              dragStartBehavior: DragStartBehavior.down,
              children: [
                ChartPointerRegion(
                  onSelect: selections.add,
                  child: const SizedBox(height: 300),
                ),
                const SizedBox(height: 1400),
              ],
            ),
          ),
        ),
      );
      var finger = await tester.startGesture(const Offset(150, 200));
      await tester.pump(const Duration(milliseconds: 30));
      expect(selections, isEmpty);
      for (var i = 0; i < 8; i++) {
        await finger.moveBy(const Offset(1, -6));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await finger.up();
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
      expect(scroll.offset, greaterThan(20));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      finger = await tester.startGesture(const Offset(150, 200));
      await tester.pump();
      expect(selections, isEmpty);
      await finger.up();
      await tester.pump();
      expect(selections, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
