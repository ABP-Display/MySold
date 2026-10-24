import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/screens/settings/language_provider.dart';

class LanguageSelector extends StatelessWidget {
  final String? initialLanguageCode;
  final void Function(String languageCode)? onLanguageChanged;

  const LanguageSelector({
    super.key,
    this.initialLanguageCode,
    this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LanguageProvider>(context);
    final selectedCode = LanguageProvider.normalizeLanguageCode(
      initialLanguageCode ?? provider.languageCode,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: selectedCode,
        decoration: InputDecoration(
          labelText: context.tr('Langue'),
          border: const OutlineInputBorder(),
        ),
        items: LanguageProvider.languages.map((language) {
          return DropdownMenuItem(
            value: language.code,
            child: Text(
              language.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (value) async {
          if (value == null) return;
          await provider.setLanguage(value);
          onLanguageChanged?.call(value);
        },
      ),
    );
  }
}
