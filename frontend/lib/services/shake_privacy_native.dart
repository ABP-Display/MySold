import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakePrivacyService {
  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  static Future<bool> requestPermission() async {
    try {
      await accelerometerEventStream().first.timeout(
        const Duration(seconds: 2),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void start(VoidCallback onShake) {
    stop();
    _subscription = accelerometerEventStream().listen((event) {
      final force = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      final now = DateTime.now();
      if (force < 22 || now.difference(_lastShake).inMilliseconds < 1200)
        return;
      _lastShake = now;
      onShake();
    }, onError: (Object _) => stop());
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
