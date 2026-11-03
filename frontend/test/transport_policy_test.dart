import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/data/transport_policy.dart';

void main() {
  test('Remote HTTP cannot send credentials; localhost dev and HTTPS work', () {
    for (final origin in [
      'https://finances.example.test',
      'http://localhost:28085',
      'http://127.0.0.1:28085',
      'http://[::1]:28085',
    ]) {
      expect(isSecureApiOrigin(Uri.parse(origin)), true);
    }
    for (final origin in [
      'http://example.test',
      'http://192.168.1.2:28085',
      'http://localhost.evil.test',
      'ftp://localhost',
    ]) {
      expect(isSecureApiOrigin(Uri.parse(origin)), false);
    }
  });
}
