import 'package:flutter/material.dart';
import 'package:mysold/widgets/app_typography.dart';

class AppThemes {
  static const String defaultThemeName = 'Sombre';

  static final ThemeData dark = _buildTheme(
    brightness: Brightness.dark,
    seed: const Color(0xFFE5E7EB),
    scaffold: Colors.black,
    surface: const Color(0xFF070707),
    surfaceVariant: const Color(0xFF111111),
    primary: const Color(0xFFE5E7EB),
    onPrimary: Colors.black,
    secondary: const Color(0xFF9CA3AF),
    onSecondary: Colors.black,
    onSurface: const Color(0xFFEDEDED),
    outline: const Color(0xFF4B5563),
  );

  static final ThemeData light = _buildTheme(
    brightness: Brightness.light,
    seed: const Color(0xFF2563EB),
    scaffold: const Color(0xFFF6F8FC),
    surface: Colors.white,
    surfaceVariant: const Color(0xFFE8EEF8),
    primary: const Color(0xFF2563EB),
    onPrimary: Colors.white,
    secondary: const Color(0xFF0F766E),
    onSecondary: Colors.white,
    onSurface: const Color(0xFF141821),
    outline: const Color(0xFF7A8496),
  );

  static final ThemeData forest = _buildTheme(
    brightness: Brightness.dark,
    seed: const Color(0xFF7EBA8A),
    scaffold: const Color(0xFF0F1511),
    surface: const Color(0xFF171F19),
    surfaceVariant: const Color(0xFF243028),
    primary: const Color(0xFF9CCFA4),
    onPrimary: const Color(0xFF102517),
    secondary: const Color(0xFFE3C16F),
    onSecondary: const Color(0xFF332600),
    onSurface: const Color(0xFFE6EEE8),
    outline: const Color(0xFF788879),
  );

  static final ThemeData ocean = _buildTheme(
    brightness: Brightness.dark,
    seed: const Color(0xFF69C9D6),
    scaffold: const Color(0xFF0B1418),
    surface: const Color(0xFF111D22),
    surfaceVariant: const Color(0xFF1B3037),
    primary: const Color(0xFF7AD7E4),
    onPrimary: const Color(0xFF00343B),
    secondary: const Color(0xFFFFB86B),
    onSecondary: const Color(0xFF3D2500),
    onSurface: const Color(0xFFE4EEF1),
    outline: const Color(0xFF6F8990),
  );

  static final ThemeData graphite = _buildTheme(
    brightness: Brightness.light,
    seed: const Color(0xFF475569),
    scaffold: const Color(0xFFF4F5F7),
    surface: Colors.white,
    surfaceVariant: const Color(0xFFE7E9ED),
    primary: const Color(0xFF475569),
    onPrimary: Colors.white,
    secondary: const Color(0xFFB45309),
    onSecondary: Colors.white,
    onSurface: const Color(0xFF151922),
    outline: const Color(0xFF7B8190),
  );

  static final ThemeData amethyst = _buildTheme(
    brightness: Brightness.dark,
    seed: const Color(0xFFC7A2FF),
    scaffold: const Color(0xFF15111B),
    surface: const Color(0xFF1E1826),
    surfaceVariant: const Color(0xFF2D2438),
    primary: const Color(0xFFC7A2FF),
    onPrimary: const Color(0xFF2B1748),
    secondary: const Color(0xFFFFB4A2),
    onSecondary: const Color(0xFF4A1E12),
    onSurface: const Color(0xFFF0E8F7),
    outline: const Color(0xFF8C7D98),
  );

  static final Map<String, ThemeData> themes = {
    defaultThemeName: dark,
    'Clair': light,
    'Graphite': graphite,
    'Foret': forest,
    'Ocean': ocean,
    'Amethyste': amethyst,
  };

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color seed,
    required Color scaffold,
    required Color surface,
    required Color surfaceVariant,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color onSurface,
    required Color outline,
  }) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
        .copyWith(
          primary: primary,
          onPrimary: onPrimary,
          secondary: secondary,
          onSecondary: onSecondary,
          surface: surface,
          surfaceVariant: surfaceVariant,
          onSurface: onSurface,
          outline: outline,
          error: brightness == Brightness.dark
              ? const Color(0xFFFFB4AB)
              : const Color(0xFFBA1A1A),
        );

    final base = ThemeData(
      fontFamily: AppTypography.family,
      fontFamilyFallback: AppTypography.fallback,
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: scaffold,
        foregroundColor: onSurface,
      ),
    );

    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceVariant.withOpacity(0.48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline.withOpacity(0.10)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: outline.withOpacity(0.32)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant.withOpacity(0.30),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline.withOpacity(0.28)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline.withOpacity(0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline.withOpacity(0.10),
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        textColor: onSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceVariant.withOpacity(0.75),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? primary : outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? primary.withOpacity(0.35)
              : outline.withOpacity(0.22);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF252A32)
            : onSurface,
        contentTextStyle: TextStyle(
          color: brightness == Brightness.dark ? onSurface : Colors.white,
        ),
      ),
    );
  }

  static String normalizeThemeName(String? name) {
    if (name == null || name.trim().isEmpty) return defaultThemeName;
    final cleaned = name.trim();

    const aliases = {
      'Cr\u00C3\u00A9puscule': defaultThemeName,
      'Cr\u00E9puscule': defaultThemeName,
      'Crepuscule': defaultThemeName,
      'Printemps': 'Foret',
      'Forêt': 'Foret',
      'Améthyste': 'Amethyste',
    };

    final normalized = aliases[cleaned] ?? cleaned;
    return themes.containsKey(normalized) ? normalized : defaultThemeName;
  }

  static ThemeData themeFor(String? name) {
    return themes[normalizeThemeName(name)] ?? dark;
  }
}
