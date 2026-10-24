import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/lazy_page_stack.dart';

class _Probe extends StatefulWidget {
  final int index;
  final List<int> created, ticks;
  const _Probe(this.index, this.created, this.ticks);
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  int _count = 0;
  @override
  void initState() {
    super.initState();
    widget.created[widget.index]++;
    _animation =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() => widget.ticks[widget.index]++)
          ..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('Page ${widget.index}'),
      TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('Compteur $_count'),
      ),
      Hero(tag: 'shared-hero', child: Text('Héros ${widget.index}')),
    ],
  );
}

void main() {
  testWidgets('Retained destinations keep independent scroll positions', (
    tester,
  ) async {
    var selected = 0;
    late StateSetter update;
    final pages = [
      for (var page = 0; page < 2; page++)
        ListView(
          key: ValueKey(page),
          children: [
            for (var row = 0; row < 60; row++)
              SizedBox(height: 50, child: Text('$page/$row')),
          ],
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: LazyPageStack(index: selected, children: pages),
            );
          },
        ),
      ),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    double position() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    final firstPosition = position();
    expect(firstPosition, greaterThan(200));
    update(() => selected = 1);
    await tester.pumpAndSettle();
    expect(position(), 0);
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    update(() => selected = 0);
    await tester.pumpAndSettle();
    expect(position(), closeTo(firstPosition, .01));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Direct navigation skips intermediate pages, preserves state and suspends hidden tickers',
    (tester) async {
      var selected = 0;
      final created = List.filled(4, 0), ticks = List.filled(4, 0);
      late StateSetter update;
      final pages = [for (var i = 0; i < 4; i++) _Probe(i, created, ticks)];
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: LazyPageStack(index: selected, children: pages),
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(created, [1, 0, 0, 0]);
      update(() => selected = 3);
      await tester.pump();
      final firstTicks = ticks[0];
      await tester.pump(const Duration(milliseconds: 100));
      expect(created, [1, 0, 0, 1]);
      expect(ticks[0], firstTicks);
      expect(ticks[3], greaterThan(0));
      expect(find.text('Page 0'), findsNothing);
      expect(find.text('Page 3'), findsOneWidget);
      final enabledHeroes = tester
          .widgetList<HeroMode>(
            find.descendant(
              of: find.byType(LazyPageStack),
              matching: find.byType(HeroMode, skipOffstage: false),
              skipOffstage: false,
            ),
          )
          .where((hero) => hero.enabled);
      expect(enabledHeroes.length, 1);
      await tester.tap(find.text('Compteur 0'));
      await tester.pump();
      update(() => selected = 0);
      await tester.pump();
      final hiddenTicks = ticks[3];
      await tester.pump(const Duration(milliseconds: 100));
      expect(ticks[3], hiddenTicks);
      update(() => selected = 3);
      await tester.pump();
      expect(created, [1, 0, 0, 1]);
      expect(find.text('Compteur 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
