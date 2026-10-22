import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mysold/screens/settings/theme_settings.dart';

class ThemeProvider extends ChangeNotifier {
  String _themeName = AppThemes.defaultThemeName;

  String get themeName => _themeName;
  ThemeData get themeData => AppThemes.themeFor(_themeName);

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _themeName = AppThemes.normalizeThemeName(prefs.getString('theme'));
    notifyListeners();
  }

  Future<void> loadThemeForUser(String uid) async {
    final doc = await DocumentStore.instance.collection('users').doc(uid).get();
    final remoteTheme = AppThemes.normalizeThemeName(doc.data()?['theme']);
    await setTheme(remoteTheme, syncToFirestore: false);
  }

  Future<void> setTheme(
    String newTheme, {
    bool syncToFirestore = true,
  }) async {
    final normalizedTheme = AppThemes.normalizeThemeName(newTheme);
    if (_themeName == normalizedTheme) {
      if (syncToFirestore) await _syncTheme(normalizedTheme);
      return;
    }

    _themeName = normalizedTheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', normalizedTheme);

    if (syncToFirestore) await _syncTheme(normalizedTheme);
    notifyListeners();
  }

  Future<void> _syncTheme(String themeName) async {
    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await DocumentStore.instance.collection('users').doc(uid).set(
      {'theme': themeName},
      SetOptions(merge: true),
    );
  }
}
