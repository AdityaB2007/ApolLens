// Gavin - Connect ApolLens instruction text to spoken guidance.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_playback.dart';
import 'audio_service.dart';

enum SpeechStatus { idle, loading, playing, paused, failed }

final class SpeechController extends ValueNotifier<SpeechStatus> {
  SpeechController(this._audio, this._playback) : super(SpeechStatus.idle);

  final AudioService _audio;
  final AudioPlayback _playback;
  int _generation = 0;
  bool _disposed = false;

  Future<void> speak(String text) async {
    if (_disposed) return;
    final generation = ++_generation;
    try {
      await _playback.stop();
      if (_disposed || generation != _generation) return;
      value = SpeechStatus.loading;
      if (_disposed || generation != _generation) return;
      final bytes = await _audio.synthesize(text);
      if (_disposed || generation != _generation) return;
      await _playback.play(bytes);
      if (!_disposed && generation == _generation) value = SpeechStatus.playing;
    } catch (_) {
      // A late failure belongs to its original instruction.
      if (!_disposed && generation == _generation) value = SpeechStatus.failed;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_playback.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
