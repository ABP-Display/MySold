import 'package:mysold/models/transaction_model.dart';

const chartFixtureCategories = <String, Map<String, dynamic>>{
  'ct': {'name': 'CT', 'color': 0xffd85050},
  'am': {'name': 'Assurance maison', 'color': 0xff21b6a8},
  'gas': {'name': 'Gaz', 'color': 0xffaa63c9},
  'gifts': {'name': 'Cadeaux', 'color': 0xffc47b9d},
  'power': {'name': 'Électricité', 'color': 0xffc58a53},
  'other': {'name': 'Autres achats', 'color': 0xff8098a8},
  'salary': {'name': 'Salaire', 'color': 0xff4caf50},
  'refund': {'name': 'Remboursements', 'color': 0xff21b6a8},
  'income-gifts': {'name': 'Cadeaux', 'color': 0xffaa63c9},
  'income-other': {'name': 'Autres revenus', 'color': 0xffe9b844},
};
const chartFixtureAccounts = {
  'current': 'Compte courant',
  'savings': 'Livret A',
  'securities': 'Compte-titres',
};
const chartFixtureInvestments = {
  'etf': 'ETF Monde',
  'stock': 'Actions',
  'crypto': 'Bitcoin',
};
const chartFixtureTypes = {'etf': 'etf', 'stock': 'stock', 'crypto': 'crypto'};

List<TransactionModel> monthChartFixture() {
  final result = <TransactionModel>[];
  void add(
    String type,
    double amount,
    int day, {
    String? category,
    String? asset,
    String? target,
  }) {
    result.add(
      TransactionModel(
        id: 'fixture-${result.length}',
        amount: amount,
        date: DateTime(2026, 6, day),
        description: category ?? asset ?? 'Transfert',
        type: type,
        categoryId: category,
        investmentId: asset,
        fromAccountId: 'current',
        toAccountId: target,
      ),
    );
  }

  for (final item in [
    ('ct', 360.0),
    ('am', 170.0),
    ('gas', 70.0),
    ('gifts', 65.0),
    ('power', 59.0),
    ('other', 107.0),
  ]) {
    add('expense', item.$2, 4, category: item.$1);
  }
  for (final item in [
    ('salary', 1225.80),
    ('refund', 79.13),
    ('income-gifts', 75.0),
    ('income-other', 58.37),
  ]) {
    add('income', item.$2, 5, category: item.$1);
  }
  for (final item in [
    (1, 'etf', 50.0),
    (2, 'stock', 30.0),
    (3, 'crypto', 20.0),
    (8, 'etf', 50.0),
    (9, 'stock', 20.0),
    (10, 'crypto', 10.0),
    (11, 'etf', 30.0),
    (11, 'stock', 20.0),
    (12, 'crypto', 20.0),
    (15, 'etf', 40.0),
    (16, 'stock', 30.0),
    (17, 'crypto', 20.0),
    (22, 'etf', 35.0),
    (23, 'stock', 30.0),
    (24, 'crypto', 15.0),
    (29, 'etf', 15.0),
    (30, 'stock', 10.0),
    (30, 'crypto', 5.0),
  ]) {
    add('investment', item.$3, item.$1, asset: item.$2);
  }
  add('transfer', 400, 8, target: 'savings');
  add('transfer', 250, 12, target: 'securities');
  return result;
}
