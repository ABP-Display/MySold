import 'package:flutter/material.dart';
import 'package:mysold/models/simulation_projection.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/app_select_field.dart';
import 'package:mysold/widgets/app_selection_button.dart';
import 'package:mysold/widgets/lazy_page_stack.dart';
import 'package:mysold/widgets/graphiques/simulation_chart.dart';

class SimulationWorkspace extends StatefulWidget {
  final String currency;
  final bool withBack;
  const SimulationWorkspace({
    super.key,
    required this.currency,
    this.withBack = false,
  });
  @override
  State<SimulationWorkspace> createState() => _SimulationWorkspaceState();
}

class _SimulationWorkspaceState extends State<SimulationWorkspace> {
  final _tabs = ValueNotifier<int>(0);
  final _budgetForm = GlobalKey<FormState>();
  final _investForm = GlobalKey<FormState>();
  final _loanForm = GlobalKey<FormState>();
  final _initial = TextEditingController(text: '1000');
  final _income = TextEditingController(text: '2000');
  final _expenses = TextEditingController(text: '1500');
  final _months = TextEditingController(text: '12');
  final _payment = TextEditingController(text: '500');
  final _return = TextEditingController(text: '5');
  final _investYears = TextEditingController(text: '10');
  final _project = TextEditingController(text: '200000');
  final _deposit = TextEditingController(text: '20000');
  final _loanRate = TextEditingController(text: '3.5');
  final _loanYears = TextEditingController(text: '20');
  final _fees = TextEditingController(text: '0');
  final _insurance = TextEditingController(text: '0');
  int _frequency = 12;
  bool _budgetDirty = false, _investDirty = false, _loanDirty = false;
  late BudgetProjection _budget = BudgetProjection.calculate(
    initial: 1000,
    monthlyIncome: 2000,
    monthlyExpenses: 1500,
    months: 12,
  );
  late InvestmentProjection _invest = InvestmentProjection.calculate(
    payment: 500,
    annualRate: 5,
    years: 10,
    paymentsPerYear: 12,
  );
  late LoanProjection _loan = LoanProjection.calculate(
    projectAmount: 200000,
    deposit: 20000,
    annualRate: 3.5,
    months: 240,
  );

  @override
  void dispose() {
    _tabs.dispose();
    for (final controller in [
      _initial,
      _income,
      _expenses,
      _months,
      _payment,
      _return,
      _investYears,
      _project,
      _deposit,
      _loanRate,
      _loanYears,
      _fees,
      _insurance,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    // Allow long labels to wrap without shrinking text on narrow screens.
    final measurement =
        TextPainter(
          text: TextSpan(text: 'Investissement', style: labelStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
          maxWidth: (MediaQuery.sizeOf(context).width / 3 - 16).clamp(
            1,
            double.infinity,
          ),
        );
    final tabHeight = (measurement.height + 20).clamp(56.0, double.infinity);
    measurement.dispose();
    // Keep the same page widgets when only the selected tab changes. Form
    // edits and recalculation still rebuild them through this state's setState.
    final pages = [_budgetPage(), _investPage(), _loanPage()];
    const labels = ['Budget', 'Investissement', 'Prêt'];
    return Scaffold(
      appBar: appPageBar(
        context,
        leading: widget.withBack ? const BackButton() : null,
        title: const Text('Simulation'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(tabHeight),
          child: ValueListenableBuilder<int>(
            valueListenable: _tabs,
            builder: (context, selected, _) => SizedBox(
              key: const ValueKey('simulation-tabs'),
              height: tabHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < labels.length; index++)
                    Expanded(
                      child: AppSelectionButton(
                        key: ValueKey('simulation-tab-$index'),
                        selected: selected == index,
                        isTab: true,
                        outlined: false,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () => _tabs.value = index,
                        child: Center(
                          child: Text(
                            labels[index],
                            style: labelStyle,
                            textAlign: TextAlign.center,
                            softWrap: true,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: _tabs,
        builder: (context, selected, _) =>
            LazyPageStack(index: selected, children: pages),
      ),
    );
  }

  double? _parse(String text) => double.tryParse(
    text
        .trim()
        .replaceAll(RegExp(r'[\s\u00a0\u202f]'), '')
        .replaceAll(',', '.'),
  );
  double _value(TextEditingController controller) => _parse(controller.text)!;
  Widget _field(
    String label,
    TextEditingController controller, {
    String? suffix,
    String? helper,
    double min = 0,
    double max = 1e12,
    bool integer = false,
    String? Function(double value)? extra,
  }) => TextFormField(
    key: ValueKey(label),
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      helperText: helper,
      helperMaxLines: 3,
      errorMaxLines: 3,
    ),
    validator: (text) {
      final number = _parse(text ?? '');
      if (number == null || !number.isFinite)
        return 'Saisissez un nombre valide.';
      if (number < min || number > max)
        return 'Valeur attendue entre $min et $max.';
      if (integer && number != number.roundToDouble())
        return 'Saisissez un nombre entier.';
      return extra?.call(number);
    },
  );

  Widget _fields(List<Widget> fields) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 520 &&
          MediaQuery.textScalerOf(context).scale(14) < 24;
      final width = columns
          ? (constraints.maxWidth - 16) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 20,
        children: [
          for (final field in fields) SizedBox(width: width, child: field),
        ],
      );
    },
  );

  Widget _formPanel(
    GlobalKey<FormState> key,
    List<Widget> fields,
    VoidCallback calculate,
    VoidCallback changed,
    bool dirty,
  ) => AppPanel(
    child: Form(
      key: key,
      onChanged: changed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fields(fields),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: calculate,
            icon: const Icon(Icons.calculate_outlined, size: 20),
            label: const Text('Calculer la simulation'),
          ),
          if (dirty) ...[
            const SizedBox(height: 10),
            Text(
              'Paramètres modifiés : recalculez pour actualiser le résultat.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
  );

  Widget _page(
    String key,
    String title,
    String subtitle,
    List<Widget> children,
  ) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1040),
      child: ListView(
        key: PageStorageKey(key),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          PageIntro(title: title, subtitle: subtitle, eyebrow: 'PROJECTION'),
          for (final child in children)
            Padding(padding: const EdgeInsets.only(bottom: 20), child: child),
        ],
      ),
    ),
  );

  Widget _result(String title, Widget chart, List<(String, double)> metrics) =>
      AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            _fields([
              for (final metric in metrics)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.$1,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      simulationMoney(metric.$2, widget.currency),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
            ]),
            const SizedBox(height: 24),
            chart,
          ],
        ),
      );

  Widget _budgetPage() {
    final colors = Theme.of(context).colorScheme;
    return _page(
      'simulation-budget',
      'Budget prévisionnel',
      'Visualisez votre épargne et le cumul de vos revenus et dépenses.',
      [
        _formPanel(
          _budgetForm,
          [
            _field('Épargne de départ', _initial, suffix: widget.currency),
            _field('Durée en mois', _months, min: 1, max: 600, integer: true),
            _field('Revenus mensuels', _income, suffix: widget.currency),
            _field('Dépenses mensuelles', _expenses, suffix: widget.currency),
          ],
          _calculateBudget,
          () {
            if (!_budgetDirty) setState(() => _budgetDirty = true);
          },
          _budgetDirty,
        ),
        _result(
          'Projection sur ${_budget.savings.length - 1} mois',
          SimulationLineChart(
            currency: widget.currency,
            series: [
              SimulationSeries('Épargne', _budget.savings, colors.primary),
              SimulationSeries(
                'Revenus cumulés',
                _budget.income,
                colors.tertiary,
              ),
              SimulationSeries(
                'Dépenses cumulées',
                _budget.expenses,
                colors.error,
              ),
            ],
          ),
          [
            ('Épargne finale', _budget.savings.last),
            (
              'Évolution de l’épargne',
              _budget.savings.last - _budget.savings.first,
            ),
          ],
        ),
      ],
    );
  }

  Widget _investPage() {
    final colors = Theme.of(context).colorScheme;
    return _page(
      'simulation-investment',
      'Investissement',
      'Comparez vos versements à une projection avec intérêts composés.',
      [
        _formPanel(
          _investForm,
          [
            _field('Versement périodique', _payment, suffix: widget.currency),
            AppSelectField<int>(
              label: 'Fréquence des versements',
              icon: Icons.repeat,
              value: _frequency,
              options: const [
                AppSelectOption(value: 365, label: 'Chaque jour'),
                AppSelectOption(value: 52, label: 'Chaque semaine'),
                AppSelectOption(value: 24, label: 'Deux fois par mois'),
                AppSelectOption(value: 12, label: 'Chaque mois'),
                AppSelectOption(value: 1, label: 'Chaque année'),
              ],
              onChanged: (value) => setState(() {
                _frequency = value!;
                _investDirty = true;
              }),
            ),
            _field('Rendement annuel estimé', _return, suffix: '%', max: 100),
            _field(
              'Durée en années',
              _investYears,
              min: 1,
              max: 100,
              integer: true,
            ),
          ],
          _calculateInvestment,
          () {
            if (!_investDirty) setState(() => _investDirty = true);
          },
          _investDirty,
        ),
        _result(
          'Projection sur ${_invest.value.length - 1} ans',
          SimulationLineChart(
            currency: widget.currency,
            annual: true,
            series: [
              SimulationSeries(
                'Versements cumulés',
                _invest.contributions,
                colors.secondary,
              ),
              SimulationSeries(
                'Capital projeté',
                _invest.value,
                colors.primary,
              ),
            ],
          ),
          [
            ('Capital final estimé', _invest.value.last),
            ('Gains estimés', _invest.value.last - _invest.contributions.last),
          ],
        ),
        Text(
          'Hypothèse : taux annuel nominal constant, capitalisation à chaque versement et versements en fin de période. Projection hors fiscalité et frais ; le rendement réel peut varier.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _loanPage() {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    return _page(
      'simulation-loan',
      'Prêt',
      'Estimez vos mensualités et visualisez le coût total de votre projet.',
      [
        _formPanel(
          _loanForm,
          [
            _field(
              'Montant total du projet',
              _project,
              suffix: widget.currency,
              min: .01,
              helper: 'L’apport sera déduit pour calculer le capital emprunté.',
            ),
            _field(
              'Apport personnel',
              _deposit,
              suffix: widget.currency,
              extra: (value) {
                final project = _parse(_project.text);
                return project != null && value >= project
                    ? 'L’apport doit être inférieur au montant du projet.'
                    : null;
              },
            ),
            _field('Taux d’intérêt annuel', _loanRate, suffix: '%', max: 100),
            _field(
              'Durée du prêt en années',
              _loanYears,
              min: 1,
              max: 50,
              integer: true,
            ),
            _field(
              'Frais de dossier et autres frais',
              _fees,
              suffix: widget.currency,
              helper: 'Frais payés au départ, non financés par le prêt.',
            ),
            _field(
              'Assurance annuelle facultative',
              _insurance,
              suffix: '%',
              max: 100,
              helper: 'Taux appliqué au capital initial emprunté. 0 si aucune.',
            ),
          ],
          _calculateLoan,
          () {
            if (!_loanDirty) setState(() => _loanDirty = true);
          },
          _loanDirty,
        ),
        _result(
          'Financement sur ${_loan.months ~/ 12} ans',
          SimulationCostChart(
            currency: widget.currency,
            parts: [
              SimulationCostPart(
                'Apport personnel',
                _loan.deposit,
                colors.tertiary,
              ),
              SimulationCostPart(
                'Capital emprunté',
                _loan.principal,
                colors.primary,
              ),
              SimulationCostPart(
                'Intérêts',
                _loan.interest,
                dark ? const Color(0xFFF1B86A) : const Color(0xFF9C6100),
              ),
              SimulationCostPart(
                'Assurance',
                _loan.insurance,
                dark ? const Color(0xFFBCA8EB) : const Color(0xFF7254AD),
              ),
              SimulationCostPart('Frais renseignés', _loan.fees, colors.error),
            ],
          ),
          [
            ('Mensualité avec assurance', _loan.monthlyTotal),
            ('Capital à emprunter', _loan.principal),
            ('Coût du crédit (intérêts + assurance + frais)', _loan.creditCost),
            ('Total versé, apport inclus', _loan.totalWithDeposit),
          ],
        ),
        Text(
          'Calcul à taux fixe nominal avec mensualités constantes. L’assurance est calculée sur le capital initial. Le total inclut uniquement les frais renseignés ; les montants affichés sont arrondis au centime.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _calculateBudget() {
    if (!_budgetForm.currentState!.validate()) return;
    setState(() {
      _budget = BudgetProjection.calculate(
        initial: _value(_initial),
        monthlyIncome: _value(_income),
        monthlyExpenses: _value(_expenses),
        months: _value(_months).toInt(),
      );
      _budgetDirty = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _calculateInvestment() {
    if (!_investForm.currentState!.validate()) return;
    setState(() {
      _invest = InvestmentProjection.calculate(
        payment: _value(_payment),
        annualRate: _value(_return),
        years: _value(_investYears).toInt(),
        paymentsPerYear: _frequency,
      );
      _investDirty = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _calculateLoan() {
    if (!_loanForm.currentState!.validate()) return;
    setState(() {
      _loan = LoanProjection.calculate(
        projectAmount: _value(_project),
        deposit: _value(_deposit),
        annualRate: _value(_loanRate),
        months: _value(_loanYears).toInt() * 12,
        fees: _value(_fees),
        annualInsuranceRate: _value(_insurance),
      );
      _loanDirty = false;
    });
    FocusScope.of(context).unfocus();
  }
}
