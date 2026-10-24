// Gavin - Authenticated requests to the ApolLens backend.
import 'dart:convert';

import 'package:http/http.dart' as http;

final class ApiService {
  ApiService(this.baseUri, this.token, {http.Client? client})
    : _client = client ?? http.Client() {
    if (!['http', 'https'].contains(baseUri.scheme) ||
        baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        token.isEmpty ||
        token.contains(RegExp(r'\s'))) {
      throw ArgumentError('Expected a backend URL and bearer token.');
    }
  }

  final Uri baseUri;
  final String token;
  final http.Client _client;
  bool _disposed = false;

  Future<http.Response> post(String path, Map<String, Object?> body) async {
    if (_disposed) throw StateError('Backend client is closed.');
    final target = baseUri.resolve(path);
    // Never send authentication to a different server or embedded user.
    if (target.origin != baseUri.origin ||
        target.userInfo.isNotEmpty ||
        target.hasFragment) {
      throw ArgumentError('Expected a path on the configured backend.');
    }
    final request = http.Request('POST', target)
      ..followRedirects = false
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode(body);
    return _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 15));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
}
