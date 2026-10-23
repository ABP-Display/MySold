import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/stamp_web_build.dart' as stamp;

void main() {
  test('build timestamps use Paris time in summer and winter', () {
    expect(
      stamp.formatBuildVersion(DateTime.utc(2026, 10, 23, 19, 45)),
      '2026.10.23.2145',
    );
    expect(
      stamp.formatBuildVersion(DateTime.utc(2026, 12, 1, 20, 45)),
      '2026.12.01.2145',
    );
  });

  test(
    'client, manifest and worker carry one stable build; changed content needs another number',
    () {
      final originalDirectory = Directory.current;
      final fixture = Directory.systemTemp.createTempSync('mysold-build-test-');
      try {
        Directory.current = fixture;
        Directory('build/web').createSync(recursive: true);
        final worker = File('build/web/sw.js')
          ..writeAsStringSync("const BUILD = '__MYSOLD_BUILD_ID__';");
        final client = File(
          'build/web/pwa_updates.js',
        )..writeAsStringSync("const LOCAL_BUILD = '__MYSOLD_BUILD_VERSION__';");
        final app = File('build/web/main.dart.js')..writeAsStringSync('app-v1');
        final index = File('build/web/index.html')
          ..writeAsStringSync(
            '<script src="pwa_updates.js"></script><script src="flutter_bootstrap.js"></script>',
          );
        final bootstrap = File('build/web/flutter_bootstrap.js')
          ..writeAsStringSync('{"mainJsPath":"main.dart.js"}');
        final logo = File('build/web/logo.png')..writeAsBytesSync([1, 2, 3]);
        final manifest = File('build/web/version.json');
        stamp.main(['--build-version=2026.10.23.2145']);
        final first = worker.readAsStringSync();
        expect(
          index.readAsStringSync(),
          contains('pwa_updates.js?mysold_build=2026.10.23.2145-'),
        );
        expect(
          index.readAsStringSync(),
          contains('flutter_bootstrap.js?mysold_build=2026.10.23.2145-'),
        );
        expect(
          bootstrap.readAsStringSync(),
          contains('main.dart.js?mysold_build=2026.10.23.2145-'),
        );
        final firstIndex = index.readAsStringSync();
        final firstBootstrap = bootstrap.readAsStringSync();
        expect(client.readAsStringSync(), contains("'2026.10.23.2145'"));
        expect(
          jsonDecode(manifest.readAsStringSync())['build'],
          '2026.10.23.2145',
        );
        stamp.main();
        expect(worker.readAsStringSync(), first);
        expect(index.readAsStringSync(), firstIndex);
        expect(bootstrap.readAsStringSync(), firstBootstrap);
        app.writeAsStringSync('app-v2');
        expect(
          () => stamp.main(['--build-version=2026.10.23.2145']),
          throwsStateError,
        );
        stamp.main(['--build-version=2026.10.23.2200']);
        final second = worker.readAsStringSync();
        expect(index.readAsStringSync(), isNot(firstIndex));
        expect(bootstrap.readAsStringSync(), isNot(firstBootstrap));
        expect(second, isNot(first));
        logo.writeAsBytesSync([4, 5, 6]);
        stamp.main(['--build-version=2026.10.23.2210']);
        expect(worker.readAsStringSync(), isNot(second));
        expect(
          jsonDecode(manifest.readAsStringSync())['build'],
          '2026.10.23.2210',
        );
      } finally {
        Directory.current = originalDirectory;
        fixture.deleteSync(recursive: true);
      }
    },
  );
}
