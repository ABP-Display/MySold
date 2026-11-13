import 'dart:convert';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/app_page_tab_menu.dart';
import 'package:mysold/services/security_gate.dart';

class AnnualEvolutionPage extends StatefulWidget {
  const AnnualEvolutionPage({super.key});
  @override
  State<AnnualEvolutionPage> createState() => _AnnualEvolutionPageState();
}

class _AnnualEvolutionPageState extends State<AnnualEvolutionPage> {
  int _year = DateTime.now().year, _tab = 0;
  late Future<Map<String, dynamic>> _data;
  static const _labels = ['Comptes', 'Catégories', 'Investissements'];
  static const _kinds = ['accounts', 'categories', 'investments'];
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = DocumentStore.instance.read('analysis/annual', {
      'year': _year,
      'day': DateTime.now().toUtc().toIso8601String().substring(0, 10),
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
    String value = '';
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
              final n = double.tryParse((text ?? '').replaceAll(',', '.'));
              return n == null || !n.isFinite || n.abs() > 1e12
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
                    (value.isEmpty ? entity['opening'].toString() : value)
                        .replaceAll(',', '.'),
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
          .convert(utf8.encode('${entity['path']}:$_year'))
          .toString();
      await DocumentStore.instance
          .collection('users')
          .doc(LocalAuth.instance.currentUser!.uid)
          .collection('annualReferences')
          .doc(id)
          .set({'entityPath': entity['path'], 'year': _year, 'amount': amount});
      if (mounted) setState(_load);
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
    String money(num? value) => hidden
        ? '••••'
        : value == null
        ? '—'
        : NumberFormat.currency(
            locale: Localizations.localeOf(context).toString(),
            symbol: currency,
          ).format(value);
    return Scaffold(
      extendBody: true,
      appBar: appPageBar(
        context,
        title: Text(context.tr('Évolution annuelle')),
      ),
      bottomNavigationBar: AppPageTabMenu(
        labels: _labels.map(context.tr).toList(),
        icons: const [
          Icons.account_balance_wallet_outlined,
          Icons.category_outlined,
          Icons.trending_up,
        ],
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
        keyPrefix: 'annual-evolution',
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: context.tr('Année précédente'),
                onPressed: _year > 1900
                    ? () => setState(() {
                        _year--;
                        _load();
                      })
                    : null,
                icon: Icon(Icons.chevron_left),
              ),
              Text('$_year', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                tooltip: context.tr('Année suivante'),
                onPressed: _year < DateTime.now().year
                    ? () => setState(() {
                        _year++;
                        _load();
                      })
                    : null,
                icon: Icon(Icons.chevron_right),
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(
                    child: TextButton.icon(
                      onPressed: () => setState(_load),
                      icon: Icon(Icons.refresh),
                      label: Text(
                        context.tr('Chargement impossible. Réessayer'),
                      ),
                    ),
                  );
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final rows = (snapshot.data!['entities'] as List)
                    .cast<Map<String, dynamic>>()
                    .where((e) => e['kind'] == _kinds[_tab])
                    .toList();
                if (rows.isEmpty)
                  return Center(
                    child: Text(
                      context.tr('Aucun élément pour cette période.'),
                    ),
                  );
                return ListView.builder(
                  key: PageStorageKey('evolution-$_year-$_tab'),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    AppPageTabMenu.clearance(
                          context,
                          _labels.map(context.tr).toList(),
                        ) +
                        24,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final e = rows[index];
                    final category = _tab == 1;
                    final values =
                        (category ? e['monthly'] : e['closing']) as List;
                    final spots = [
                      for (var m = 0; m < values.length; m++)
                        if (values[m] != null)
                          FlSpot(m.toDouble(), (values[m] as num).toDouble()),
                    ];
                    return ExpansionTile(
                      key: ValueKey('${e['path']}-$_year'),
                      title: Text(e['name'] as String),
                      subtitle: Text(
                        '${context.tr(category ? 'Total annuel' : 'Valeur à la date du rapport')} : ${money(e['current'] as num)}',
                      ),
                      childrenPadding: const EdgeInsets.all(12),
                      children: [
                        if (category)
                          Text(
                            context.trParams(
                              'Année précédente, même période : {amount} · Écart : {percent}',
                              {
                                'amount': money(e['previous'] as num?),
                                'percent': hidden
                                    ? '••••'
                                    : e['percent'] == null
                                    ? context.tr('Non calculable')
                                    : '${e['percent']} %',
                              },
                            ),
                          ),
                        if (!category) ...[
                          ListTile(
                            title: Text(context.tr('Au 1er janvier')),
                            subtitle: Text(
                              context.tr(
                                e['estimated'] == true
                                    ? 'Valeur reconstituée, à confirmer'
                                    : 'Référence renseignée',
                              ),
                            ),
                            trailing: Text(money(e['opening'] as num?)),
                          ),
                          Text(
                            context
                                .trParams('Variation : {amount} · {percent}', {
                                  'amount': money(e['delta'] as num?),
                                  'percent': hidden
                                      ? '••••'
                                      : e['percent'] == null
                                      ? context.tr('Non calculable')
                                      : '${e['percent']} %',
                                }),
                          ),
                          if ((e['unexplained'] as num).abs() > 0.01)
                            Text(
                              context.trParams(
                                'Écart non historisé : {amount}',
                                {'amount': money(e['unexplained'] as num)},
                              ),
                            ),
                          if (_tab == 2)
                            Text(
                              context.trParams(
                                'Versements nets : {flows} · Valorisation : {value}',
                                {
                                  'flows': money(e['netFlows'] as num),
                                  'value': money(e['valuationChange'] as num?),
                                },
                              ),
                            ),
                          if (_tab == 2)
                            Text(
                              context.tr(
                                'La variation inclut les versements et retraits : ce n’est pas un rendement financier.',
                              ),
                            ),
                          TextButton.icon(
                            onPressed: () => _reference(e),
                            icon: Icon(Icons.edit_outlined),
                            label: Text(
                              context.tr('Renseigner la référence annuelle'),
                            ),
                          ),
                        ],
                        Text(
                          context.tr(
                            'Clôtures mensuelles et période en cours (UTC)',
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
                            height: 170,
                            child: LineChart(
                              LineChartData(
                                lineTouchData: LineTouchData(enabled: false),
                                titlesData: FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    dotData: FlDotData(show: false),
                                  ),
                                ],
                              ),
                              duration: Duration.zero,
                            ),
                          ),
                        for (var m = 0; m < values.length; m++)
                          ListTile(
                            dense: true,
                            title: Text(
                              DateFormat.MMMM(
                                Localizations.localeOf(context).toString(),
                              ).format(DateTime(_year, m + 1)),
                            ),
                            trailing: Text(money(values[m] as num?)),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
