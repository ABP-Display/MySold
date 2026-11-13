import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/l10n/feature_strings.dart';
import 'package:mysold/widgets/app_page_tab_menu.dart';

void main() {
  testWidgets(
    'Retained menu follows language changes without recreating its inputs',
    (tester) async {
      final locale = ValueNotifier(const Locale('fr'));
      addTearDown(locale.dispose);
      final menu = AppPageTabMenu(
        labels: const ['Dépenses', 'Revenus'],
        icons: const [Icons.arrow_downward, Icons.arrow_upward],
        selectedIndex: 0,
        onSelected: (_) {},
        keyPrefix: 'locale',
      );
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, _) => MaterialApp(
            locale: value,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(bottomNavigationBar: menu),
          ),
        ),
      );
      for (final value in AppLocalizations.supportedLocales) {
        locale.value = value;
        await tester.pumpAndSettle();
        expect(
          find.text(AppLocalizations(value).t('Dépenses')),
          findsOneWidget,
        );
        expect(find.text(AppLocalizations(value).t('Revenus')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  test(
    'Every new feature key has five complete translations and placeholders',
    () {
      for (final entry in featureStrings.entries) {
        expect(entry.value.length, 5, reason: entry.key);
        final placeholders = RegExp(
          r'\{\w+\}',
        ).allMatches(entry.key).map((m) => m.group(0)).toSet();
        for (final value in entry.value) {
          expect(value.trim(), isNotEmpty, reason: entry.key);
          expect(
            RegExp(r'\{\w+\}').allMatches(value).map((m) => m.group(0)).toSet(),
            placeholders,
            reason: entry.key,
          );
        }
      }
    },
  );
  test('Dynamic labels preserve values without translating user content', () {
    const ja = AppLocalizations(Locale('ja'));
    expect(ja.t('Projection sur 12 mois'), '12か月の予測');
    expect(ja.t('Mon compte personnel'), 'Mon compte personnel');
    expect(ja.t('Évolution annuelle'), '年間推移');
  });
  test('Catalog variables are preserved in every language', () {
    Set<String> variables(String value) => RegExp(
      r'\{\w+\}',
    ).allMatches(value).map((match) => match.group(0)!).toSet();
    for (final key in AppLocalizations.knownKeys) {
      if (variables(key).isEmpty) continue;
      for (final locale in AppLocalizations.supportedLocales) {
        expect(
          variables(AppLocalizations(locale).t(key)),
          variables(key),
          reason: '${locale.languageCode}: $key',
        );
      }
    }
  });
  test('Visible static text uses localization instead of raw literals', () {
    final rawText = RegExp(r'''\bText\(\s*(['"])((?:\\.|(?!\1).)*?)\1''');
    final untranslated = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.contains('l10n')) continue;
      for (final match in rawText.allMatches(file.readAsStringSync())) {
        final value = match.group(2)!;
        if (value.contains(r'$') ||
            !RegExp('[A-Za-zÀ-ÿ]').hasMatch(value) ||
            value == 'MySold' ||
            value == 'MySold.')
          continue;
        untranslated.add('${file.path}: $value');
      }
    }
    expect(untranslated, isEmpty);
  });
  test('Catalog coverage audit', () {
    final pending = <String, Map<String, String>>{};
    final observed = <String>{};
    final literal = RegExp(
      r'''(?:\.tr|_t|trParams)\(\s*(['"])((?:\\.|(?!\1).)*?)\1''',
    );
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) => f.path.endsWith('.dart') && !f.path.contains('l10n'),
            )) {
      for (final match in literal.allMatches(file.readAsStringSync())) {
        final key = match
            .group(2)!
            .replaceAll(r"\'", "'")
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n');
        if (!key.contains(r'$')) observed.add(key);
      }
    }
    final gaps = <String, List<String>>{};
    for (final code in ['en', 'es', 'de', 'it', 'ja']) {
      final strings = AppLocalizations(Locale(code));
      final missing = {
        ...AppLocalizations.knownKeys,
        ...observed,
      }.where((k) => !strings.hasTranslation(k)).toList();
      print(
        '$code: ${missing.length} missing of ${AppLocalizations.knownKeys.length}: $missing',
      );
      if (Platform.environment['AUDIT_SHARED_TRANSLATIONS'] == '1' &&
          code != 'en') {
        final english = const AppLocalizations(Locale('en'));
        print(
          '$code shares English: ${AppLocalizations.knownKeys.where((key) => strings.t(key) == english.t(key)).toList()}',
        );
      }
      gaps[code] = missing;
      pending[code] = {
        for (final key in missing)
          key: const AppLocalizations(Locale('en')).t(key),
      };
      if (code != 'en')
        for (final key in ['legal_terms_full', 'privacy_policy_full']) {
          pending[code]![key] = const AppLocalizations(Locale('en')).t(key);
        }
    }
    if (Platform.environment['EXPORT_TRANSLATION_CATALOG'] == '1')
      File(
        '../test-results/catalog-source.json',
      ).writeAsStringSync(jsonEncode(pending));
    expect(
      gaps.values.expand((v) => v).toList(),
      isEmpty,
      reason: 'Untranslated catalog or UI keys',
    );
  });
}
