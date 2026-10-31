import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/lazy_page_stack.dart';

void main() {
  testWidgets(
    'Single-subscription query streams remain subscribed across tab returns',
    (tester) async {
      var index = 0;
      final listens = [0, 0], cancels = [0, 0];
      final streams = [
        for (var i = 0; i < 2; i++)
          StreamController<int>(
            onListen: () => listens[i]++,
            onCancel: () => cancels[i]++,
          ),
      ];
      addTearDown(() async {
        for (final stream in streams) await stream.close();
      });
      final pages = [
        for (var i = 0; i < 2; i++)
          StreamBuilder<int>(
            stream: streams[i].stream,
            builder: (_, snapshot) =>
                Text('Tab $i total ${snapshot.data ?? 0}'),
          ),
      ];
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return Scaffold(
                body: LazyPageStack(index: index, children: pages),
              );
            },
          ),
        ),
      );
      streams[0].add(10);
      await tester.pump();
      await tester.pump();
      expect(find.text('Tab 0 total 10'), findsOneWidget);
      for (var cycle = 0; cycle < 4; cycle++) {
        update(() => index = 1);
        await tester.pump();
        streams[1].add(20 + cycle);
        streams[0].add(30 + cycle);
        await tester.pump();
        await tester.pump();
        expect(find.text('Tab 1 total ${20 + cycle}'), findsOneWidget);
        update(() => index = 0);
        await tester.pump();
        expect(find.text('Tab 0 total ${30 + cycle}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(listens, [1, 1]);
      expect(cancels, [0, 0]);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
