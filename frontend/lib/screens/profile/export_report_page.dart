import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:mysold/services/budget_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/services/security_gate.dart';
import 'package:mysold/services/transaction_export_service.dart';

class ExportReportPage extends StatefulWidget {
  const ExportReportPage({super.key});

  @override
  State<ExportReportPage> createState() => _ExportReportPageState();
}

class _ExportReportPageState extends State<ExportReportPage> {
  _ExportPeriodChoice _period = _ExportPeriodChoice.thisMonth;
  DateTimeRange? _customRange;

  DateTimeRange get _selectedRange {
    final now = DateTime.now();
    switch (_period) {
      case _ExportPeriodChoice.fullYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year + 1, 1, 1),
        );
      case _ExportPeriodChoice.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case _ExportPeriodChoice.custom:
        return _customRange ??
            DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: DateTime(now.year, now.month, now.day + 1),
            );
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange:
          _customRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (range == null) return;
    setState(() {
      _period = _ExportPeriodChoice.custom;
      _customRange = DateTimeRange(
        start: DateTime(range.start.year, range.start.month, range.start.day),
        end: DateTime(range.end.year, range.end.month, range.end.day + 1),
      );
    });
  }

  Future<void> _startExport() async {
    final authorized = await SecurityGate.requestPin(
      context,
      title: context.tr('Exporter un rapport'),
      message: context.tr('Confirmez votre PIN avant de generer le PDF.'),
    );
    if (!authorized || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExportReportLoadingPage(
          range: _selectedRange,
          periodLabel: _periodLabel(_period),
        ),
      ),
    );
  }

  String _periodLabel(_ExportPeriodChoice period) {
    switch (period) {
      case _ExportPeriodChoice.fullYear:
        return 'Annee complete';
      case _ExportPeriodChoice.thisMonth:
        return 'Ce mois-ci';
      case _ExportPeriodChoice.custom:
        return 'Periode personnalisee';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final range = _selectedRange;
    final inclusiveEnd = range.end.subtract(const Duration(days: 1));

    return Scaffold(
      appBar: appPageBar(
        context,
        title: Text(context.tr('Exporter un rapport')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Panel(
            icon: Icons.calendar_month_outlined,
            title: context.tr('Periode'),
            child: Column(
              children: [
                _RadioRow(
                  title: context.tr('Annee complete'),
                  subtitle: '${DateTime.now().year}',
                  selected: _period == _ExportPeriodChoice.fullYear,
                  onTap: () =>
                      setState(() => _period = _ExportPeriodChoice.fullYear),
                ),
                _RadioRow(
                  title: context.tr('Ce mois-ci'),
                  subtitle: DateFormat(
                    'MMMM yyyy',
                    Localizations.localeOf(context).toString(),
                  ).format(DateTime.now()),
                  selected: _period == _ExportPeriodChoice.thisMonth,
                  onTap: () =>
                      setState(() => _period = _ExportPeriodChoice.thisMonth),
                ),
                _RadioRow(
                  title: context.tr('Periode personnalisee'),
                  subtitle:
                      '${dateFormat.format(range.start)} - ${dateFormat.format(inclusiveEnd)}',
                  selected: _period == _ExportPeriodChoice.custom,
                  onTap: _pickCustomRange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            icon: Icons.dashboard_customize_outlined,
            title: context.tr('Contenu du rapport'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    'Le rapport inclut automatiquement toutes les opérations de la période.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _IncludedType(
                      label: context.tr('Revenus'),
                      color: Colors.green,
                    ),
                    _IncludedType(
                      label: context.tr('Depenses'),
                      color: Colors.redAccent,
                    ),
                    _IncludedType(
                      label: context.tr('Investissements'),
                      color: colorScheme.primary,
                    ),
                    _IncludedType(
                      label: context.tr('Transferts'),
                      color: colorScheme.onSurface.withOpacity(0.62),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _startExport,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(context.tr('Generer le PDF')),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('Le rapport sera genere en arriere-plan.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class ExportReportLoadingPage extends StatefulWidget {
  final DateTimeRange range;
  final String periodLabel;

  const ExportReportLoadingPage({
    super.key,
    required this.range,
    required this.periodLabel,
  });

  @override
  State<ExportReportLoadingPage> createState() =>
      _ExportReportLoadingPageState();
}

class _ExportReportLoadingPageState extends State<ExportReportLoadingPage> {
  double _progress = 0.08;
  String _message = 'Preparation du rapport...';
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runExport());
  }

  void _step(double progress, String message) {
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _message = message;
    });
  }

  Future<void> _runExport() async {
    try {
      final uid = LocalAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Utilisateur introuvable.');

      final references = context.read<UserDataProvider>();
      final currency = context.read<CurrencyProvider>().currency;
      final primaryColor = Theme.of(context).colorScheme.primary.value;
      final service = BudgetService(userId: uid);

      _step(0.18, context.tr('Chargement des references...'));
      final accounts = await references.getAccounts();
      final categories = await references.getCategories();
      final investments = await references.getInvestments();

      _step(0.34, context.tr('Chargement des transactions...'));
      final transactions = await service.getTransactionsBetween(
        start: widget.range.start,
        end: widget.range.end,
        descending: false,
      );

      _step(0.48, context.tr('Preparation des donnees...'));
      if (transactions.isEmpty) {
        throw Exception(context.tr('Aucune transaction a exporter.'));
      }

      await Future<void>.delayed(const Duration(milliseconds: 80));
      _step(0.68, context.tr('Generation du PDF...'));
      final title = _buildTitle();
      final bytes = await TransactionExportService.buildPdfBytesInBackground(
        transactions: transactions,
        title: title,
        currency: currency,
        accounts: accounts,
        categories: categories,
        investments: investments,
        primaryColor: primaryColor,
      );

      _step(0.92, context.tr('Enregistrement du fichier...'));
      final savedPath = await TransactionExportService.savePdfBytes(
        bytes: bytes,
        title: title,
      );

      if (!mounted) return;
      setState(() {
        _progress = 1;
        _done = true;
        _message = savedPath == null || savedPath.isEmpty
            ? context.tr('Telechargement lance.')
            : context.tr('Fichier enregistre.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _message = context.tr('Export impossible');
      });
    }
  }

  String _buildTitle() {
    final dateFormat = DateFormat('dd-MM-yyyy');
    final start = dateFormat.format(widget.range.start);
    final end = dateFormat.format(
      widget.range.end.subtract(const Duration(days: 1)),
    );
    return 'MySold - Rapport complet - $start au $end';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _done || _error != null,
      child: Scaffold(
        appBar: appPageBar(
          context,
          title: Text(context.tr('Generation du rapport')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 76,
                    width: 76,
                    decoration: BoxDecoration(
                      color:
                          (_error == null
                                  ? colorScheme.primary
                                  : Colors.redAccent)
                              .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      _error == null
                          ? (_done
                                ? Icons.check_rounded
                                : Icons.picture_as_pdf_outlined)
                          : Icons.error_outline,
                      size: 34,
                      color: _error == null
                          ? colorScheme.primary
                          : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  LinearProgressIndicator(
                    value: _error == null ? _progress : null,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _error == null
                        ? '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)} %'
                        : _error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.64),
                    ),
                  ),
                  if (_done || _error != null) ...[
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(context.tr('Retour')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ExportPeriodChoice { fullYear, thisMonth, custom }

class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Panel({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RadioRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _IncludedType extends StatelessWidget {
  final String label;
  final Color color;

  const _IncludedType({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
