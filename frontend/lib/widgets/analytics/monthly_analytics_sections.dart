import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/monthly_analytics.dart';
import 'package:mysold/widgets/app_design.dart';

String _money(
  BuildContext context,
  double value,
  String currency,
  bool hidden,
) => hidden
    ? '•••• $currency'
    : NumberFormat.currency(
        locale: Localizations.localeOf(context).toString(),
        symbol: currency,
      ).format(value);
Color _muted(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

class MonthlyStatsPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;
  const MonthlyStatsPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });
  @override
  Widget build(BuildContext context) => AppPanel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr(title),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(color: _muted(context), fontSize: 12, height: 1.5),
          ),
        ],
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class MonthlyOverview extends StatelessWidget {
  final MonthlyAnalytics data;
  final MonthlyTotals? totals;
  final String currency;
  final bool hidden;
  const MonthlyOverview({
    super.key,
    required this.data,
    this.totals,
    required this.currency,
    required this.hidden,
  });
  @override
  Widget build(BuildContext context) => AppMetricGrid(
    children: [
      for (final item in [
        (
          'Revenus',
          (totals ?? data.current).income,
          Icons.south_west,
          Colors.green,
        ),
        (
          'Dépenses',
          (totals ?? data.current).expense,
          Icons.north_east,
          Theme.of(context).colorScheme.error,
        ),
        (
          'Investissements',
          (totals ?? data.current).investment,
          Icons.trending_up,
          Theme.of(context).colorScheme.primary,
        ),
        (
          totals == null ? 'Reste du mois' : 'Reste de l’année',
          (totals ?? data.current).available,
          Icons.payments_outlined,
          Theme.of(context).colorScheme.primary,
        ),
      ])
        AppMetricCard(
          label: context.tr(item.$1),
          value: _money(context, item.$2, currency, hidden),
          icon: item.$3,
          color: hidden ? _muted(context) : item.$4,
        ),
    ],
  );
}

class _MetricPair extends StatelessWidget {
  final List<Widget> children;
  const _MetricPair({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns =
          bounds.maxWidth >= 560 &&
              MediaQuery.textScalerOf(context).scale(14) < 22
          ? 2
          : 1;
      final width = (bounds.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class MonthlyProjection extends StatelessWidget {
  final MonthlyAnalytics data;
  final String currency;
  final bool hidden;
  const MonthlyProjection({
    super.key,
    required this.data,
    required this.currency,
    required this.hidden,
  });
  @override
  Widget build(BuildContext context) => MonthlyStatsPanel(
    title: 'Projection fin de mois',
    icon: Icons.auto_graph,
    subtitle:
        '${DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(data.month)} · ${context.tr(data.isCurrent ? 'Dépenses estimées au rythme actuel, revenus reçus et investissements inchangés.' : 'Mois terminé : résultat réel.')}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricPair(
          children: [
            AppMetricCard(
              label: context.tr('Reste du mois'),
              value: _money(context, data.current.available, currency, hidden),
              icon: Icons.payments_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            AppMetricCard(
              label: context.tr(
                data.isCurrent ? 'Fin de mois estimée' : 'Résultat du mois',
              ),
              value: data.projectedAvailable == null
                  ? '—'
                  : _money(context, data.projectedAvailable!, currency, hidden),
              icon: Icons.flag_outlined,
              color: hidden || (data.projectedAvailable ?? 0) >= 0
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ],
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: data.elapsedDays / data.daysInMonth,
          minHeight: 5,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text(
          '${data.elapsedDays} / ${data.daysInMonth} ${context.tr('jours écoulés')}',
          style: TextStyle(color: _muted(context), fontSize: 12),
        ),
        if (data.financialOperationCount == 0) ...[
          const SizedBox(height: 8),
          Text(context.tr('Pas assez de données pour estimer la fin du mois.')),
        ],
      ],
    ),
  );
}
