import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/widgets/app_page_transitions.dart';
import 'package:mysold/widgets/graphiques/app_charts.dart';
import 'package:mysold/widgets/graphiques/chart_info_region.dart';

class _PaintProbe extends CustomPainter {
  final VoidCallback onPaint;
  _PaintProbe(this.onPaint);
  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(_PaintProbe oldDelegate) => false;
}

void main() {
  testWidgets(
    'Sliding chart information does not repaint the underlying graph',
    (tester) async {
      var paints = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: ChartInfoRegion(
                resolve: (position, _) =>
                    ChartInfo('Jour ${position.dx.floor()}', '42 €'),
                child: CustomPaint(painter: _PaintProbe(() => paints++)),
              ),
            ),
          ),
        ),
      );
      final initialPaints = paints;
      final finger = await tester.startGesture(const Offset(30, 150));
      await tester.pumpAndSettle();
      for (var x = 40.0; x < 340; x += 40) {
        await finger.moveTo(Offset(x, 150));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('chart-info-card')), findsOneWidget);
      }
      expect(paints, initialPaints);
      await finger.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chart-info-card')), findsNothing);
      expect(paints, initialPaints);
    },
  );

  testWidgets(
    'Changing chart values reaches the new data without interpolation frames',
    (tester) async {
      var value = 10.0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Row(
                  children: [
                    Expanded(
                      child: AppLineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: [const FlSpot(0, 0), FlSpot(1, value)],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: AppBarChart(
                        BarChartData(
                          barGroups: [
                            BarChartGroupData(
                              x: 0,
                              barRods: [BarChartRodData(toY: value)],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: AppPieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(value: value),
                            PieChartSectionData(value: 5),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      update(() => value = 25);
      await tester.pump();
      // A zero-duration implicit animation completes on the next frame.
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .single
            .spots
            .last
            .y,
        25,
      );
      expect(
        tester
            .widget<BarChart>(find.byType(BarChart))
            .data
            .barGroups
            .single
            .barRods
            .single
            .toY,
        25,
      );
      expect(
        tester
            .widget<PieChart>(find.byType(PieChart))
            .data
            .sections
            .first
            .value,
        25,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pushing a Web route keeps it at full size and opacity during transition',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(pageTransitionsTheme: AppPageTransitions.theme),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: SizedBox.expand(key: ValueKey('destination')),
                  ),
                ),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final destination = find.byKey(const ValueKey('destination'));
      expect(tester.getRect(destination), const Rect.fromLTWH(0, 0, 800, 600));
      expect(
        find.ancestor(of: destination, matching: find.byType(FadeTransition)),
        findsNothing,
      );
      expect(
        find.ancestor(of: destination, matching: find.byType(ScaleTransition)),
        findsNothing,
      );
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
