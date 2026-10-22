import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyOption {
  final String code;
  final String symbol;
  final String name;

  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.name,
  });

  String get label => '$symbol $name ($code)';
}

class CurrencyProvider extends ChangeNotifier {
  static const String defaultCurrencyCode = 'EUR';

  static const List<CurrencyOption> currencies = [
    CurrencyOption(code: 'EUR', symbol: '\u20AC', name: 'Euro'),
    CurrencyOption(code: 'USD', symbol: r'$', name: 'Dollar US'),
    CurrencyOption(code: 'GBP', symbol: '\u00A3', name: 'Livre sterling'),
    CurrencyOption(code: 'JPY', symbol: '\u00A5', name: 'Yen'),
    CurrencyOption(code: 'CHF', symbol: 'CHF', name: 'Franc suisse'),
    CurrencyOption(code: 'CAD', symbol: r'C$', name: 'Dollar canadien'),
    CurrencyOption(code: 'AUD', symbol: r'A$', name: 'Dollar australien'),
    CurrencyOption(code: 'MAD', symbol: 'MAD', name: 'Dirham marocain'),
    CurrencyOption(code: 'AED', symbol: 'AED', name: 'Dirham UAE'),
    CurrencyOption(code: 'XOF', symbol: 'CFA', name: 'Franc CFA'),
    CurrencyOption(code: 'CNY', symbol: '\u00A5', name: 'Yuan renminbi'),
    CurrencyOption(code: 'KRW', symbol: '\u20A9', name: 'Won'),
    CurrencyOption(code: 'BRL', symbol: r'R$', name: 'Real bresilien'),
    CurrencyOption(code: 'MXN', symbol: r'MX$', name: 'Peso mexicain'),
    CurrencyOption(code: 'INR', symbol: '\u20B9', name: 'Roupie indienne'),
  ];

  String _currencyCode = defaultCurrencyCode;

  String get currencyCode => _currencyCode;
  CurrencyOption get selectedCurrency => optionForCode(_currencyCode);
  String get currency => selectedCurrency.symbol;

  static CurrencyOption optionForCode(String? code) {
    final normalized = normalizeCurrencyCode(code);
    return currencies.firstWhere(
      (currency) => currency.code == normalized,
      orElse: () => currencies.first,
    );
  }

  static String normalizeCurrencyCode(String? value) {
    if (value == null || value.trim().isEmpty) return defaultCurrencyCode;
    final cleaned = value.trim();

    const legacySymbols = {
      '\u20AC': 'EUR',
      '\u00E2\u201A\u00AC': 'EUR',
      r'$': 'USD',
      '\u00A3': 'GBP',
      '\u00C2\u00A3': 'GBP',
      '\u00A5': 'JPY',
      '\u00C2\u00A5': 'JPY',
      'CHF': 'CHF',
      'CFA': 'XOF',
    };

    final fromSymbol = legacySymbols[cleaned];
    if (fromSymbol != null) return fromSymbol;

    final upperCode = cleaned.toUpperCase();
    final exists = currencies.any((currency) => currency.code == upperCode);
    return exists ? upperCode : defaultCurrencyCode;
  }

  Future<void> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _currencyCode = normalizeCurrencyCode(
      prefs.getString('currencyCode') ?? prefs.getString('currency'),
    );
    notifyListeners();
  }

  Future<void> loadCurrencyForUser(String uid) async {
    final doc = await DocumentStore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    final remoteCurrency = normalizeCurrencyCode(
      data?['currencyCode'] ?? data?['currency'],
    );
    await setCurrency(remoteCurrency, syncToFirestore: false);
  }

  Future<void> setCurrency(
    String newCurrencyCode, {
    bool syncToFirestore = true,
  }) async {
    final normalizedCode = normalizeCurrencyCode(newCurrencyCode);
    if (_currencyCode == normalizedCode) {
      if (syncToFirestore) await _syncCurrency(normalizedCode);
      return;
    }

    _currencyCode = normalizedCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currencyCode', normalizedCode);
    await prefs.setString('currency', optionForCode(normalizedCode).symbol);

    if (syncToFirestore) await _syncCurrency(normalizedCode);
    notifyListeners();
  }

  Future<void> _syncCurrency(String currencyCode) async {
    final uid = LocalAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final option = optionForCode(currencyCode);
    await DocumentStore.instance.collection('users').doc(uid).set(
      {
        'currency': option.symbol,
        'currencyCode': option.code,
      },
      SetOptions(merge: true),
    );
  }
}
