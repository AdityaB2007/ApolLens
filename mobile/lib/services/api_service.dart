// Gavin - Authenticated requests to the ApolLens backend.
import 'dart:async';
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
  final _pending = <Completer<void>>{};

  Future<http.Response> post(String path, Map<String, Object?> body) async {
    if (_disposed) throw StateError('Backend client is closed.');
    final target = baseUri.resolve(path);
    // Never send authentication to a different server or embedded user.
    if (target.scheme != baseUri.scheme ||
        target.origin != baseUri.origin ||
        target.userInfo.isNotEmpty ||
        target.hasFragment) {
      throw ArgumentError('Expected a path on the configured backend.');
    }
    final aborted = Completer<void>();
    final request =
        http.AbortableRequest('POST', target, abortTrigger: aborted.future)
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode(body);
    _pending.add(aborted);
    try {
      return await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
    } finally {
      _pending.remove(aborted);
      // A timeout must also release the underlying connection.
      if (!aborted.isCompleted) aborted.complete();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final request in _pending) {
      if (!request.isCompleted) request.complete();
    }
    _pending.clear();
    _client.close();
  }
}
