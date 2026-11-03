import 'package:mysold/widgets/app_page_transitions.dart';
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
          primaryContainer: Color.lerp(surface, primary, 0.14),
          onPrimaryContainer: onSurface,
          secondary: secondary,
          onSecondary: onSecondary,
          secondaryContainer: Color.lerp(surface, secondary, 0.14),
          onSecondaryContainer: onSurface,
          surface: surface,
          surfaceVariant: surfaceVariant,
          surfaceContainerLowest: scaffold,
          surfaceContainerLow: Color.lerp(surface, surfaceVariant, 0.35),
          surfaceContainer: surfaceVariant,
          surfaceContainerHigh: Color.lerp(surface, surfaceVariant, 0.8),
          surfaceContainerHighest: surfaceVariant,
          onSurface: onSurface,
          onSurfaceVariant: Color.lerp(onSurface, surface, 0.30),
          outline: outline,
          outlineVariant: outline.withValues(alpha: 0.38),
          error: brightness == Brightness.dark
              ? const Color(0xFFFFB4AB)
              : const Color(0xFFBA1A1A),
        );

    final base = ThemeData(
      pageTransitionsTheme: AppPageTransitions.theme,
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

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: outline.withValues(alpha: 0.38)),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: 23,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          height: 1.5,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.5,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shape,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 600),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: outline,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          side: BorderSide(color: outline.withValues(alpha: 0.45)),
        ),
        constraints: const BoxConstraints(maxWidth: 720),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: shape,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          shape: WidgetStatePropertyAll(shape),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: onSurface,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          minimumSize: const Size(44, 44),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(44, 44),
          side: BorderSide(color: outline.withValues(alpha: 0.50)),
          shape: buttonShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        shape: buttonShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color.lerp(surface, surfaceVariant, 0.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: outline.withValues(alpha: 0.45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: outline.withValues(alpha: 0.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: 0.24),
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
