// Gavin - Connect ApolLens instruction text to spoken guidance.
import 'dart:async';

import 'audio_playback.dart';
import 'audio_service.dart';

final class SpeechController {
  SpeechController(this._audio, this._playback);

  final AudioService _audio;
  final AudioPlayback _playback;
  int _generation = 0;
  bool _disposed = false;

  Future<void> speak(String text) async {
    if (_disposed) return;
    final generation = ++_generation;
    await _playback.stop();
    if (_disposed || generation != _generation) return;
    final bytes = await _audio.synthesize(text);
    if (_disposed || generation != _generation) return;
    await _playback.play(bytes);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_playback.dispose().catchError((Object _) {}));
  }
}
