import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/graphiques/chart_pointer_region.dart';

void main() {
  testWidgets(
    'Vertical scrolling stops chart selection; horizontal inspection remains available',
    (tester) async {
      final selections = <Offset>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ChartPointerRegion(
                  onSelect: selections.add,
                  child: const SizedBox(height: 450),
                ),
                const SizedBox(height: 1400),
              ],
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(const Offset(200, 350));
      await tester.pump();
      expect(selections.length, 1);
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      expect(selections.length, 1);
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(0),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
      await tester.pumpAndSettle();
      final horizontal = await tester.startGesture(const Offset(60, 200));
      await horizontal.moveBy(const Offset(80, 0));
      await tester.pump();
      expect(selections.length, greaterThan(2));
      await horizontal.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
