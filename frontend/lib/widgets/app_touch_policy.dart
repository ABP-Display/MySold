import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Recognize a deliberate touch scroll sooner, before a pending button press
/// starts its feedback. Mouse precision and smaller device thresholds are kept.
class AppTouchPolicy extends StatelessWidget {
  final Widget child;
  const AppTouchPolicy({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        gestureSettings: DeviceGestureSettings(
          touchSlop: math.min(media.gestureSettings.touchSlop ?? kTouchSlop, 8),
        ),
      ),
      child: child,
    );
  }
}
