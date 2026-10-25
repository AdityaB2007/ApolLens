// Gavin - Fetch spoken ApolLens instructions from Indi's backend.
import 'dart:typed_data';

import 'api_service.dart';

final class AudioService {
  const AudioService(this._api);

  final ApiService _api;

  Future<Uint8List> synthesize(String text, {Future<void>? cancel}) async {
    if (text.trim().isEmpty) {
      throw ArgumentError('An instruction is required.');
    }
    // Keep speech identical to the text shown on the phone.
    final response = await _api.post('/api/audio/speak', {
      'text': text,
    }, cancel: cancel);
    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (response.statusCode != 200 ||
        contentType != 'audio/mpeg' ||
        response.bodyBytes.isEmpty) {
      throw StateError('Spoken instructions are unavailable.');
    }
    return response.bodyBytes;
  }
}
