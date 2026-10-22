import 'package:flutter/material.dart';

class InvestmentTypeOption {
  final String value;
  final String label;
  final IconData icon;

  const InvestmentTypeOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

const investmentTypeOptions = [
  InvestmentTypeOption(
    value: 'stock',
    label: 'Actions',
    icon: Icons.show_chart_outlined,
  ),
  InvestmentTypeOption(
    value: 'etf',
    label: 'ETF',
    icon: Icons.stacked_line_chart_outlined,
  ),
  InvestmentTypeOption(
    value: 'crypto',
    label: 'Crypto',
    icon: Icons.currency_bitcoin_outlined,
  ),
  InvestmentTypeOption(
    value: 'bond',
    label: 'Obligations',
    icon: Icons.account_balance_outlined,
  ),
  InvestmentTypeOption(
    value: 'other',
    label: 'Autres',
    icon: Icons.category_outlined,
  ),
];

InvestmentTypeOption investmentTypeOption(String? value) {
  return investmentTypeOptions.firstWhere(
    (option) => option.value == value,
    orElse: () => investmentTypeOptions.last,
  );
}
