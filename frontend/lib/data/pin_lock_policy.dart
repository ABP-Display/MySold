class PinLockPolicy {
  static const delays = <int, String>{
    0: 'Immediat',
    1: 'Apres 1 minute',
    5: 'Apres 5 minutes',
    15: 'Apres 15 minutes',
    60: 'Apres 1 heure',
  };

  final String frequency;
  final int minutes;

  PinLockPolicy(Object? frequency, Object? delay)
    : frequency = switch (frequency?.toString().trim().toLowerCase()) {
        'always' ||
        'toujours' ||
        'chaque ouverture' ||
        'chaque ouverture de l app' ||
        "chaque ouverture de l'app" => 'always',
        _ => 'never',
      },
      minutes = _delay(delay);

  static int _delay(Object? value) {
    final minutes = value is num && value.isFinite
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    return delays.containsKey(minutes) ? minutes! : 0;
  }

  bool shouldLock(Duration away) =>
      frequency == 'always' && away >= Duration(minutes: minutes);
}
