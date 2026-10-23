import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('mysoldRequestMotionPermission')
external JSPromise<JSBoolean> _requestPermission();
@JS('mysoldStartShake')
external void _start(JSFunction callback);
@JS('mysoldStopShake')
external void _stop();

class ShakePrivacyService {
  static Future<bool> requestPermission() async {
    try {
      return (await _requestPermission().toDart).toDart;
    } catch (_) {
      return false;
    }
  }

  void start(VoidCallback onShake) {
    try {
      _start(onShake.toJS);
    } catch (_) {
      /* Motion is optional. */
    }
  }

  void stop() {
    try {
      _stop();
    } catch (_) {
      /* No listener on unsupported browsers. */
    }
  }
}
