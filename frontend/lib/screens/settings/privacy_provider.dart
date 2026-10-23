import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyProvider extends ChangeNotifier {
  static const String hideAmountsKey = 'hide_amounts';
  static const String shakeEnabledKey = 'shake_to_hide_enabled';
  bool _hideAmounts = false;
  bool _shakeHideAmounts = false;
  bool _shakeEnabled = false;

  bool get persistentHideAmounts => _hideAmounts;
  bool get shakeHideAmounts => _shakeHideAmounts;
  bool get hideAmounts => _hideAmounts || _shakeHideAmounts;
  bool get shakeEnabled => _shakeEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _hideAmounts = prefs.getBool(hideAmountsKey) ?? false;
    _shakeEnabled = prefs.getBool(shakeEnabledKey) ?? false;
    notifyListeners();
  }

  Future<void> setHideAmounts(bool value) async {
    if (_hideAmounts == value && !_shakeHideAmounts) return;

    _hideAmounts = value;
    _shakeHideAmounts = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hideAmountsKey, value);
  }

  Future<void> setShakeEnabled(bool value) async {
    _shakeEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(shakeEnabledKey, value);
  }

  void hideWithShake() {
    if (!_shakeEnabled || hideAmounts) return;
    _shakeHideAmounts = true;
    notifyListeners();
  }

  String money(double value, String currency) {
    if (hideAmounts) return '**** $currency';
    return '${value.toStringAsFixed(2)} $currency';
  }

  String compactMoney(double value, String currency) {
    if (hideAmounts) return '**** $currency';
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M $currency';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K $currency';
    }
    return '${value.toStringAsFixed(0)} $currency';
  }

  String percent(double value, {int decimals = 0}) {
    if (hideAmounts) return '**%';
    return '${value.toStringAsFixed(decimals)}%';
  }
}
