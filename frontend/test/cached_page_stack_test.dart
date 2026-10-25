import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/cached_page_stack.dart';

void main() {
  testWidgets(
    'Revisiting a tab reuses content; changed inputs refresh before display',
    (tester) async {
      var index = 0, revision = 0;
      final builds = [0, 0, 0];
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return Scaffold(
                body: CachedPageStack(
                  index: index,
                  itemCount: 3,
                  revision: revision,
                  itemBuilder: (_, page) {
                    builds[page]++;
                    return ListView(
                      key: ValueKey(page),
                      children: [
                        Text('Page $page revision $revision'),
                        for (var row = 0; row < 50; row++)
                          SizedBox(height: 50, child: Text('Row $page/$row')),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      final element = tester.element(find.byType(ListView));
      double position() => tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      final offset = position();
      update(() => index = 1);
      await tester.pump();
      update(() => index = 0);
      await tester.pump();
      expect(builds, [1, 1, 0]);
      expect(tester.element(find.byType(ListView)), same(element));
      expect(position(), closeTo(offset, .01));
      update(() => revision++);
      await tester.pump();
      expect(builds, [2, 1, 0]);
      expect(tester.element(find.byType(ListView)), same(element));
      update(() => index = 1);
      await tester.pump();
      expect(builds, [2, 2, 0]);
      expect(find.text('Page 1 revision 1'), findsOneWidget);
      expect(find.text('Page 1 revision 0'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
