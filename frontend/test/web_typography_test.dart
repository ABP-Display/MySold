import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/screens/settings/theme_settings.dart';
import 'package:mysold/widgets/auth_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'All app and authentication themes can render French currency spacing locally',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      final family = manifest.cast<Map<String, dynamic>>().singleWhere(
        (entry) => entry['family'] == 'NotoSans',
      );
      final asset = (family['fonts'] as List).single['asset'] as String;
      final bytes = await rootBundle.load(asset);
      expect(
        ascii.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, 4)),
        'wOF2',
      );
      expect(bytes.lengthInBytes, greaterThan(10000));
      for (final theme in [...AppThemes.themes.values, AuthPalette.theme]) {
        for (final style in [
          theme.textTheme.bodyMedium,
          theme.textTheme.headlineMedium,
          theme.textTheme.titleLarge,
        ]) {
          expect(style!.fontFamily, 'Roboto');
          expect(style.fontFamilyFallback, contains('NotoSans'));
        }
      }
    },
  );
}
