import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/investment_type.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/models/category_evolution.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/services/annual_analysis_service.dart';
import 'package:mysold/services/security_gate.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/graphiques/entity_annual_chart.dart';

/// A single item opened from its own management list, not a profile destination.
class EntityEvolutionPage extends StatefulWidget {
  final String userId, entityPath, name;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>>) onEdit;
  const EntityEvolutionPage({
    super.key,
    required this.userId,
    required this.entityPath,
    required this.name,
    required this.onEdit,
  });
  @override
  State<EntityEvolutionPage> createState() => _EntityEvolutionPageState();
}

class _EntityEvolutionPageState extends State<EntityEvolutionPage> {
  int _year = DateTime.now().toUtc().year;
  late Future<Map<String, dynamic>> _summary;
  late Future<Map<String, dynamic>> _configuration;
  late Future<Map<String, dynamic>> _currentSummary;
  late String _displayName;
  bool get _category => widget.entityPath.startsWith('categories/');
  bool get _investment => widget.entityPath.startsWith('investments/');

  @override
  void initState() {
    super.initState();
    _summary = readAnnualAnalysis(_year);
    _currentSummary = _summary;
    _displayName = widget.name;
    _configuration = _readConfiguration();
  }

  Future<Map<String, dynamic>> _readConfiguration() async {
    final doc = await DocumentStore.instance
        .doc('users/${widget.userId}/${widget.entityPath}')
        .get();
    final data = doc.data() ?? <String, dynamic>{};
    String? support;
    if (_investment && data['holdingAccountId'] is String) {
      final account = await DocumentStore.instance
          .doc('users/${widget.userId}/accounts/${data['holdingAccountId']}')
          .get();
      support = account.data()?['name']?.toString();
    }
    return {'document': doc, 'data': data, 'support': support};
  }

  Future<void> _edit(DocumentSnapshot<Map<String, dynamic>> document) async {
    await widget.onEdit(document);
    if (mounted)
      setState(() {
        _configuration = _readConfiguration();
        _summary = readAnnualAnalysis(_year);
        _currentSummary = readAnnualAnalysis(DateTime.now().toUtc().year);
      });
  }

  Future<void> _reference(Map<String, dynamic> entity) async {
    if (!await SecurityGate.requestPin(
          context,
          title: context.tr('Référence annuelle'),
          message: context.tr(
            'Confirmez votre PIN pour modifier la valeur au 1er janvier.',
          ),
        ) ||
        !mounted)
      return;
    String? value;
    final form = GlobalKey<FormState>();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          context.trParams('Valeur au 1er janvier {year}', {'year': _year}),
        ),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: (entity['opening'] as num).toStringAsFixed(2),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            onChanged: (text) => value = text,
            validator: (text) {
              final number = double.tryParse((text ?? '').replaceAll(',', '.'));
              return number == null || !number.isFinite || number.abs() > 1e12
                  ? context.tr('Montant invalide')
                  : null;
            },
            decoration: InputDecoration(
              labelText: context.tr('Montant de référence'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(context.tr('Annuler')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate())
                Navigator.pop(
                  dialog,
                  double.parse(
                    (value ?? entity['opening'].toString()).replaceAll(
                      ',',
                      '.',
                    ),
                  ),
                );
            },
            child: Text(context.tr('Enregistrer')),
          ),
        ],
      ),
    );
    if (amount == null || !mounted) return;
    try {
      final id = sha256
          .convert(utf8.encode('${widget.entityPath}:$_year'))
          .toString();
      await DocumentStore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('annualReferences')
          .doc(id)
          .set({
            'entityPath': widget.entityPath,
            'year': _year,
            'amount': amount,
          });
      if (mounted) setState(() => _summary = readAnnualAnalysis(_year));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Référence non enregistrée. Réessayez.')),
          ),
        );
    }
  }

  String _money(num? value) {
    if (context.read<PrivacyProvider>().hideAmounts) return '••••';
    if (value == null) return '—';
    return NumberFormat.currency(
      locale: Localizations.localeOf(context).toString(),
      symbol: context.read<CurrencyProvider>().currency,
      decimalDigits: 2,
    ).format(value);
  }

  String _rate(num? value) => context.read<PrivacyProvider>().hideAmounts
      ? '••••'
      : value == null
      ? context.tr('Non calculable')
      : '${value > 0 ? '+' : ''}${NumberFormat.decimalPercentPattern(locale: Localizations.localeOf(context).toString(), decimalDigits: 1).format(value / 100)}';

  @override
  Widget build(BuildContext context) {
    final hidden = context.watch<PrivacyProvider>().hideAmounts;
    final currency = context.watch<CurrencyProvider>().currency;
    return Scaffold(
      appBar: appPageBar(
        context,
        title: Text(_displayName),
        translateTitle: false,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ListView(
            key: PageStorageKey('entity-${widget.entityPath}'),
            dragStartBehavior: DragStartBehavior.down,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              _overview(),
              const Divider(height: 40),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    context.tr('Évolution annuelle'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.tr('Année précédente'),
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _year <= 1900
                            ? null
                            : () => _changeYear(_year - 1),
                      ),
                      Text(
                        '$_year',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        tooltip: context.tr('Année suivante'),
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _year >= DateTime.now().toUtc().year
                            ? null
                            : () => _changeYear(_year + 1),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FutureBuilder<Map<String, dynamic>>(
                future: _summary,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return _retry(
                      () =>
                          setState(() => _summary = readAnnualAnalysis(_year)),
                    );
                  if (snapshot.connectionState != ConnectionState.done)
                    return const SizedBox(
                      height: 290,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  final entity = annualEntities(
                    snapshot.data,
                  )[widget.entityPath];
                  if (entity == null)
                    return Text(
                      context.tr('Aucun élément pour cette période.'),
                    );
                  final asOf =
                      DateTime.tryParse(
                        snapshot.data?['asOf']?.toString() ?? '',
                      ) ??
                      DateTime.now().toUtc();
                  final comparison = _category
                      ? CategoryEvolution.fromSummary(entity)
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EntityAnnualChart(
                        year: _year,
                        values: annualChartValues(entity, _year, asOf),
                        currency: currency,
                        hidden: hidden,
                        zeroBased: _category,
                      ),
                      const SizedBox(height: 24),
                      _metrics(
                        [
                          (
                            _category
                                ? 'Année précédente, même période'
                                : 'Au 1er janvier',
                            _money(
                              (_category
                                      ? entity['previous']
                                      : entity['opening'])
                                  as num?,
                            ),
                          ),
                          ('Variation', _money(entity['delta'] as num?)),
                        ],
                        details: {
                          'Variation': hidden
                              ? '••••'
                              : comparison?.label != null
                              ? context.tr(comparison!.label!)
                              : _rate(
                                  comparison?.percent ??
                                      entity['percent'] as num?,
                                ),
                        },
                      ),
                      if (_category &&
                          comparison!.label != null &&
                          !hidden) ...[
                        const SizedBox(height: 12),
                        Text(
                          context.tr(comparison.hint),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (!_category) ...[
                        const SizedBox(height: 20),
                        ExpansionTile(
                          key: const ValueKey('entity-reference-settings'),
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 12),
                          title: Text(
                            context.tr('Référence annuelle'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            context.tr(
                              entity['estimated'] == true
                                  ? 'Valeur reconstituée, à confirmer'
                                  : 'Référence renseignée',
                            ),
                          ),
                          children: [
                            if ((entity['unexplained'] as num).abs() > .01)
                              Text(
                                context.trParams(
                                  'Écart non historisé : {amount}',
                                  {
                                    'amount': _money(
                                      entity['unexplained'] as num,
                                    ),
                                  },
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _reference(entity),
                                label: Text(
                                  context.tr(
                                    'Renseigner la référence annuelle',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_investment) ...[
                        const SizedBox(height: 16),
                        _metrics([
                          (
                            'Versements nets',
                            _money(entity['netFlows'] as num?),
                          ),
                          (
                            'Valorisation',
                            _money(entity['valuationChange'] as num?),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Text(
                          context.tr(
                            'La variation inclut les versements et retraits : ce n’est pas un rendement financier.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeYear(int year) => setState(() {
    _year = year;
    _summary = readAnnualAnalysis(year);
  });

  Widget _overview() => FutureBuilder<Map<String, dynamic>>(
    future: _configuration,
    builder: (context, snapshot) {
      final config = snapshot.data,
          data = config?['data'] as Map<String, dynamic>?;
      final document =
          config?['document'] as DocumentSnapshot<Map<String, dynamic>>?;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.tr(_category ? 'Total annuel' : 'Solde actuel'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: document?.exists == true
                    ? () async {
                        await _edit(document!);
                        if (!mounted) return;
                        try {
                          final updated = await _configuration;
                          if (mounted)
                            setState(
                              () => _displayName =
                                  (updated['data'] as Map)['name']
                                      ?.toString() ??
                                  widget.name,
                            );
                        } catch (_) {
                          // The configuration builder provides its retry action.
                        }
                      }
                    : null,
                label: Text(context.tr('Modifier')),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FutureBuilder<Map<String, dynamic>>(
            future: _currentSummary,
            builder: (context, summary) {
              final entity = annualEntities(summary.data)[widget.entityPath];
              final amount =
                  (_category ? (entity?['current']) : (data?['balance']))
                      as num?;
              return Text(
                _money(amount),
                key: const ValueKey('entity-current-amount'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              );
            },
          ),
          if (snapshot.hasError)
            _retry(() => setState(() => _configuration = _readConfiguration())),
          if (data != null) ...[
            if ((data['description']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                data['description'].toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _metadata([
              if (_category)
                (
                  'Type',
                  context.tr(data['type'] == 'income' ? 'Revenu' : 'Dépense'),
                ),
              if (_investment) ...[
                (
                  'Type',
                  investmentCategoryLabel(
                    context,
                    investmentTypeOption(
                      data['investmentType']?.toString() ?? 'other',
                      options: context
                          .watch<UserDataProvider>()
                          .investmentCategories,
                    ),
                  ),
                ),
                (
                  'Compte support',
                  config?['support']?.toString() ??
                      context.tr('Compte non défini'),
                ),
              ],
              if (!_category && !_investment)
                (
                  'Gestion du solde',
                  context.tr(
                    data['managedByInvestments'] == true
                        ? 'Compte investissement auto'
                        : 'Manuelle',
                  ),
                ),
            ]),
          ],
        ],
      );
    },
  );

  Widget _metrics(
    List<(String, String)> values, {
    Map<String, String> details = const {},
  }) => LayoutBuilder(
    builder: (context, bounds) {
      final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
      final columns = largeText
          ? 1
          : bounds.maxWidth >= 600
          ? values.length
          : 2;
      final width = (bounds.maxWidth - (columns - 1) * 18) / columns;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: largeText ? null : 36,
                    child: Text(
                      context.tr(value.$1),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value.$2,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (details[value.$1] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      details[value.$1]!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _metadata(List<(String, String)> values) => Wrap(
    spacing: 28,
    runSpacing: 14,
    children: [
      for (final value in values)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(value.$1),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(value.$2),
            ],
          ),
        ),
    ],
  );

  Widget _retry(VoidCallback retry) => TextButton.icon(
    onPressed: retry,
    icon: const Icon(Icons.refresh),
    label: Text(context.tr('Chargement impossible. Réessayer')),
  );
}
