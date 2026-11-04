import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Web views can lack a device-provided drag threshold. Keep a small tolerance
/// for taps instead of waiting for Flutter's larger generic touch fallback.
class WebScrollScope extends StatelessWidget {
  final Widget child;
  const WebScrollScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.gestureSettings.touchSlop != null) return child;
    return MediaQuery(
      data: media.copyWith(
        gestureSettings: const DeviceGestureSettings(touchSlop: 8),
      ),
      child: child,
    );
  }
}
