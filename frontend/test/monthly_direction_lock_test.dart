import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/analytics/monthly_analysis_chart.dart';
import 'package:mysold/widgets/app_touch_policy.dart';
import 'package:mysold/widgets/lazy_section_list.dart';
import 'monthly_analytics_test.dart' show comparisonFixture;

void main() {
  testWidgets(
    'Monthly chart keeps a mostly horizontal finger drag despite vertical drift and redraws',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppTouchPolicy(child: child!),
          home: Scaffold(
            body: LazySectionList(
              gaps: const [16],
              sections: [
                (_) => MonthlyAnalysisChart(
                  data: comparisonFixture(),
                  currency: '€',
                  hidden: false,
                ),
                (_) => const SizedBox(height: 1400),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final plot = find.byKey(const ValueKey('monthly-analysis-plot'));
      await tester.ensureVisible(plot);
      await tester.pumpAndSettle();
      final rect = tester.getRect(plot),
          position = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
      final original = position.pixels;
      String day() => tester
          .widget<Text>(
            find.byKey(const ValueKey('monthly-analysis-selected-day')),
          )
          .data!;
      final days = <String>{};
      var finger = await tester.startGesture(
        Offset(rect.left + 52, rect.top + 80),
      );
      for (var step = 1; step <= 10; step++) {
        await finger.moveBy(const Offset(21, 3));
        await tester.pump(const Duration(milliseconds: 16));
        days.add(day());
      }
      expect(days.length, greaterThanOrEqualTo(8));
      expect(position.pixels, closeTo(original, .1));
      await finger.up();
      await tester.pumpAndSettle();
      final selected = day();
      final current = tester.getRect(plot);
      finger = await tester.startGesture(
        Offset(current.center.dx, current.top + 160),
      );
      for (var step = 0; step < 6; step++) {
        await finger.moveBy(const Offset(2, -12));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(position.pixels, greaterThan(original + 30));
      expect(day(), selected);
      await finger.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
