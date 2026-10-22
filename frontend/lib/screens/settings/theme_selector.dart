import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/screens/settings/theme_provider.dart';
import 'package:mysold/screens/settings/theme_settings.dart';

class ThemeSelector extends StatelessWidget {
  final String? initialTheme;
  final void Function(String themeName)? onThemeChanged;

  const ThemeSelector({
    super.key,
    this.initialTheme,
    this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ThemeProvider>(context);
    final selectedTheme = AppThemes.normalizeThemeName(
      initialTheme ?? provider.themeName,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: DropdownButtonFormField<String>(
        value: selectedTheme,
        decoration: InputDecoration(
          labelText: context.tr('Theme'),
          border: const OutlineInputBorder(),
        ),
        items: AppThemes.themes.keys.map((name) {
          return DropdownMenuItem(value: name, child: Text(name));
        }).toList(),
        onChanged: (value) async {
          if (value == null) return;
          await provider.setTheme(value);
          onThemeChanged?.call(value);
        },
      ),
    );
  }
}
