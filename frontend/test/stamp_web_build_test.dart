import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/stamp_web_build.dart' as stamp;

void main() {
  test('PWA version is stable and changes for code or image updates', () {
    final originalDirectory = Directory.current;
    final fixture = Directory.systemTemp.createTempSync('mysold-build-test-');
    try {
      Directory.current = fixture;
      Directory('build/web').createSync(recursive: true);
      final worker = File('build/web/sw.js')
        ..writeAsStringSync("const BUILD = '__MYSOLD_BUILD_ID__';");
      final app = File('build/web/main.dart.js')..writeAsStringSync('app-v1');
      final logo = File('build/web/logo.png')..writeAsBytesSync([1, 2, 3]);
      stamp.main();
      final first = worker.readAsStringSync();
      expect(first, isNot(contains('__MYSOLD_BUILD_ID__')));
      stamp.main();
      expect(worker.readAsStringSync(), first);
      app.writeAsStringSync('app-v2');
      stamp.main();
      final second = worker.readAsStringSync();
      expect(second, isNot(first));
      logo.writeAsBytesSync([4, 5, 6]);
      stamp.main();
      expect(worker.readAsStringSync(), isNot(second));
    } finally {
      Directory.current = originalDirectory;
      fixture.deleteSync(recursive: true);
    }
  });
}
