import 'package:flutter/material.dart';
import 'package:mysold/models/investment_type.dart';
import 'app_select_field.dart';

List<AppSelectOption<String>> investmentAssetOptions(
  BuildContext context, {
  required Map<String, String> investments,
  required Map<String, String> assetTypes,
  required List<InvestmentTypeOption> categories,
}) => [
  for (final entry in investments.entries)
    () {
      final category = investmentTypeOption(
        assetTypes[entry.key],
        options: categories,
      );
      return AppSelectOption(
        value: entry.key,
        label: entry.value,
        subtitle: investmentCategoryLabel(context, category),
        icon: category.icon,
        color: category.color,
      );
    }(),
];
