import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/month_operation_charts.dart';
import 'package:mysold/models/investment_type.dart';
import 'app_charts.dart';

Color investmentSectionColor(String type) => switch (type) {
  'stock' => const Color(0xffc5a3da),
  'etf' => const Color(0xff8daee0),
  'crypto' => const Color(0xffd5b778),
  'bond' => const Color(0xff77b8ae),
  _ => const Color(0xff8a96a1),
};

class InvestmentSectionsChart extends StatefulWidget {
  final List<InvestmentSection> sections;
  final Widget Function(BuildContext, int) detailBuilder;
  final String Function(int) money;
  const InvestmentSectionsChart({
    super.key,
    required this.sections,
    required this.detailBuilder,
    required this.money,
  });
  @override
  State<InvestmentSectionsChart> createState() =>
      _InvestmentSectionsChartState();
}

class _InvestmentSectionsChartState extends State<InvestmentSectionsChart> {
  int? _selected;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_selected != null) {
      final index = _selected!, section = widget.sections[index];
      return Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('investment-sections-back'),
                tooltip: context.tr('Retour aux sections'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.arrow_back, size: 18),
              ),
              Expanded(
                child: Text(
                  '${section.firstDay}–${section.lastDay}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  widget.money(section.total),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Expanded(child: widget.detailBuilder(context, index)),
        ],
      );
    }
    final types = investmentChartTypes
        .where((t) => widget.sections.any((s) => (s.types[t] ?? 0) > 0))
        .toList();
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, bounds) {
              final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
              final left = 32.0 * scale, bottom = 28.0 * scale;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Stack(
                  children: [
                    AppBarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        minY: 0,
                        maxY: 100,
                        barTouchData: BarTouchData(enabled: false),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: 50,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: colors.outlineVariant.withValues(alpha: .5),
                            strokeWidth: .7,
                            dashArray: [3, 5],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: left,
                              interval: 50,
                              getTitlesWidget: (v, _) => Text(
                                '${v.toInt()} %',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: bottom,
                              interval: 1,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= 4 || v != i)
                                  return const SizedBox.shrink();
                                final section = widget.sections[i];
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(
                                    '${section.firstDay}–${section.lastDay}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < 4; i++)
                            () {
                              final section = widget.sections[i];
                              var from = 0.0;
                              final stacks = <BarChartRodStackItem>[];
                              for (final type in types) {
                                final cents = section.types[type] ?? 0;
                                if (cents == 0) continue;
                                final to = from + cents / section.total * 100;
                                stacks.add(
                                  BarChartRodStackItem(
                                    from,
                                    to,
                                    investmentSectionColor(type),
                                  ),
                                );
                                from = to;
                              }
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: section.total == 0 ? 0 : 100,
                                    rodStackItems: stacks,
                                    width: ((bounds.maxWidth - left) / 4 * .42)
                                        .clamp(12.0, 40.0),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                  ),
                                ],
                              );
                            }(),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      left: left,
                      bottom: bottom,
                      child: Row(
                        children: [
                          for (var i = 0; i < 4; i++)
                            Expanded(
                              child: Semantics(
                                identifier: 'investment-section-$i',
                                button: true,
                                label:
                                    '${widget.sections[i].firstDay}–${widget.sections[i].lastDay}, ${widget.money(widget.sections[i].total)}',
                                child: Tooltip(
                                  message:
                                      '${widget.sections[i].firstDay}–${widget.sections[i].lastDay} · ${widget.money(widget.sections[i].total)}',
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => setState(() => _selected = i),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final type in types)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: investmentSectionColor(type),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    context.tr(investmentTypeOption(type).label),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
