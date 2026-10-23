import 'package:mysold/widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/services/budget_alert_service.dart';
import 'package:mysold/services/local_notification_service.dart';

class BudgetAlertPage extends StatefulWidget {
  final String userId;

  const BudgetAlertPage({super.key, required this.userId});

  @override
  State<BudgetAlertPage> createState() => _BudgetAlertPageState();
}

class _BudgetAlertPageState extends State<BudgetAlertPage> {
  late final BudgetAlertService _service;
  late Future<BudgetMonthStats> _statsFuture;
  late Future<List<BudgetAlert>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _service = BudgetAlertService(userId: widget.userId);
    _statsFuture = _service.getCurrentMonthStats();
    _alertsFuture = _service.getAlerts();
  }

  Future<void> _refreshStats() async {
    setState(() {
      _statsFuture = _service.getCurrentMonthStats();
      _alertsFuture = _service.getAlerts();
    });
  }

  Future<void> _checkAlerts() async {
    final triggered = await _service.checkCurrentMonthAlerts();
    await _refreshStats();

    if (!mounted) return;
    for (final alert in triggered) {
      await LocalNotificationService.showBudgetAlert(alert);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          triggered.isEmpty
              ? context.tr('Aucune nouvelle alerte declenchee')
              : context
                    .tr('{count} alerte(s) declenchee(s)')
                    .replaceAll('{count}', triggered.length.toString()),
        ),
      ),
    );
  }

  Future<void> _openAlertEditor({BudgetAlert? alert}) async {
    final titleCtrl = TextEditingController(
      text: alert?.title ?? context.tr('Depenses mensuelles'),
    );
    final thresholdCtrl = TextEditingController(
      text: (alert?.thresholdPercent ?? 50).toStringAsFixed(0),
    );
    var isEnabled = alert?.isEnabled ?? true;

    final saved = await showAppSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      alert == null
                          ? context.tr('Nouvelle alerte')
                          : context.tr('Modifier l alerte'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: context.tr('Nom de l alerte'),
                        hintText: context.tr('Ex: Attention aux depenses'),
                        prefixIcon: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: thresholdCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.tr('Seuil'),
                        hintText: '50',
                        suffixText: '%',
                        prefixIcon: const Icon(Icons.percent),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isEnabled,
                        onChanged: (value) {
                          setModalState(() => isEnabled = value);
                        },
                        title: Text(context.tr('Alerte active')),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final threshold = double.tryParse(
                            thresholdCtrl.text.trim().replaceAll(',', '.'),
                          );
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty || threshold == null) return;

                          try {
                            await _service.saveAlert(
                              alertId: alert?.id,
                              title: title,
                              thresholdPercent: threshold,
                              isEnabled: isEnabled,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${context.tr('Erreur')} : $e'),
                                ),
                              );
                            }
                            return;
                          }

                          if (context.mounted) Navigator.pop(context, true);
                        },
                        icon: const Icon(Icons.check),
                        label: Text(
                          alert == null
                              ? context.tr('Ajouter')
                              : context.tr('Mettre a jour'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      await _refreshStats();
    }
  }

  Future<void> _confirmDelete(BudgetAlert alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Supprimer l alerte')),
          content: Text(context.tr('Cette limite budgetaire sera supprimee.')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Annuler')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                context.tr('Supprimer'),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _service.deleteAlert(alert.id);
      await _refreshStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>().currency;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Limites budgetaires'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAlertEditor(),
        icon: const Icon(Icons.add),
        label: Text(context.tr('Alerte')),
      ),
      body: FutureBuilder<BudgetMonthStats>(
        future: _statsFuture,
        builder: (context, statsSnapshot) {
          final stats =
              statsSnapshot.data ??
              const BudgetMonthStats(income: 0, expense: 0, monthKey: '');

          return FutureBuilder<List<BudgetAlert>>(
            future: _alertsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final alerts = snapshot.data ?? [];

              if (alerts.isEmpty) {
                return _buildEmptyState(stats, currency);
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  _buildHeader(stats, currency, alerts.length),
                  const SizedBox(height: 16),
                  ...alerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAlertCard(alert, stats),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(BudgetMonthStats stats, String currency, int count) {
    final privacy = context.watch<PrivacyProvider>();
    final progress = (stats.expenseIncomePercent / 100).clamp(0.0, 1.0);
    final hidden = privacy.hideAmounts;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Alertes du mois'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context
                          .tr('{count} seuil(s) configure(s)')
                          .replaceAll('{count}', count.toString()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.64),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('Verifier'),
                onPressed: _checkAlerts,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            hidden
                ? context.tr('**% des revenus depenses')
                : context
                      .tr('{percent}% des revenus depenses')
                      .replaceAll(
                        '{percent}',
                        stats.expenseIncomePercent.toStringAsFixed(0),
                      ),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: hidden ? 1 : progress,
            minHeight: 7,
            color: hidden
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.18)
                : null,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 10),
          Text(
            '${context.tr('Depenses')} ${_money(stats.expense, currency, privacy)} / ${context.tr('Revenus')} ${_money(stats.income, currency, privacy)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.64),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BudgetAlert alert, BudgetMonthStats stats) {
    final title = alert.title;
    final threshold = alert.thresholdPercent;
    final isEnabled = alert.isEnabled;
    final isReached = isEnabled && stats.expenseIncomePercent >= threshold;
    final privacy = context.watch<PrivacyProvider>();
    final hidden = privacy.hideAmounts;
    final progress = threshold <= 0
        ? 0.0
        : (stats.expenseIncomePercent / threshold).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color:
                      (hidden
                              ? Theme.of(context).colorScheme.onSurface
                              : isReached
                              ? Colors.redAccent
                              : Theme.of(context).colorScheme.primary)
                          .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  hidden
                      ? Icons.visibility_off_outlined
                      : isReached
                      ? Icons.warning_amber_rounded
                      : Icons.notifications_none_outlined,
                  color: hidden
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.52)
                      : isReached
                      ? Colors.redAccent
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEnabled
                          ? context
                                .tr('Seuil a {percent}% des revenus')
                                .replaceAll(
                                  '{percent}',
                                  threshold.toStringAsFixed(0),
                                )
                          : context.tr('Alerte desactivee'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.62),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openAlertEditor(alert: alert);
                  } else if (value == 'delete') {
                    _confirmDelete(alert);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined),
                        const SizedBox(width: 8),
                        Text(context.tr('Modifier')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(context.tr('Supprimer')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: hidden ? 1 : progress,
            minHeight: 6,
            color: hidden
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.18)
                : isReached
                ? Colors.redAccent
                : null,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  isReached
                      ? context.tr('Seuil atteint')
                      : context.tr('En surveillance'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: hidden
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.58)
                        : isReached
                        ? Colors.redAccent
                        : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                hidden
                    ? '**%'
                    : '${stats.expenseIncomePercent.toStringAsFixed(0)}%',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BudgetMonthStats stats, String currency) {
    final privacy = context.watch<PrivacyProvider>();
    final hidden = privacy.hideAmounts;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('Aucune limite'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Creez un seuil pour surveiller vos depenses par rapport aux revenus du mois.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hidden
                  ? context
                        .tr('Actuel: **% - {amount} depenses')
                        .replaceAll(
                          '{amount}',
                          _money(stats.expense, currency, privacy),
                        )
                  : context
                        .tr('Actuel: {percent}% - {amount} depenses')
                        .replaceAll(
                          '{percent}',
                          stats.expenseIncomePercent.toStringAsFixed(0),
                        )
                        .replaceAll(
                          '{amount}',
                          _money(stats.expense, currency, privacy),
                        ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _openAlertEditor(),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Ajouter une alerte')),
            ),
          ],
        ),
      ),
    );
  }

  String _money(double value, String currency, PrivacyProvider privacy) {
    return privacy.money(value, currency);
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
      ),
    );
  }
}
