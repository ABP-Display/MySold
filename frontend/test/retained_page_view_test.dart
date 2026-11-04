import 'dart:async';
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
    'Startup prepares destinations once and restores the initial page',
    (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      final created = [0, 0, 0, 0];
      final ready = List.generate(4, (_) => Completer<void>());
      var prepared = 0;
      final navigation = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetainedPageView(
              controller: controller,
              onPageChanged: navigation.add,
              readiness: ready.map((entry) => entry.future).toList(),
              onPrepared: () => prepared++,
              children: [for (var i = 0; i < 4; i++) _Page(i, created, () {})],
            ),
          ),
        ),
      );
      for (var index = 0; index < 4; index++) {
        await tester.pumpAndSettle();
        expect(controller.page, index.toDouble());
        expect(created[index], 1);
        expect(prepared, 0);
        ready[index].complete();
      }
      await tester.pumpAndSettle();
      expect(prepared, 1);
      expect(controller.page, 0);
      expect(navigation, isEmpty);
      expect(created, [1, 1, 1, 1]);
      controller.animateToPage(
        3,
        duration: const Duration(milliseconds: 260),
        curve: Curves.linear,
      );
      await tester.pumpAndSettle();
      expect(navigation, [1, 2, 3]);
      expect(created, [1, 1, 1, 1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Startup continues after a data error without an animation ticker',
    (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      final ready = [Completer<void>(), Completer<void>()];
      var prepared = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetainedPageView(
              controller: controller,
              onPageChanged: (_) {},
              readiness: ready.map((entry) => entry.future).toList(),
              onPrepared: () => prepared++,
              children: const [SizedBox(), SizedBox()],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ready[1].completeError(StateError('Fixture early failure'));
      await tester.pump();
      ready[0].completeError(StateError('Fixture load failure'));
      await tester.pumpAndSettle();
      expect(prepared, 1);
      expect(controller.page, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Disposing during startup cancels remaining navigation', (
    tester,
  ) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    final ready = [Completer<void>(), Completer<void>()];
    final created = [0, 0];
    var prepared = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetainedPageView(
            controller: controller,
            onPageChanged: (_) {},
            readiness: ready.map((entry) => entry.future).toList(),
            onPrepared: () => prepared++,
            children: [for (var i = 0; i < 2; i++) _Page(i, created, () {})],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    ready[0].complete();
    await tester.pumpAndSettle();
    expect(created, [1, 0]);
    expect(prepared, 0);
    expect(tester.takeException(), isNull);
  });

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
