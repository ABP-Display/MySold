import 'dart:js_interop';

@JS('mysoldCheckForUpdate')
external JSPromise<JSString> _checkForUpdate();
@JS('mysoldApplyUpdate')
external JSPromise<JSBoolean> _applyUpdate();

class PwaUpdateService {
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
