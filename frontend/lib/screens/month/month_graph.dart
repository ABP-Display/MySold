import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/month_chart_data.dart';
import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/widgets/graphiques/app_charts.dart';
import 'package:mysold/widgets/graphiques/chart_info_region.dart';
import 'package:mysold/widgets/graphiques/month_chart_style.dart';
import 'package:mysold/widgets/graphiques/month_investment_chart.dart';
import 'package:mysold/widgets/graphiques/month_transfer_chart.dart';
import 'package:mysold/widgets/privacy/privacy_chart_mask.dart';

class MonthGraph extends StatefulWidget {
  final DateTime month;
  final List<TransactionModel> transactions;
  final Map<String, Map<String, dynamic>> categories;
  final Map<String, String> accountIds, investmentIds, investmentTypes;
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
  late MonthChartData _data;
  List<Object> _inputs = const [];
  Map<String, String> _types = const {};
  int? _week;
  late int _limit;
  @override
  void initState() {
    super.initState();
    _limit = widget.type == 'income' ? 4 : 5;
    _prepare(force: true);
  }

  @override
  void didUpdateWidget(covariant MonthGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month ||
        oldWidget.type != widget.type;
    if (changed) {
      _week = null;
      _limit = widget.type == 'income' ? 4 : 5;
    }
    _prepare(force: changed);
  }

  void _prepare({bool force = false}) {
    // Snapshot mutable transaction fields so edits cannot leave a stale chart.
    final inputs = <Object>[
      for (final t in widget.transactions)
        (
          t.id,
          t.type,
          t.amount,
          t.date.millisecondsSinceEpoch,
          t.date.isUtc,
          t.categoryId,
          t.fromAccountId,
          t.toAccountId,
          t.investmentId,
        ),
    ];
    if (force ||
        !listEquals(inputs, _inputs) ||
        !mapEquals(widget.investmentTypes, _types)) {
      _inputs = inputs;
      _types = Map.of(widget.investmentTypes);
      _data = MonthChartData.build(
        widget.month,
        widget.transactions,
        investmentTypes: _types,
      );
    }
  }

  List<_CategorySlice> _slices(
    BuildContext context,
    List<MonthCategoryTotal> values,
  ) {
    final result = <_CategorySlice>[];
    for (final value in values.take(_limit)) {
      final category = widget.categories[value.id], raw = category?['color'];
      final color = raw is num ? Color(raw.toInt()) : Colors.grey;
      result.add(
        _CategorySlice(
          category?['name']?.toString() ?? context.tr('Autre'),
          value.cents,
          readableChartColor(context, color),
        ),
      );
    }
    final remaining = values.skip(_limit).toList();
    if (remaining.isNotEmpty)
      result.add(
        _CategorySlice(
          context.trParams('Autres ({count})', {'count': remaining.length}),
          remaining.fold(0, (sum, v) => sum + v.cents),
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>().currency;
    if (context.watch<PrivacyProvider>().hideAmounts)
      return const Padding(
        padding: EdgeInsets.all(16),
        child: PrivacyChartMask(height: 260),
      );
    final categories =
        _data.categories[widget.type] ?? const <MonthCategoryTotal>[];
    final hasData = widget.type == 'investment'
        ? _data.investmentTotal > 0
        : widget.type == 'transfer'
        ? _data.transferTotal > 0
        : categories.isNotEmpty;
    if (!hasData)
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(context.tr('Aucune donnée pour ce graphique')),
      );
    Widget chart;
    if (widget.type == 'investment') {
      chart = MonthInvestmentChart(
        data: _data,
        currency: currency,
        selectedWeek: _week,
        onWeekChanged: (value) => setState(() => _week = value),
      );
    } else if (widget.type == 'transfer') {
      chart = MonthTransferChart(
        flows: _data.transfers,
        accounts: widget.accountIds,
        investments: widget.investmentIds,
        currency: currency,
      );
    } else {
      final total = categories.fold(0, (sum, v) => sum + v.cents);
      final slices = _slices(context, categories);
      chart = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(
                context.tr(
                  widget.type == 'income'
                      ? 'Origine des revenus'
                      : 'Répartition du mois',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                monthChartMoney(context, total, currency),
                key: const ValueKey('month-chart-total'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (widget.type == 'income')
            _income(context, slices, total, currency)
          else
            _expenses(context, slices, total, currency),
          if (categories.length > (widget.type == 'income' ? 4 : 5))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('month-chart-more-categories'),
                icon: Icon(
                  _limit >= categories.length
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 18,
                ),
                onPressed: () => setState(
                  () => _limit = _limit >= categories.length
                      ? (widget.type == 'income' ? 4 : 5)
                      : _limit + 5,
                ),
                label: Text(
                  context.tr(
                    _limit >= categories.length ? 'Réduire' : 'Afficher plus',
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: chart,
        ),
      ),
    );
  }

  Widget _expenses(
    BuildContext context,
    List<_CategorySlice> slices,
    int total,
    String currency,
  ) => Column(
    children: [
      for (final slice in slices)
        Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Tooltip(
            message:
                '${slice.label} · ${monthChartMoney(context, slice.cents, currency)}',
            child: Semantics(
              label:
                  '${slice.label}, ${monthChartMoney(context, slice.cents, currency)}',
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final wide = bounds.maxWidth >= 600;
                  final amount = monthChartMoney(
                    context,
                    slice.cents,
                    currency,
                  );
                  final bar = LayoutBuilder(
                    builder: (context, barBounds) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: math.max(
                          1,
                          barBounds.maxWidth *
                              slice.cents /
                              slices.fold<int>(
                                1,
                                (maximum, item) =>
                                    math.max(maximum, item.cents),
                              ),
                        ),
                        height: wide ? 18 : 10,
                        decoration: BoxDecoration(
                          color: slice.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  );
                  if (wide)
                    return Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            slice.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: SizedBox(height: 26, child: bar)),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 145,
                          child: Text(
                            amount,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    );
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              slice.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              amount,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      SizedBox(height: 10, child: bar),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
    ],
  );
  Widget _income(
    BuildContext context,
    List<_CategorySlice> slices,
    int total,
    String currency,
  ) => LayoutBuilder(
    builder: (context, bounds) {
      final locale = Localizations.localeOf(context).toString();
      final wide = bounds.maxWidth >= 600;
      final donut = SizedBox(
        width: 220,
        height: 220,
        child: ChartInfoRegion(
          resolve: (position, size) {
            final delta = position - Offset(size.width / 2, size.height / 2);
            if (delta.distance < 62 || delta.distance > 105) return null;
            final angle =
                (math.atan2(delta.dy, delta.dx) + math.pi / 2 + math.pi * 2) %
                (math.pi * 2);
            var end = 0.0;
            for (final slice in slices) {
              end += slice.cents / total * math.pi * 2;
              if (angle <= end)
                return ChartInfo(
                  slice.label,
                  '${monthChartMoney(context, slice.cents, currency)} · ${NumberFormat.decimalPercentPattern(locale: locale, decimalDigits: 1).format(slice.cents / total)}',
                  color: slice.color,
                );
            }
            return null;
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AppPieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  centerSpaceRadius: 64,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (final slice in slices)
                      PieChartSectionData(
                        value: slice.cents.toDouble(),
                        color: slice.color,
                        radius: 36,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              IgnorePointer(
                child: SizedBox(
                  width: 116,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      monthChartMoney(context, total, currency),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      Widget legend(double width) {
        final columns = wide
            ? 1
            : width >= 240
            ? 2
            : 1;
        final itemWidth = (width - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            for (final slice in slices)
              SizedBox(
                width: itemWidth,
                child: Tooltip(
                  message: slice.label,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: slice.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slice.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              monthChartMoney(context, slice.cents, currency),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }

      if (wide)
        return Row(
          children: [
            donut,
            const SizedBox(width: 32),
            Expanded(
              child: LayoutBuilder(builder: (context, b) => legend(b.maxWidth)),
            ),
          ],
        );
      return Column(
        children: [
          Center(child: donut),
          const SizedBox(height: 12),
          legend(bounds.maxWidth),
        ],
      );
    },
  );
}

class _CategorySlice {
  final String label;
  final int cents;
  final Color color;
  const _CategorySlice(this.label, this.cents, this.color);
}
