import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/investment_type.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/services/annual_analysis_service.dart';
import 'package:mysold/services/security_gate.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/graphiques/app_charts.dart';

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
  bool get _category => widget.entityPath.startsWith('categories/');
  bool get _investment => widget.entityPath.startsWith('investments/');

  @override
  void initState() {
    super.initState();
    _summary = readAnnualAnalysis(_year);
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

  @override
  Widget build(BuildContext context) {
    final hidden = context.watch<PrivacyProvider>().hideAmounts;
    final currency = context.watch<CurrencyProvider>().currency;
    final locale = Localizations.localeOf(context).toString();
    String money(num? value) => hidden
        ? '••••'
        : value == null
        ? '—'
        : NumberFormat.currency(
            locale: locale,
            symbol: currency,
            decimalDigits: 2,
          ).format(value);
    String percent(num? value) => hidden
        ? '••••'
        : value == null
        ? context.tr('Non calculable')
        : '${value > 0 ? '+' : ''}${NumberFormat.decimalPercentPattern(locale: locale, decimalDigits: 1).format(value / 100)}';
    return Scaffold(
      appBar: appPageBar(
        context,
        title: Text(widget.name),
        translateTitle: false,
      ),
      body: ListView(
        key: PageStorageKey('entity-${widget.entityPath}'),
        dragStartBehavior: DragStartBehavior.down,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _configuration,
            builder: (context, snapshot) {
              final result = snapshot.data;
              final data = result?['data'] as Map<String, dynamic>?;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('Paramètres'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed:
                            result == null ||
                                !(result['document'] as DocumentSnapshot).exists
                            ? null
                            : () => _edit(
                                result['document']
                                    as DocumentSnapshot<Map<String, dynamic>>,
                              ),
                        label: Text(context.tr('Modifier')),
                      ),
                    ],
                  ),
                  if (snapshot.hasError)
                    TextButton(
                      onPressed: () =>
                          setState(() => _configuration = _readConfiguration()),
                      child: Text(
                        context.tr('Chargement impossible. Réessayer'),
                      ),
                    ),
                  if (data != null) ...[
                    if ((data['description']?.toString() ?? '').isNotEmpty)
                      _value(
                        context.tr('Description'),
                        data['description'].toString(),
                      ),
                    if (_category)
                      _value(
                        context.tr('Type'),
                        context.tr(
                          data['type'] == 'income' ? 'Revenu' : 'Dépense',
                        ),
                      ),
                    if (_investment) ...[
                      _value(
                        context.tr('Type'),
                        context.tr(
                          investmentTypeOption(
                            data['investmentType']?.toString() ?? 'other',
                          ).label,
                        ),
                      ),
                      _value(
                        context.tr('Compte support'),
                        result?['support']?.toString() ??
                            context.tr('Compte non défini'),
                      ),
                    ],
                    if (!_category && !_investment)
                      _value(
                        context.tr('Compte investissement auto'),
                        context.tr(
                          data['managedByInvestments'] == true ? 'Oui' : 'Non',
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
          const Divider(height: 32),
          Text(
            context.tr('Évolution annuelle'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: context.tr('Année précédente'),
                icon: const Icon(Icons.chevron_left),
                onPressed: _year <= 1900
                    ? null
                    : () => setState(() {
                        _year--;
                        _summary = readAnnualAnalysis(_year);
                      }),
              ),
              Text('$_year', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                tooltip: context.tr('Année suivante'),
                icon: const Icon(Icons.chevron_right),
                onPressed: _year >= DateTime.now().toUtc().year
                    ? null
                    : () => setState(() {
                        _year++;
                        _summary = readAnnualAnalysis(_year);
                      }),
              ),
            ],
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _summary,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return TextButton.icon(
                  onPressed: () =>
                      setState(() => _summary = readAnnualAnalysis(_year)),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.tr('Chargement impossible. Réessayer')),
                );
              if (snapshot.connectionState != ConnectionState.done)
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              final entity = annualEntities(snapshot.data)[widget.entityPath];
              if (entity == null)
                return Text(context.tr('Aucun élément pour cette période.'));
              final values =
                  (_category ? entity['monthly'] : entity['closing']) as List;
              final spots = [
                if (!_category &&
                    entity['opening'] != null &&
                    (entity['unexplained'] as num).abs() <= .01)
                  FlSpot(0, (entity['opening'] as num).toDouble()),
                for (var m = 0; m < values.length; m++)
                  if (values[m] != null)
                    FlSpot(m + 1.0, (values[m] as num).toDouble()),
              ];
              final low = spots.isEmpty
                  ? 0.0
                  : spots.map((p) => p.y).reduce(math.min);
              final high = spots.isEmpty
                  ? 1.0
                  : spots.map((p) => p.y).reduce(math.max);
              final padding = math.max(1.0, (high - low) * .12);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _value(
                    context.tr(
                      _category
                          ? 'Total annuel'
                          : 'Valeur à la date du rapport',
                    ),
                    money(entity['current'] as num?),
                  ),
                  if (_category)
                    _value(
                      context.tr('Année précédente, même période'),
                      money(entity['previous'] as num?),
                    ),
                  if (!_category) ...[
                    _value(
                      context.tr('Au 1er janvier'),
                      money(entity['opening'] as num?),
                    ),
                    Text(
                      context.tr(
                        entity['estimated'] == true
                            ? 'Valeur reconstituée, à confirmer'
                            : 'Référence renseignée',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  _value(
                    context.tr('Évolution annuelle'),
                    percent(entity['percent'] as num?),
                  ),
                  if (!_category) ...[
                    _value(
                      context.tr('Variation'),
                      money(entity['delta'] as num?),
                    ),
                    if ((entity['unexplained'] as num).abs() > .01)
                      Text(
                        context.trParams('Écart non historisé : {amount}', {
                          'amount': money(entity['unexplained'] as num),
                        }),
                      ),
                    if (_investment) ...[
                      Text(
                        context.trParams(
                          'Versements nets : {flows} · Valorisation : {value}',
                          {
                            'flows': money(entity['netFlows'] as num),
                            'value': money(entity['valuationChange'] as num?),
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                          'La variation inclut les versements et retraits : ce n’est pas un rendement financier.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _reference(entity),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(
                          context.tr('Renseigner la référence annuelle'),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                      _category
                          ? 'Totaux mensuels (UTC)'
                          : 'Clôtures mensuelles et période en cours (UTC)',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  if (hidden)
                    SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(context.tr('Montants masques')),
                      ),
                    ),
                  if (!hidden && spots.length < 2)
                    Text(
                      context.tr(
                        'Historique insuffisant pour tracer une courbe.',
                      ),
                    ),
                  if (!hidden && spots.length >= 2)
                    SizedBox(
                      height: 220,
                      child: AppLineChart(
                        LineChartData(
                          minX: 0,
                          maxX: 12,
                          minY: low - padding,
                          maxY: high + padding,
                          lineTouchData: LineTouchData(enabled: false),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(drawVerticalLine: false),
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                interval: (high - low + 2 * padding) / 4,
                                getTitlesWidget: (value, _) => Text(
                                  NumberFormat.compact(
                                    locale: locale,
                                  ).format(value),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 3,
                                reservedSize: 28,
                                getTitlesWidget: (value, _) => Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    value == 0
                                        ? '01/01'
                                        : DateFormat.MMM(locale).format(
                                            DateTime(_year, value.toInt()),
                                          ),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              color: Theme.of(context).colorScheme.primary,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  for (var m = 0; m < values.length; m++)
                    _value(
                      DateFormat.MMMM(locale).format(DateTime(_year, m + 1)),
                      money(values[m] as num?),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _value(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(title)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
