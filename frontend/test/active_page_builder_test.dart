import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mysold/widgets/active_page_builder.dart';
import 'package:mysold/widgets/lazy_page_stack.dart';

void main() {
  testWidgets(
    'Hidden provider changes defer data work until activation without losing state',
    (tester) async {
      final revision = ValueNotifier(0), builds = [0, 0];
      var selected = 0;
      late StateSetter update;
      final pages = [
        for (var i = 0; i < 2; i++)
          ActivePageBuilder(
            builder: (context) {
              final value = context.watch<ValueNotifier<int>>().value;
              builds[i]++;
              return Text('Page $i revision $value');
            },
          ),
      ];
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: revision,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return Scaffold(
                  body: LazyPageStack(index: selected, children: pages),
                );
              },
            ),
          ),
        ),
      );
      update(() => selected = 1);
      await tester.pump();
      final hiddenBuilds = builds[0];
      revision.value = 1;
      await tester.pump();
      expect(builds[0], hiddenBuilds);
      expect(find.text('Page 1 revision 1'), findsOneWidget);
      update(() => selected = 0);
      await tester.pump();
      expect(find.text('Page 0 revision 1'), findsOneWidget);
      expect(find.text('Page 0 revision 0'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      revision.dispose();
    },
  );
}
