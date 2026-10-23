import 'dart:js_interop';

@JS('mysoldCheckForUpdate')
external JSPromise<JSString> _checkForUpdate();
@JS('mysoldApplyUpdate')
external JSPromise<JSBoolean> _applyUpdate();
@JS('mysoldBuildVersion')
external JSString get _currentBuild;
@JS('mysoldUpdateVersion')
external JSString get _availableBuild;

class PwaUpdateService {
  static String get currentBuild {
    try {
      return _currentBuild.toDart;
    } catch (_) {
      return '';
    }
  }

  static String get availableBuild {
    try {
      return _availableBuild.toDart;
    } catch (_) {
      return '';
    }
  }

  static Future<String> check() async {
    try {
      return (await _checkForUpdate().toDart).toDart;
    } catch (_) {
      return 'error';
    }
  }

  static Future<bool> apply() async {
    try {
      return (await _applyUpdate().toDart).toDart;
    } catch (_) {
      return false;
    }
  }
}
