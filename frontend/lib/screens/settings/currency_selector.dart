import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/screens/settings/currency_provider.dart';

class CurrencySelector extends StatelessWidget {
  final String? initialCurrencyCode;
  final void Function(String currencyCode)? onCurrencyChanged;

  const CurrencySelector({
    super.key,
    this.initialCurrencyCode,
    this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CurrencyProvider>(context);
    final selectedCode = CurrencyProvider.normalizeCurrencyCode(
      initialCurrencyCode ?? provider.currencyCode,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: DropdownButtonFormField<String>(
        value: selectedCode,
        decoration: InputDecoration(
          labelText: context.tr('Devise'),
          border: const OutlineInputBorder(),
        ),
        items: CurrencyProvider.currencies.map((currency) {
          return DropdownMenuItem(
            value: currency.code,
            child: Text(currency.label),
          );
        }).toList(),
        onChanged: (value) async {
          if (value == null) return;
          await provider.setCurrency(value);
          onCurrencyChanged?.call(value);
        },
      ),
    );
  }
}
