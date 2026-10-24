import 'package:flutter/material.dart';

/// MySold is a Web app: open routes without rasterizing a full-page zoom/fade.
abstract final class AppPageTransitions {
  static final theme = PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: const _DirectPageTransitionsBuilder(),
    },
  );
}

class _DirectPageTransitionsBuilder extends PageTransitionsBuilder {
  const _DirectPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
