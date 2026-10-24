import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/models/simulation_projection.dart';

void main() {
  test(
    'Zero-rate loan includes deposit, insurance and upfront fees exactly once',
    () {
      final loan = LoanProjection.calculate(
        projectAmount: 100000,
        deposit: 20000,
        annualRate: 0,
        months: 120,
        fees: 1500,
        annualInsuranceRate: .3,
      );
      expect(loan.principal, 80000);
      expect(loan.monthlyPayment, closeTo(80000 / 120, 1e-8));
      expect(loan.monthlyInsurance, 20);
      expect(loan.interest, 0);
      expect(loan.insurance, 2400);
      expect(loan.creditCost, 3900);
      expect(loan.totalWithDeposit, 103900);
    },
  );

  test(
    'Fixed payment amortizes the whole capital and matches interest paid',
    () {
      final loan = LoanProjection.calculate(
        projectAmount: 200000,
        deposit: 20000,
        annualRate: 3.5,
        months: 240,
      );
      var balance = loan.principal, interest = 0.0;
      for (var month = 0; month < loan.months; month++) {
        final charge = balance * .035 / 12;
        interest += charge;
        balance += charge - loan.monthlyPayment;
      }
      expect(loan.monthlyPayment, closeTo(1043.93, .005));
      expect(balance, closeTo(0, 1e-5));
      expect(loan.interest, closeTo(interest, 1e-5));
      expect(
        loan.totalWithDeposit,
        closeTo(loan.deposit + loan.monthlyTotal * loan.months, 1e-5),
      );
    },
  );

  test('A larger deposit reduces both borrowing and interest', () {
    LoanProjection calculate(double deposit) => LoanProjection.calculate(
      projectAmount: 200000,
      deposit: deposit,
      annualRate: 3.5,
      months: 240,
    );
    expect(
      calculate(40000).monthlyPayment,
      lessThan(calculate(20000).monthlyPayment),
    );
    expect(calculate(40000).interest, lessThan(calculate(20000).interest));
  });

  test(
    'A nearly zero interest rate remains finite and approaches zero-rate payments',
    () {
      final loan = LoanProjection.calculate(
        projectAmount: 100000,
        deposit: 0,
        annualRate: 1e-12,
        months: 120,
      );
      expect(loan.monthlyPayment, closeTo(100000 / 120, 1e-7));
      expect(loan.interest, closeTo(0, 1e-5));
    },
  );

  test('Invalid loan parameters are rejected before calculation', () {
    for (final deposit in [-1.0, 100000.0, double.nan]) {
      expect(
        () => LoanProjection.calculate(
          projectAmount: 100000,
          deposit: deposit,
          annualRate: 3,
          months: 120,
        ),
        throwsArgumentError,
      );
    }
    for (final months in [0, 601]) {
      expect(
        () => LoanProjection.calculate(
          projectAmount: 100000,
          deposit: 0,
          annualRate: 3,
          months: months,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => LoanProjection.calculate(
        projectAmount: 100000,
        deposit: 0,
        annualRate: double.infinity,
        months: 120,
      ),
      throwsArgumentError,
    );
  });

  test('Budget includes month zero, cumulative flows and negative savings', () {
    final budget = BudgetProjection.calculate(
      initial: 1000,
      monthlyIncome: 500,
      monthlyExpenses: 1000,
      months: 3,
    );
    expect(budget.savings, [1000, 500, 0, -500]);
    expect(budget.income, [0, 500, 1000, 1500]);
    expect(budget.expenses, [0, 1000, 2000, 3000]);
  });

  test('Investment samples years while compounding each payment period', () {
    final investment = InvestmentProjection.calculate(
      payment: 100,
      annualRate: 12,
      years: 2,
      paymentsPerYear: 12,
    );
    expect(investment.contributions, [0, 1200, 2400]);
    expect(investment.value[1], closeTo(1268.25, .02));
    expect(investment.value.last, greaterThan(investment.contributions.last));
    final zero = InvestmentProjection.calculate(
      payment: 100,
      annualRate: 0,
      years: 2,
      paymentsPerYear: 365,
    );
    expect(zero.value, zero.contributions);
    expect(zero.value.length, 3);
  });
}
