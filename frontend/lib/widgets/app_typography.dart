import 'package:flutter/material.dart';
import 'app_design.dart';

/// All themes share bundled fallback fonts, including the authentication pages.
abstract final class AppTypography {
  static Widget readable(BuildContext context, Widget child) =>
      MediaQuery.sizeOf(context).width < AppDesign.mobileBreakpoint
      ? MediaQuery.withClampedTextScaling(minScaleFactor: 1.15, child: child)
      : child;

  static const family = 'Roboto';
  static const fallback = [
    'Roboto',
    'NotoSans',
    'NotoSansSymbols',
    'NotoSansJP',
    'NotoEmoji',
  ];
}
