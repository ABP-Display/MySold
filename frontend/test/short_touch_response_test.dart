import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/graphiques/chart_pointer_region.dart';

void main() {
  testWidgets(
    'Touch down and vertical moves perform no chart selection; a released tap selects',
    (tester) async {
      final selections = <Offset>[];
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: scroll,
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
