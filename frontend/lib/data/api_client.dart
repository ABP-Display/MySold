import 'dart:convert';
import 'package:http/browser_client.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  const ApiException(this.code, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static final instance = ApiClient._();
  ApiClient._();
  final BrowserClient _client = BrowserClient()..withCredentials = true;

  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    // Same-origin cookies never enter localStorage or the exported CSV.
    final uri = Uri.base.resolve('/api/$path');
    final headers = {
      'Content-Type': 'application/json',
      'X-MySold-Request': '1',
    };
    final response = body == null
        ? await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 30))
        : await _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 60));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        decoded['code']?.toString() ?? 'server-error',
        decoded['message']?.toString() ?? 'Le serveur est indisponible.',
      );
    }
    return decoded;
  }
}
