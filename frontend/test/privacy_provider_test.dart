import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Shake is opt-in, repeated movement only hides, eye reveals', () async {
    final privacy = PrivacyProvider();
    await privacy.load();
    expect(privacy.shakeEnabled, isFalse);
    privacy.hideWithShake();
    expect(privacy.hideAmounts, isFalse);
    await privacy.setShakeEnabled(true);
    privacy.hideWithShake();
    privacy.hideWithShake();
    expect(privacy.hideAmounts, isTrue);
    expect(privacy.money(42, '€'), '**** €');
    await privacy.setHideAmounts(false);
    expect(privacy.hideAmounts, isFalse);
    final reloaded = PrivacyProvider();
    await reloaded.load();
    expect(reloaded.shakeEnabled, isTrue);
    expect(reloaded.hideAmounts, isFalse);
    await reloaded.setShakeEnabled(false);
    reloaded.hideWithShake();
    expect(reloaded.hideAmounts, isFalse);
  });
  test('Explicit masking remains enabled until the user reveals', () async {
    final privacy = PrivacyProvider();
    await privacy.setHideAmounts(true);
    final reloaded = PrivacyProvider();
    await reloaded.load();
    expect(reloaded.hideAmounts, isTrue);
    await reloaded.setHideAmounts(false);
    expect(reloaded.hideAmounts, isFalse);
  });
}
