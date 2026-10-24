import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/app_typography.dart';
import 'package:mysold/widgets/app_page_transitions.dart';

abstract final class AuthPalette {
  static const background = Colors.black;
  static const surface = Colors.black;
  static const field = Color(0xFF0E0E0E);
  static const story = Colors.black;
  static const border = Color(0xFF737373);
  static const accent = Color(0xFFB2CFA6);
  static const text = Color(0xFFF2F2F2);
  static const muted = Color(0xFFB8B8B8);
  static const tint = Color(0xFF1C1C1C);

  static final theme = ThemeData(
    pageTransitionsTheme: AppPageTransitions.theme,
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppTypography.family,
    fontFamilyFallback: AppTypography.fallback,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      onPrimary: background,
      surface: surface,
      onSurface: text,
      secondary: accent,
      onSecondary: background,
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      outline: border,
    ),
    scaffoldBackgroundColor: background,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: field,
      labelStyle: const TextStyle(color: muted),
      helperStyle: const TextStyle(color: muted, height: 1.5),
      prefixIconColor: muted,
      suffixIconColor: muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border, width: 1.25),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: background,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

class AuthBrand extends StatelessWidget {
  final double logoSize;
  const AuthBrand({super.key, this.logoSize = 80});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      AuthLogo(size: logoSize),
      const SizedBox(width: 11),
      const Expanded(
        child: Text(
          'MySold.',
          style: TextStyle(
            color: AuthPalette.text,
            fontSize: 23,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
      ),
    ],
  );
}

/// The original logo, shared by authentication screens.
class AuthLogo extends StatelessWidget {
  final double size;
  const AuthLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'MySold',
    child: Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AuthPalette.field,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AuthPalette.border),
      ),
      child: Image.asset(
        'assets/icons/logo.png',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    ),
  );
}

class AuthPinHeader extends StatelessWidget {
  final String title, description;
  const AuthPinHeader({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Center(child: AuthLogo(size: 112)),
      const SizedBox(height: 24),
      Semantics(
        header: true,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AuthPalette.text,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.8,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        description,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AuthPalette.muted, height: 1.6),
      ),
    ],
  );
}

/// One scrollable card shared by login and registration, including with a keyboard.
class AuthScaffold extends StatelessWidget {
  final Widget Function(BuildContext context, bool compact) formBuilder;
  final ScrollController? scrollController;

  const AuthScaffold({
    super.key,
    required this.formBuilder,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) => Theme(
    data: AuthPalette.theme,
    child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final wide = viewport.maxWidth >= 900;
            final padding = viewport.maxWidth < 600 ? 16.0 : 32.0;
            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.all(padding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (viewport.maxHeight - padding * 2).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1000 : 520),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AuthPalette.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AuthPalette.border,
                          width: 1.25,
                        ),
                      ),
                      child: wide
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Expanded(flex: 4, child: _AuthStory()),
                                  Expanded(
                                    flex: 6,
                                    child: formBuilder(context, false),
                                  ),
                                ],
                              ),
                            )
                          : formBuilder(context, true),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _AuthStory extends StatelessWidget {
  const _AuthStory();

  Widget benefit(BuildContext context, IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AuthPalette.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.tr(label),
            style: const TextStyle(color: AuthPalette.text, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AuthPalette.story,
      border: Border(right: BorderSide(color: AuthPalette.border, width: 1.25)),
    ),
    padding: const EdgeInsets.all(32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthBrand(),
        const SizedBox(height: 64),
        Text(
          context.tr('VOS FINANCES, SIMPLEMENT'),
          style: const TextStyle(
            color: AuthPalette.accent,
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.tr('Plus de clarté.\nPlus de sérénité.'),
          style: const TextStyle(
            color: AuthPalette.text,
            fontFamily: AppTypography.family,
            fontSize: 38,
            height: 1.15,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.tr(
            'Un espace à vous pour suivre votre budget et donner forme à vos projets.',
          ),
          style: const TextStyle(
            color: AuthPalette.muted,
            fontSize: 14,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 40),
        benefit(
          context,
          Icons.account_balance_wallet_outlined,
          'Vos comptes, réunis',
        ),
        benefit(
          context,
          Icons.bar_chart_outlined,
          'Votre budget, plus lisible',
        ),
        benefit(context, Icons.trending_up, 'Vos projets, en perspective'),
        const Spacer(),
        const SizedBox(height: 40),
        Text(
          context.tr('Vos données restent sur votre instance.'),
          style: const TextStyle(
            color: AuthPalette.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
