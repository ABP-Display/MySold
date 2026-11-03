import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';

/// Shared startup/data loading state, independent of the user's theme.
class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('app-loading-screen'),
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final compact = bounds.maxHeight < 300;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/logo.png',
                    width: compact ? 64 : 112,
                    height: compact ? 64 : 112,
                    semanticLabel: 'MySold',
                  ),
                  SizedBox(height: compact ? 12 : 24),
                  RepaintBoundary(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: const Color(0xFFB2CFA6),
                        backgroundColor: const Color(0xFF262626),
                        value: MediaQuery.disableAnimationsOf(context)
                            ? .65
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      context.tr('Chargement de vos données…'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFB8B8B8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
