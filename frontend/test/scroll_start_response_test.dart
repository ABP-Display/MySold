import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/app_selection_button.dart';
import 'package:mysold/widgets/graphiques/chart_pointer_region.dart';
import 'package:mysold/widgets/lazy_section_list.dart';
import 'package:mysold/widgets/web_scroll_scope.dart';

void main() {
  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    for (final width in [390.0, 1280.0]) {
      for (final target in ['button', 'selection', 'operation', 'chart']) {
        testWidgets(
          'The first short drag over $target moves the page on $platform at $width without a tap',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var taps = 0;
            final child = switch (target) {
              'button' => IconButton(
                tooltip: 'Action',
                onPressed: () => taps++,
                icon: const Icon(Icons.tune),
              ),
              'selection' => AppSelectionButton(
                selected: false,
                onPressed: () => taps++,
                child: const Text('Choisir'),
              ),
              'operation' => AppOperationCard(
                title: 'Opération',
                subtitle: 'Compte courant',
                amount: '42 €',
                icon: Icons.payments,
                color: Colors.green,
                onTap: () => taps++,
              ),
              _ => ChartPointerRegion(
                onSelect: (_) => taps++,
                child: const SizedBox(
                  width: double.infinity,
                  height: 240,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            };
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                builder: (context, child) => WebScrollScope(child: child!),
                home: Scaffold(
                  body: LazySectionList(
                    sections: [
                      (_) => const SizedBox(height: 300),
                      (_) => SizedBox(
                        key: const ValueKey('target'),
                        height: 260,
                        child: Center(child: child),
                      ),
                      (_) => const SizedBox(height: 1800),
                    ],
                    gaps: const [0, 0],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final position = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            position.jumpTo(150);
            await tester.pumpAndSettle();
            final finger = await tester.startGesture(
              tester.getCenter(find.byKey(const ValueKey('target'))),
            );
            await tester.pump(const Duration(milliseconds: 30));
            await finger.moveBy(const Offset(1, -12));
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              position.pixels,
              greaterThan(150),
              reason:
                  'Do not discard the first movement while resolving a tap.',
            );
            expect(taps, 0);
            await finger.up();
            await tester.pumpAndSettle();
            expect(taps, 0);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'A fast mostly vertical first chart movement scrolls rather than inspecting',
    (tester) async {
      var selections = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => WebScrollScope(child: child!),
          home: Scaffold(
            body: LazySectionList(
              gaps: const [0, 0],
              sections: [
                (_) => const SizedBox(height: 300),
                (_) => ChartPointerRegion(
                  onSelect: (_) => selections++,
                  child: const SizedBox(
                    key: ValueKey('fast-chart'),
                    height: 260,
                  ),
                ),
                (_) => const SizedBox(height: 1800),
              ],
            ),
          ),
        ),
      );
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(150);
      await tester.pumpAndSettle();
      final finger = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('fast-chart'))),
      );
      await finger.moveBy(const Offset(12, -24));
      await tester.pump(const Duration(milliseconds: 16));
      expect(position.pixels, greaterThan(150));
      expect(selections, 0);
      await finger.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Short finger jitter remains a released tap, not an early action',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => WebScrollScope(child: child!),
          home: Scaffold(
            body: LazySectionList(
              sections: [
                (_) => SizedBox(
                  height: 260,
                  child: Center(
                    child: AppSelectionButton(
                      selected: false,
                      onPressed: () => taps++,
                      child: const Text('Choisir'),
                    ),
                  ),
                ),
                (_) => const SizedBox(height: 1800),
              ],
              gaps: const [0],
            ),
          ),
        ),
      );
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final finger = await tester.startGesture(
        tester.getCenter(find.text('Choisir')),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await finger.moveBy(const Offset(1, -3));
      await tester.pump(const Duration(milliseconds: 16));
      expect(taps, 0);
      expect(position.pixels, 0);
      await finger.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
    },
  );

  testWidgets(
    'Mouse wheel over a clickable surface still scrolls without clicking',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => WebScrollScope(child: child!),
          home: Scaffold(
            body: LazySectionList(
              sections: [
                (_) => SizedBox(
                  height: 260,
                  child: Center(
                    child: IconButton(
                      tooltip: 'Action',
                      onPressed: () => taps++,
                      icon: const Icon(Icons.tune),
                    ),
                  ),
                ),
                (_) => const SizedBox(height: 1800),
              ],
              gaps: const [0],
            ),
          ),
        ),
      );
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(IconButton)),
          scrollDelta: const Offset(0, 80),
        ),
      );
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.pixels, 80);
      expect(taps, 0);
    },
  );

  for (final deviceSlop in [null, 4.0, 24.0]) {
    testWidgets(
      'Web fallback respects a supplied device tolerance: $deviceSlop',
      (tester) async {
        DeviceGestureSettings? actual;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                gestureSettings: DeviceGestureSettings(touchSlop: deviceSlop),
              ),
              child: WebScrollScope(child: child!),
            ),
            home: Builder(
              builder: (context) {
                actual = MediaQuery.gestureSettingsOf(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(actual!.touchSlop, deviceSlop ?? 8);
      },
    );
  }
}
