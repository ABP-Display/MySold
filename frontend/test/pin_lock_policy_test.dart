import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/data/pin_lock_policy.dart';

void main() {
  test('normalizes legacy lock settings and bounds dropdown values', () {
    expect(PinLockPolicy("Chaque ouverture de l'app", '5').minutes, 5);
    expect(PinLockPolicy('Toujours', 1440).frequency, 'always');
    expect(PinLockPolicy('always', 1440).minutes, 0);
    expect(PinLockPolicy('never', double.nan).minutes, 0);
  });
  test('locks after the selected delay only when enabled', () {
    final policy = PinLockPolicy('always', 5);
    expect(policy.shouldLock(const Duration(minutes: 4, seconds: 59)), false);
    expect(policy.shouldLock(const Duration(minutes: 5)), true);
    expect(PinLockPolicy('always', 0).shouldLock(Duration.zero), true);
    expect(
      PinLockPolicy('never', 0).shouldLock(const Duration(days: 1)),
      false,
    );
  });
}
