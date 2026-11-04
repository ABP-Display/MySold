import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/retained_page_view.dart';

class _Page extends StatefulWidget {
  final int index;
  final List<int> created;
  final VoidCallback onTap;
  const _Page(this.index, this.created, this.onTap);
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    widget.created[widget.index]++;
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (var i = 0; i < 40; i++)
        SizedBox(
          height: 70,
          child: TextButton(
            onPressed: widget.onTap,
            child: Text('Page ${widget.index} ligne $i'),
          ),
        ),
    ],
  );
}

void main() {
  testWidgets(
    'Only navigation buttons change pages; vertical scroll and page state survive',
    (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      final created = [0, 0];
      var selected = 0, taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetainedPageView(
              controller: controller,
              onPageChanged: (index) => selected = index,
              children: [
                for (var i = 0; i < 2; i++) _Page(i, created, () => taps++),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('Page 0 ligne 0'), const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(taps, 0);
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(_Page).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      final offset = position.pixels;
      expect(offset, greaterThan(100));
      await tester.dragFrom(const Offset(650, 160), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(controller.page, 0);
      expect(created, [1, 0]);
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(650, 160),
          scrollDelta: Offset(600, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.page, 0);
      final trackpad = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await trackpad.panZoomStart(const Offset(650, 160));
      await trackpad.panZoomUpdate(
        const Offset(650, 160),
        pan: const Offset(-400, 0),
      );
      await trackpad.panZoomEnd();
      await tester.pumpAndSettle();
      expect(controller.page, 0);
      controller.animateToPage(
        1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(taps, 0);
      controller.animateToPage(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(created, [1, 1]);
      expect(position.pixels, closeTo(offset, .01));
      expect(tester.takeException(), isNull);
    },
  );
}
