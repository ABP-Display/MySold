import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/scroll_item_retention.dart';

class _Row extends StatefulWidget {
  final int index;
  final List<int> created, alive;
  const _Row(this.index, this.created, this.alive);
  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  @override
  void initState() {
    super.initState();
    widget.created[widget.index]++;
    widget.alive[widget.index]++;
  }

  @override
  void dispose() {
    widget.alive[widget.index]--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 100, child: Text('Row ${widget.index}'));
}

void main() {
  testWidgets(
    'Nearby rows reuse their render tree; long scrolling evicts old rows',
    (tester) async {
      final created = List.filled(300, 0), alive = List.filled(300, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScrollItemRetention(
              capacity: 16,
              child: ListView.builder(
                itemExtent: 100,
                itemCount: 300,
                itemBuilder: (_, i) => RetainedScrollItem(
                  key: ValueKey(i),
                  child: _Row(i, created, alive),
                ),
              ),
            ),
          ),
        ),
      );
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      position.jumpTo(450);
      await tester.pumpAndSettle();
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(created[0], 1);
      for (var offset = 1000.0; offset < 12000; offset += 600) {
        position.jumpTo(offset);
        await tester.pumpAndSettle();
        // Retained rows plus the currently laid-out viewport/cache extent.
        expect(alive.fold<int>(0, (a, b) => a + b), lessThanOrEqualTo(29));
      }
      expect(alive[0], 0);
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(created[0], 2);
      expect(tester.takeException(), isNull);
    },
  );
}
