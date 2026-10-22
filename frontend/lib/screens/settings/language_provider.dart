import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageOption {
  final String code;
  final String name;

  const LanguageOption({
    required this.code,
    required this.name,
  });
}

class LanguageProvider extends ChangeNotifier {
  static const String defaultLanguageCode = 'fr';

  static const List<LanguageOption> languages = [
    LanguageOption(code: 'fr', name: 'Fran\u00E7ais'),
    LanguageOption(code: 'en', name: 'English'),
    LanguageOption(code: 'es', name: 'Espa\u00F1ol'),
    LanguageOption(code: 'de', name: 'Deutsch'),
    LanguageOption(code: 'it', name: 'Italiano'),
    LanguageOption(code: 'ja', name: '\u65E5\u672C\u8A9E'),
  ];

  String _languageCode = defaultLanguageCode;

  String get languageCode => _languageCode;
  LanguageOption get selectedLanguage => optionForCode(_languageCode);
  String get language => selectedLanguage.name;
  Locale get locale => Locale(_languageCode);

  static LanguageOption optionForCode(String? code) {
    final normalized = normalizeLanguageCode(code);
    return languages.firstWhere(
      (language) => language.code == normalized,
      orElse: () => languages.first,
    );
  }

  static String normalizeLanguageCode(String? value) {
    if (value == null || value.trim().isEmpty) return defaultLanguageCode;
    final cleaned = value.trim();

    const aliases = {
      'Fran\u00E7ais': 'fr',
      'Fran\u00C3\u00A7ais': 'fr',
      'Francais': 'fr',
      'Anglais': 'en',
      'English': 'en',
      'Espagnol': 'es',
      'Espa\u00F1ol': 'es',
      'Allemand': 'de',
      'Deutsch': 'de',
      'Italien': 'it',
      'Italiano': 'it',
      'Japonais': 'ja',
      '\u65E5\u672C\u8A9E': 'ja',
    };

    final fromName = aliases[cleaned];
    if (fromName != null) return fromName;

    final lowerCode = cleaned.toLowerCase();
    final exists = languages.any((language) => language.code == lowerCode);
    return exists ? lowerCode : defaultLanguageCode;
  }

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = normalizeLanguageCode(
      prefs.getString('languageCode') ?? prefs.getString('language'),
    );
    notifyListeners();
  }

  Future<void> loadLanguageForUser(String uid) async {
    final doc = await DocumentStore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    final remoteLanguage = normalizeLanguageCode(
      data?['languageCode'] ?? data?['language'],
    );
    await setLanguage(remoteLanguage, syncToFirestore: false);
  }

  Future<void> setLanguage(
    String newLanguageCode, {
    bool syncToFirestore = true,
  }) async {
    final normalizedCode = normalizeLanguageCode(newLanguageCode);
    if (_languageCode == normalizedCode) {
      if (syncToFirestore) await _syncLanguage(normalizedCode);
      return;
    }

    _languageCode = normalizedCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', normalizedCode);
    await prefs.setString('language', optionForCode(normalizedCode).name);

    if (syncToFirestore) await _syncLanguage(normalizedCode);
    notifyListeners();
  }

  Future<void> _syncLanguage(String languageCode) async {
    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final option = optionForCode(languageCode);
    await DocumentStore.instance.collection('users').doc(uid).set(
      {
        'language': option.name,
        'languageCode': option.code,
      },
      SetOptions(merge: true),
    );
  }
}
