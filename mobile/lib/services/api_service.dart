// Gavin - Authenticated requests to the ApolLens backend.
import 'dart:convert';

import 'package:http/http.dart' as http;

final class ApiService {
  ApiService(this.baseUri, this.token, {http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUri;
  final String token;
  final http.Client _client;

  Future<http.Response> post(String path, Map<String, Object?> body) async {
    final request = http.Request('POST', baseUri.resolve(path))
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

  void dispose() => _client.close();
}
