import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/month_chart_series.dart';
import 'package:mysold/models/month_operation_charts.dart';
import 'package:mysold/widgets/graphiques/investment_sections_chart.dart';
import 'package:mysold/widgets/graphiques/transfer_sankey_chart.dart';
import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/widgets/graphiques/app_charts.dart';
import 'package:mysold/widgets/graphiques/month_breakdown_chart.dart';
import 'package:mysold/widgets/graphiques/month_money_axis.dart';
import 'package:mysold/widgets/graphiques/chart_info_region.dart';
import 'package:mysold/widgets/graphiques/viewport_bar_chart.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';
import 'package:provider/provider.dart';

class MonthGraph extends StatefulWidget {
  final DateTime month;
  final List<TransactionModel> transactions;
  final Map<String, Map<String, dynamic>> categories;
  final Map<String, String> accountIds, investmentIds;
  final Map<String, String> investmentTypes;
  final String type;
  const MonthGraph({
    super.key,
    required this.month,
    required this.transactions,
    required this.categories,
    required this.accountIds,
    required this.investmentIds,
    required this.type,
    this.investmentTypes = const {},
  });
  @override
  State<MonthGraph> createState() => _MonthGraphState();
}

class _MonthGraphState extends State<MonthGraph> {
  static const _palette = [
    Color(0xff77b8ae),
    Color(0xff8daee0),
    Color(0xffc5a3da),
    Color(0xffd5b778),
    Color(0xffc98891),
    Color(0xff8a96a1),
  ];
  late MonthChartSeries _data;
  List<Object> _snapshot = const [];
  List<InvestmentSection> _sections = const [];
  List<TransferRoute> _routes = const [];
  final _expenseScroll = ScrollController();
  @override
  void dispose() {
    _expenseScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant MonthGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepare();
  }

  void _prepare() {
    final now = DateTime.now();
    final snapshot = <Object>[
      widget.type,
      widget.month.year,
      widget.month.month,
      now.year,
      now.month,
      now.day,
      for (final entry in widget.investmentTypes.entries)
        (entry.key, entry.value),
      for (final t in widget.transactions)
        (
          t.type,
          t.date,
          t.amount,
          t.categoryId,
          t.investmentId,
          t.fromAccountId,
          t.toAccountId,
        ),
    ];
    if (listEquals(snapshot, _snapshot)) return;
    _snapshot = snapshot;
    final current = widget.transactions.where(
      (t) =>
          t.type == widget.type &&
          t.date.year == widget.month.year &&
          t.date.month == widget.month.month &&
          t.amount.isFinite &&
          (t.amount.abs() * 100).round() > 0,
    );
    _data = MonthChartSeries.build(
      widget.month,
      current.map(
        (t) => MonthChartEntry(
          t.date,
          t.amount,
          widget.type == 'investment'
              ? t.investmentId
              : widget.type == 'transfer'
              ? t.toAccountId
              : t.categoryId,
        ),
      ),
      now: now,
    );
    if (widget.type == 'investment') {
      _sections = investmentSections(
        widget.month,
        current.map((t) => MonthChartEntry(t.date, t.amount, t.investmentId)),
        widget.investmentTypes,
      );
    }
    if (widget.type == 'transfer') {
      _routes = transferRoutes(
        widget.month,
        current.map(
          (t) => TransferChartEntry(
            t.investmentId ?? t.fromAccountId,
            t.toAccountId,
            t.investmentId != null,
            t.date,
            t.amount,
          ),
        ),
      );
    }
  }

  String _money(BuildContext context, int cents) {
    final locale = Localizations.localeOf(context).toString();
    final value = NumberFormat.currency(
      locale: locale,
      symbol: '',
      decimalDigits: 2,
    ).format(cents / 100).trim();
    return '$value ${context.read<CurrencyProvider>().currency}';
  }

  List<_Slice> _slices(BuildContext context) {
    final entries = _data.groups.entries.toList();
    Color color(String? id, int index) {
      final raw = widget.categories[id]?['color'];
      var result =
          (widget.type == 'expense' || widget.type == 'income') && raw is num
          ? Color(raw.toInt())
          : _palette[index % _palette.length];
      final light = Theme.of(context).brightness == Brightness.light;
      if ((!light && result.computeLuminance() < .12) ||
          (light && result.computeLuminance() > .75)) {
        result = Color.lerp(result, light ? Colors.black : Colors.white, .3)!;
      }
      return result;
    }

    String label(String? id) => switch (widget.type) {
      'investment' => widget.investmentIds[id] ?? context.tr('Investissement'),
      'transfer' => widget.accountIds[id] ?? context.tr('Compte destination'),
      _ => widget.categories[id]?['name']?.toString() ?? context.tr('Autre'),
    };
    return [
      for (var i = 0; i < entries.length; i++)
        _Slice(
          entries[i].key,
          label(entries[i].key),
          entries[i].value,
          color(entries[i].key, i),
        ),
    ];
  }

  double _categoryHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return math.max(196.0, 172.5 * scale + 28);
  }

  List<_Slice> _incomeSlices(BuildContext context) {
    final all = _slices(context);
    if (all.length <= 5) return all;
    return [
      ...all.take(5),
      _Slice(
        null,
        context.trParams('Autres ({count})', {'count': all.length - 5}),
        all.skip(5).fold(0, (sum, s) => sum + s.cents),
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CurrencyProvider>();
    final frameHeight = _categoryHeight(context);
    if (context.watch<PrivacyProvider>().hideAmounts)
      return Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: PrivacyChartMask(height: frameHeight),
      );
    if (_data.total == 0)
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
        child: SizedBox(
          height: frameHeight,
          child: Center(
            child: Text(context.tr('Aucune donnée pour ce graphique')),
          ),
        ),
      );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: SizedBox(
            width: double.infinity,
            height: frameHeight,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: 'month-chart-${widget.type}',
              label: widget.type == 'expense'
                  ? _slices(context)
                        .map((s) => '${s.label} : ${_money(context, s.cents)}')
                        .join('; ')
                  : null,
              child: TooltipVisibility(
                visible: TickerMode.valuesOf(context).enabled,
                child: switch (widget.type) {
                  'income' => _pie(context, _incomeSlices(context)),
                  'investment' => InvestmentSectionsChart(
                    key: ValueKey((widget.month.year, widget.month.month)),
                    sections: _sections,
                    money: (cents) => _money(context, cents),
                    detailBuilder: (context, index) {
                      final section = _sections[index];
                      if (section.total == 0)
                        return Center(
                          child: Text(
                            context.tr('Aucune donnée pour ce graphique'),
                          ),
                        );
                      final entries = section.assets.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      final slices = <_Slice>[
                        for (final e in entries.take(5))
                          _Slice(
                            e.key,
                            widget.investmentIds[e.key] ??
                                context.tr('Investissement'),
                            e.value,
                            investmentSectionColor(
                              widget.investmentTypes[e.key] ?? 'other',
                            ),
                          ),
                        if (entries.length > 5)
                          _Slice(
                            null,
                            context.trParams('Autres ({count})', {
                              'count': entries.length - 5,
                            }),
                            entries.skip(5).fold(0, (sum, e) => sum + e.value),
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      ];
                      return _pie(context, slices);
                    },
                  ),
                  'transfer' => TransferSankeyChart(
                    key: ValueKey((widget.month.year, widget.month.month)),
                    routes: _routes,
                    accounts: widget.accountIds,
                    investments: widget.investmentIds,
                    money: (cents) => _money(context, cents),
                    currency: context.read<CurrencyProvider>().currency,
                  ),
                  _ => _vertical(context, _slices(context)),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _axisLabel(String label) {
    final clean = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    final chars = clean.characters;
    if (chars.length <= 5) return clean;
    final words = clean.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.length > 1) {
      return words
          .take(4)
          .map((word) => word.characters.first)
          .join()
          .toUpperCase();
    }
    return chars.take(3).toString().toUpperCase();
  }

  Widget _vertical(BuildContext context, List<_Slice> slices) => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
      final axis = MonthMoneyAxis(slices.map((s) => s.cents));
      final left = axis.width(context, (cents) => _money(context, cents));
      final bottom = 54.0 * scale;
      final plotWidth = math.max(
        bounds.maxWidth,
        left + slices.length * 21 * scale,
      );
      final data = BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: axis.maximum,
        gridData: _grid(context, axis.interval),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < slices.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: slices[i].cents / 100,
                  width: math.min(24, (plotWidth - left) / slices.length * .5),
                  color: slices[i].color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
        titlesData: _titles(context, axis, bottom, (value, meta) {
          final i = value.toInt();
          if (i < 0 || i >= slices.length || value != i)
            return const SizedBox.shrink();
          final slot = (plotWidth - left) / slices.length;
          return SideTitleWidget(
            axisSide: meta.axisSide,
            space: 10,
            child: Transform.rotate(
              angle: -.55,
              alignment: Alignment.center,
              child: SizedBox(
                width: math.max(28, slot - 4),
                child: Text(
                  _axisLabel(slices[i].label),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }),
      );
      final chart = SizedBox(
        width: plotWidth,
        height: bounds.maxHeight,
        child: AppBarChart(
          data.copyWith(barTouchData: BarTouchData(enabled: false)),
        ),
      );
      // A bounded plot keeps labels readable when a month has many categories.
      return ChartInfoRegion(
        compact: true,
        changes: _expenseScroll,
        resolve: (position, _) {
          final offset = _expenseScroll.hasClients
              ? _expenseScroll.offset
              : 0.0;
          final selection = barSelectionAt(
            data,
            Size(plotWidth, bounds.maxHeight),
            position.translate(offset, 0),
          );
          if (selection == null) return null;
          final slice = slices[selection.group];
          return ChartInfo(
            slice.label,
            _money(context, slice.cents),
            color: slice.color,
            anchor: Offset(
              left +
                  (selection.group + .5) * (plotWidth - left) / slices.length -
                  offset,
              (1 - slice.cents / 100 / axis.maximum) *
                  (bounds.maxHeight - bottom),
            ),
          );
        },
        child: plotWidth <= bounds.maxWidth
            ? chart
            : Scrollbar(
                controller: _expenseScroll,
                thumbVisibility: plotWidth > bounds.maxWidth,
                child: SingleChildScrollView(
                  controller: _expenseScroll,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: chart,
                ),
              ),
      );
    },
  );

  Widget _pie(BuildContext context, List<_Slice> slices) => MonthBreakdownChart(
    slices: [
      for (final s in slices) MonthPieSlice(s.id, s.label, s.cents, s.color),
    ],
    money: (cents) => _money(context, cents),
  );

  FlTitlesData _titles(
    BuildContext context,
    MonthMoneyAxis axis,
    double bottomHeight,
    Widget Function(double, TitleMeta) bottom,
  ) => FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: axis.titles(context, (cents) => _money(context, cents)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: bottomHeight,
        interval: 1,
        getTitlesWidget: bottom,
      ),
    ),
  );
  FlGridData _grid(BuildContext context, double interval) => FlGridData(
    drawVerticalLine: false,
    horizontalInterval: interval,
    getDrawingHorizontalLine: (_) => FlLine(
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .5),
      strokeWidth: .7,
      dashArray: [3, 5],
    ),
  );
}

class _Slice {
  final String? id;
  final String label;
  final int cents;
  final Color color;
  const _Slice(this.id, this.label, this.cents, this.color);
}
