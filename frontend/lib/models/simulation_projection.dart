import 'dart:math' as math;

double _money(double value) => (value * 100).roundToDouble() / 100;

void _amount(double value, String name, {bool positive = false}) {
  if (!value.isFinite ||
      value < 0 ||
      value > 1e12 ||
      (positive && value == 0)) {
    throw ArgumentError.value(value, name, 'Montant invalide');
  }
}

class BudgetProjection {
  final List<double> savings, income, expenses;
  const BudgetProjection._(this.savings, this.income, this.expenses);
  factory BudgetProjection.calculate({
    required double initial,
    required double monthlyIncome,
    required double monthlyExpenses,
    required int months,
  }) {
    _amount(initial, 'initial');
    _amount(monthlyIncome, 'monthlyIncome');
    _amount(monthlyExpenses, 'monthlyExpenses');
    if (months < 1 || months > 600) throw ArgumentError.value(months, 'months');
    final savings = [_money(initial)], income = [0.0], expenses = [0.0];
    for (var month = 1; month <= months; month++) {
      income.add(_money(income.last + monthlyIncome));
      expenses.add(_money(expenses.last + monthlyExpenses));
      savings.add(_money(savings.last + monthlyIncome - monthlyExpenses));
    }
    return BudgetProjection._(savings, income, expenses);
  }
}

class InvestmentProjection {
  /// Annual samples; contributions are made at the end of each payment period.
  final List<double> contributions, value;
  const InvestmentProjection._(this.contributions, this.value);
  factory InvestmentProjection.calculate({
    required double payment,
    required double annualRate,
    required int years,
    required int paymentsPerYear,
  }) {
    _amount(payment, 'payment');
    if (!annualRate.isFinite || annualRate < 0 || annualRate > 100) {
      throw ArgumentError.value(annualRate, 'annualRate');
    }
    if (years < 1 || years > 100) throw ArgumentError.value(years, 'years');
    if (![1, 12, 24, 52, 365].contains(paymentsPerYear)) {
      throw ArgumentError.value(paymentsPerYear, 'paymentsPerYear');
    }
    final contributions = [0.0], values = [0.0];
    var value = 0.0, paid = 0.0;
    final periodicRate = annualRate / 100 / paymentsPerYear;
    for (var year = 1; year <= years; year++) {
      for (var period = 0; period < paymentsPerYear; period++) {
        paid = _money(paid + payment);
        value = _money(value * (1 + periodicRate) + payment);
      }
      if (!value.isFinite) throw ArgumentError('Projection trop élevée');
      contributions.add(paid);
      values.add(value);
    }
    return InvestmentProjection._(contributions, values);
  }
}

class LoanProjection {
  final double projectAmount, deposit, principal, monthlyPayment;
  final double monthlyInsurance, interest, insurance, fees;
  final int months;
  const LoanProjection._({
    required this.projectAmount,
    required this.deposit,
    required this.principal,
    required this.monthlyPayment,
    required this.monthlyInsurance,
    required this.interest,
    required this.insurance,
    required this.fees,
    required this.months,
  });

  double get monthlyTotal => monthlyPayment + monthlyInsurance;
  double get creditCost => interest + insurance + fees;
  double get totalWithDeposit => deposit + principal + creditCost;

  /// Fixed-rate, fully amortizing loan. Fees are paid upfront, not financed.
  /// Insurance is a fixed annual percentage of the original borrowed capital.
  factory LoanProjection.calculate({
    required double projectAmount,
    required double deposit,
    required double annualRate,
    required int months,
    double fees = 0,
    double annualInsuranceRate = 0,
  }) {
    _amount(projectAmount, 'projectAmount', positive: true);
    _amount(deposit, 'deposit');
    _amount(fees, 'fees');
    if (deposit >= projectAmount)
      throw ArgumentError('Apport supérieur ou égal au projet');
    if (months < 1 || months > 600) throw ArgumentError.value(months, 'months');
    for (final rate in [annualRate, annualInsuranceRate]) {
      if (!rate.isFinite || rate < 0 || rate > 100)
        throw ArgumentError.value(rate, 'rate');
    }
    final principal = projectAmount - deposit;
    final rate = annualRate / 1200;
    // Avoid cancellation in 1 - (1 + rate)^-months near a zero rate.
    final payment = rate < 1e-7
        ? principal /
              months *
              (1 +
                  (months + 1) * rate / 2 +
                  (months * months - 1) * rate * rate / 12)
        : principal * rate / (1 - math.pow(1 + rate, -months));
    final monthlyInsurance = principal * annualInsuranceRate / 1200;
    return LoanProjection._(
      projectAmount: projectAmount,
      deposit: deposit,
      principal: principal,
      monthlyPayment: payment,
      monthlyInsurance: monthlyInsurance,
      interest: math.max(0, payment * months - principal),
      insurance: monthlyInsurance * months,
      fees: fees,
      months: months,
    );
  }
}
