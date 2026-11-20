import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';

String investmentCategoryLabel(
  BuildContext context,
  InvestmentTypeOption option,
) => option.builtInLabel ? context.tr(option.label) : option.label;

class InvestmentTypeOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const InvestmentTypeOption({
    required this.value,
    required this.label,
    required this.icon,
    this.color = const Color(0xff8a96a1),
  });

  bool get builtInLabel =>
      investmentTypeOptions.any((o) => o.value == value && o.label == label);
  Map<String, dynamic> toMap() => {
    'id': value,
    'name': label,
    'color': color.toARGB32(),
    'icon': icon.codePoint,
  };
}

const investmentTypeOptions = [
  InvestmentTypeOption(
    value: 'stock',
    label: 'Actions',
    icon: Icons.show_chart_outlined,
    color: Color(0xffc5a3da),
  ),
  InvestmentTypeOption(
    value: 'etf',
    label: 'ETF',
    icon: Icons.stacked_line_chart_outlined,
    color: Color(0xff8daee0),
  ),
  InvestmentTypeOption(
    value: 'crypto',
    label: 'Crypto',
    icon: Icons.currency_bitcoin_outlined,
    color: Color(0xffd5b778),
  ),
  InvestmentTypeOption(
    value: 'bond',
    label: 'Obligations',
    icon: Icons.account_balance_outlined,
    color: Color(0xff77b8ae),
  ),
  InvestmentTypeOption(
    value: 'other',
    label: 'Autres',
    icon: Icons.category_outlined,
  ),
];

InvestmentTypeOption investmentTypeOption(
  String? value, {
  List<InvestmentTypeOption> options = investmentTypeOptions,
}) {
  return options.firstWhere(
    (option) => option.value == value,
    orElse: () => options.firstWhere(
      (o) => o.value == 'other',
      orElse: () => investmentTypeOptions.last,
    ),
  );
}

List<InvestmentTypeOption> investmentCategoriesFromProfile(dynamic raw) {
  if (raw is! List) return investmentTypeOptions;
  final result = <InvestmentTypeOption>[];
  final ids = <String>{};
  for (final row in raw) {
    if (row is! Map ||
        row['id'] is! String ||
        row['name'] is! String ||
        row['color'] is! int ||
        row['icon'] is! int ||
        !ids.add(row['id']))
      continue;
    result.add(
      InvestmentTypeOption(
        value: row['id'],
        label: row['name'],
        color: Color(row['color']),
        // Icons are user-selected; release builds already keep the full font.
        // ignore: non_const_argument_for_const_parameter
        icon: IconData(row['icon'], fontFamily: 'MaterialIcons'),
      ),
    );
  }
  if (!ids.contains('other')) result.add(investmentTypeOptions.last);
  return List.unmodifiable(result);
}
