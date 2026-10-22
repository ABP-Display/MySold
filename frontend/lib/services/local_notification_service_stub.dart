import 'dart:js_interop';
import 'package:mysold/services/budget_alert_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@JS('mysoldNotify')
external void _notify(JSString title, JSString body);
@JS('mysoldRequestNotifications')
external JSPromise<JSString> _requestNotifications();

class LocalNotificationService {
  static Future<void> initialize() async {}

  static Future<bool> requestPermission() async {
    try {
      return (await _requestNotifications().toDart).toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  static Future<void> showBudgetAlert(BudgetAlertResult alert) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notifications_enabled') == false ||
        prefs.getBool('budget_alerts_enabled') == false)
      return;
    _notify(
      alert.title.toJS,
      'Seuil atteint : ${alert.currentPercent.toStringAsFixed(0)} % des revenus du mois.'
          .toJS,
    );
  }
}
