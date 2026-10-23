import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Include every deployed asset in the worker version, even asset-only changes.
void main() {
  final directory = Directory('build/web');
  final worker = File('build/web/sw.js');
  final declaration = RegExp(r"const BUILD = '[^']*';");
  const placeholder = "const BUILD = '__MYSOLD_BUILD_ID__';";
  final template = worker.readAsStringSync().replaceFirst(
    declaration,
    placeholder,
  );
  if (!template.contains(placeholder))
    throw StateError('Missing service worker build ID');
  final files = directory.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final manifest = files
      .map((file) {
        final path = file.path
            .substring(directory.path.length + 1)
            .replaceAll('\\', '/');
        final bytes = path == 'sw.js'
            ? utf8.encode(template)
            : file.readAsBytesSync();
        return '$path:${sha256.convert(bytes)}';
      })
      .join('\n');
  final version = sha256.convert(utf8.encode(manifest)).toString();
  worker.writeAsStringSync(
    template.replaceFirst(placeholder, "const BUILD = '$version';"),
  );
  stdout.writeln('PWA build: $version');
}
