import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/widgets/graphiques/dual_line_chart.dart';
import 'package:mysold/widgets/graphiques/triple_line_chart.dart';

double _round2(double v) => double.parse(v.toStringAsFixed(2));

class SimulationScreen extends StatefulWidget {
  final bool withBack;

  const SimulationScreen({super.key, this.withBack = false});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class CustomUnderlineTabIndicator extends Decoration {
  final Color color;
  final double height;

  const CustomUnderlineTabIndicator({required this.color, this.height = 4.0});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _CustomUnderlinePainter(color: color, height: height);
  }
}

class _CustomUnderlinePainter extends BoxPainter {
  final Color color;
  final double height;

  _CustomUnderlinePainter({required this.color, required this.height});

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = height;

    final double width = cfg.size!.width;
    final double left = offset.dx + (width * 0.1);
    final double right = offset.dx + (width * 0.9);
    final double y = offset.dy + cfg.size!.height - height / 2;

    canvas.drawLine(Offset(left, y), Offset(right, y), paint);
  }
}

class _SimulationScreenState extends State<SimulationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  // ---- Budget
  final _form1 = GlobalKey<FormState>();
  final _startCtrl = TextEditingController(text: '1000');
  final _incomeCtrl = TextEditingController(text: '2000');
  final _expenseCtrl = TextEditingController(text: '1500');
  final _monthsCtrl = TextEditingController(text: '12');
  List<double>? _resBudgetSolde;
  List<double>? _resBudgetRevenus;
  List<double>? _resBudgetDepenses;

  // ---- Investissement
  final _form2 = GlobalKey<FormState>();
  final _pmtCtrl = TextEditingController(text: '500');
  final _periodicity = ValueNotifier<String>('Mois');
  final _rateCtrl = TextEditingController(text: '5');
  final _yearsCtrl = TextEditingController(text: '10');
  List<double>? _resInvest;
  List<double>? _resBrut;
  int _years = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Simulation'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            alignment: Alignment.centerLeft,

            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              controller: _tabCtrl,
              isScrollable: false,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 12),
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              labelColor: Theme.of(context).colorScheme.onSurface,
              unselectedLabelColor: Theme.of(
                context,
                // ignore: deprecated_member_use
              ).colorScheme.onSurface.withOpacity(0.5),
              tabs: const [
                Tab(text: 'Budget'),
                Tab(text: 'Investissement'),
              ],
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              physics: const BouncingScrollPhysics(),
              children: [_budgetBody(), _investBody()],
            ),
          ),
        ],
      ),
    );
  }

  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  // ---------- Gestion UI ----------
  Widget _card({required Widget child}) => Card(
    color: Theme.of(context).cardColor,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );

  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outline,
        width: 1.0,
      ),
    ),
  );

  Widget _numField(String l, TextEditingController c, {bool isInt = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _input(l),
          validator: (v) => (v == null || v.isEmpty) ? 'Obligatoire' : null,
        ),
      );

  ElevatedButton _actionBtn(String txt, VoidCallback cb) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      minimumSize: const Size.fromHeight(48),
    ),
    onPressed: cb,
    child: Text(txt),
  );
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  // ---------- Onglet BUDGET ----------
  Widget _budgetBody() {
    final currency = Provider.of<CurrencyProvider>(context).currency;
    return ListView(
      children: [
        _card(
          child: Form(
            key: _form1,
            child: Column(
              children: [
                _numField('Epargne de départ ($currency)', _startCtrl),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _numField(
                        'Revenus mensuels ($currency)',
                        _incomeCtrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numField(
                        'Dépenses mensuelles ($currency)',
                        _expenseCtrl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _numField('Nombre de mois', _monthsCtrl, isInt: true),
                const SizedBox(height: 8),

                _actionBtn('Simuler', _runBudget),
              ],
            ),
          ),
        ),
        if (_resBudgetSolde != null &&
            _resBudgetRevenus != null &&
            _resBudgetDepenses != null)
          _card(
            child: Column(
              children: [
                TripleLineChart(
                  solde: _resBudgetSolde!,
                  revenus: _resBudgetRevenus!,
                  depenses: _resBudgetDepenses!,
                ),
                const SizedBox(height: 12),
                Text(
                  'Valeur après ${_resBudgetSolde!.length - 1} mois : '
                  '${NumberFormat.currency(locale: "fr_FR", symbol: "($currency)").format(_resBudgetSolde!.last)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.track_changes,
                      color: Theme.of(context).colorScheme.primary,
                    ), // Icône de l'objectif
                    const SizedBox(width: 8),
                    Text(
                      'Objectif',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Optimiser les dépenses pour maximiser l’épargne, puis utiliser une parti de cette épargne afin de simuler un investissement rentable.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _runBudget() {
    if (!_form1.currentState!.validate()) return;
    final s = double.parse(_startCtrl.text.replaceAll(',', '.'));
    final inc = double.parse(_incomeCtrl.text.replaceAll(',', '.'));
    final exp = double.parse(_expenseCtrl.text.replaceAll(',', '.'));
    final m = int.parse(_monthsCtrl.text);

    final res = _simBudget(s, inc, exp, m);
    _resBudgetSolde = res['solde'];
    _resBudgetRevenus = res['revenus'];
    _resBudgetDepenses = res['depenses'];
    setState(() {
      final res = _simBudget(s, inc, exp, m);
      _resBudgetSolde = res['solde'];
      _resBudgetRevenus = res['revenus'];
      _resBudgetDepenses = res['depenses'];
    });
  }

  Map<String, List<double>> _simBudget(
    double s,
    double inc,
    double exp,
    int m,
  ) {
    final List<double> solde = [s];
    final List<double> revenus = [0];
    final List<double> depenses = [0];

    for (int i = 1; i <= m; i++) {
      revenus.add(_round2(revenus.last + inc));
      depenses.add(_round2(depenses.last + exp));
      solde.add(_round2(solde.last + inc - exp));
    }

    return {'solde': solde, 'revenus': revenus, 'depenses': depenses};
  }

  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  // ---------- Onglet INVEST ----------
  Widget _investBody() {
    final currency = Provider.of<CurrencyProvider>(context).currency;
    return ListView(
      children: [
        _card(
          child: Form(
            key: _form2,
            child: Column(
              children: [
                // Ligne Versement + Taux
                Row(
                  children: [
                    Expanded(
                      child: _numField('Versement ($currency)', _pmtCtrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numField('Taux annuel ($currency)', _rateCtrl),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _periodicityDrop(),
                _numField('Durée (années)', _yearsCtrl, isInt: true),
                const SizedBox(height: 8),
                _actionBtn('Simuler', _runInvest),
              ],
            ),
          ),
        ),
        if (_resInvest != null && _resBrut != null)
          _card(
            child: Column(
              children: [
                DualLineChart(brute: _resBrut!, rendement: _resInvest!),
                const SizedBox(height: 12),
                Text(
                  'Valeur après $_years ans : '
                  '${NumberFormat.currency(locale: "fr_FR", symbol: "($currency)").format(_resInvest!.last)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.flag,
                      color: Theme.of(context).colorScheme.primary,
                    ), // Icône de l'objectif
                    const SizedBox(width: 8),
                    Text(
                      'Le savais-tu ?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '- L’ETF MSCI World : Affiche une performance moyenne d’environ 7-8% par an sur 25 ans.\n'
                  '- S&P 500 : Historiquement, cet indice a généré un rendement moyen d’environ 10-11% par an sur plusieurs décennies.\n'
                  '- Nasdaq-100 : Grâce aux géants de la tech, cet indice a souvent dépassé 15% par an sur les 20 dernières années.\n'
                  '- L’OR : A eu une performance moyenne d’environ 6-7% par an, mais avec de fortes variations.\n'
                  '- Le CAC 40 : Tourne autour de 5-6% par an sur 25 ans.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  '⚠️ Les performances passées ne garantissent pas les rendements futurs.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _runInvest() {
    if (!_form2.currentState!.validate()) return;

    final pmt = double.parse(_pmtCtrl.text.replaceAll(',', '.'));
    final rate = double.parse(_rateCtrl.text) / 100;
    final yrs = int.parse(_yearsCtrl.text);
    final freq = _freqPerYear(_periodicity.value);

    _years = yrs;
    _resBrut = _simBrut(pmt, yrs, freq);
    _resInvest = _simInvest(pmt, rate, yrs, freq);
    setState(() {});
  }

  int _freqPerYear(String p) =>
      {'Jour': 365, 'Semaine': 52, 'Bi-mensuel': 24, 'Mois': 12, 'An': 1}[p]!;

  List<double> _simBrut(double pmt, int yrs, int freq) {
    final peri = yrs * freq;
    List<double> lst = [0];
    for (int i = 1; i <= peri; i++) {
      lst.add(_round2(lst.last + pmt));
    }
    return lst;
  }

  List<double> _simInvest(double pmt, double rA, int yrs, int freq) {
    final peri = yrs * freq;
    final r = rA / freq;
    List<double> v = [0];
    for (int i = 1; i <= peri; i++) {
      v.add(_round2(v.last * (1 + r) + pmt));
    }
    return v;
  }

  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  //
  // ---------- Dropdown périodicité ----------
  Widget _periodicityDrop() => ValueListenableBuilder(
    valueListenable: _periodicity,
    builder: (_, val, __) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: val,
        decoration: _input('Périodicité'),
        borderRadius: BorderRadius.circular(18),
        items: const [
          DropdownMenuItem(value: 'Jour', child: Text('Jour')),
          DropdownMenuItem(value: 'Semaine', child: Text('Semaine')),
          DropdownMenuItem(value: 'Bi-mensuel', child: Text('Bi-mensuel')),
          DropdownMenuItem(value: 'Mois', child: Text('Mois')),
          DropdownMenuItem(value: 'An', child: Text('An')),
        ],
        onChanged: (v) => _periodicity.value = v!,
      ),
    ),
  );
}
