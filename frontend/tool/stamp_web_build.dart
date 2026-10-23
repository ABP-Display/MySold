import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

String formatBuildVersion(DateTime instant) {
  tz_data.initializeTimeZones();
  final paris = tz.TZDateTime.from(instant, tz.getLocation('Europe/Paris'));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${paris.year}.${two(paris.month)}.${two(paris.day)}.${two(paris.hour)}${two(paris.minute)}';
}

/// Stamp the running client, the server manifest and the worker in one build.
void main([List<String> arguments = const []]) {
  final directory = Directory('build/web');
  final worker = File('build/web/sw.js');
  final client = File('build/web/pwa_updates.js');
  final manifestFile = File('build/web/version.json');
  final workerDeclaration = RegExp(r"const BUILD = '[^']*';");
  final clientDeclaration = RegExp(r"const LOCAL_BUILD = '[^']*';");
  const workerPlaceholder = "const BUILD = '__MYSOLD_BUILD_ID__';";
  const clientPlaceholder = "const LOCAL_BUILD = '__MYSOLD_BUILD_VERSION__';";
  final workerTemplate = worker.readAsStringSync().replaceFirst(
    workerDeclaration,
    workerPlaceholder,
  );
  final clientTemplate = client.readAsStringSync().replaceFirst(
    clientDeclaration,
    clientPlaceholder,
  );
  if (!workerTemplate.contains(workerPlaceholder) ||
      !clientTemplate.contains(clientPlaceholder)) {
    throw StateError('Missing PWA build placeholder');
  }
  final files = directory.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final contents = files
      .map((file) {
        final path = file.path
            .substring(directory.path.length + 1)
            .replaceAll('\\', '/');
        if (path == 'version.json') return '';
        final bytes = switch (path) {
          'sw.js' => utf8.encode(workerTemplate),
          'pwa_updates.js' => utf8.encode(clientTemplate),
          _ => file.readAsBytesSync(),
        };
        return '$path:${sha256.convert(bytes)}';
      })
      .where((line) => line.isNotEmpty)
      .join('\n');
  final hash = sha256.convert(utf8.encode(contents)).toString();
  final previous = manifestFile.existsSync()
      ? jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  if (arguments.length > 1 ||
      arguments.any((value) => !value.startsWith('--build-version='))) {
    throw ArgumentError('Use --build-version=YYYY.MM.DD.HHMM');
  }
  final explicit = arguments.isEmpty
      ? null
      : arguments.single.substring('--build-version='.length);
  final version =
      explicit ??
      (previous['contentHash'] == hash
          ? previous['build'] as String
          : formatBuildVersion(DateTime.now()));
  if (!RegExp(r'^\d{4}\.\d{2}\.\d{2}\.\d{4}$').hasMatch(version)) {
    throw ArgumentError('Build version must use YYYY.MM.DD.HHMM');
  }
  if (previous['build'] == version && previous['contentHash'] != hash) {
    throw StateError(
      'A different build already uses $version. Wait for the next minute or pass a distinct --build-version.',
    );
  }
  worker.writeAsStringSync(
    workerTemplate.replaceFirst(
      workerPlaceholder,
      "const BUILD = '$version-$hash';",
    ),
  );
  client.writeAsStringSync(
    clientTemplate.replaceFirst(
      clientPlaceholder,
      "const LOCAL_BUILD = '$version';",
    ),
  );
  manifestFile.writeAsStringSync(
    jsonEncode({'build': version, 'contentHash': hash}),
  );
  stdout.writeln('PWA build: $version (Europe/Paris)');
}
