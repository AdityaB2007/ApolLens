// Gavin - Connect ApolLens instruction text to spoken guidance.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_playback.dart';
import 'audio_service.dart';

enum SpeechStatus { idle, loading, playing, paused, muted, failed }

final class SpeechController extends ValueNotifier<SpeechStatus> {
  SpeechController(this._audio, this._playback) : super(SpeechStatus.idle) {
    _states = _playback.states.listen(_onPlaybackState);
  }

  final AudioService _audio;
  final AudioPlayback _playback;
  late final StreamSubscription<PlayerState> _states;
  int _generation = 0;
  bool _disposed = false;
  String? _text;
  bool _muted = false;

  String? get text => _text;
  bool get muted => _muted;

  SpeechStatus get _playbackStatus => switch (_playback.state) {
        PlayerState.playing => SpeechStatus.playing,
        PlayerState.paused => SpeechStatus.paused,
        _ => SpeechStatus.idle,
      };

  void _onPlaybackState(PlayerState state) {
    // Queued events must still describe the current active audio.
    if (_disposed || _muted || state != _playback.state) return;
    if (value == SpeechStatus.playing || value == SpeechStatus.paused) {
      value = _playbackStatus;
    }
  }

  Future<void> setMuted(bool muted) async {
    if (_disposed || muted == _muted) return;
    _muted = muted;
    // Unmuting waits for an explicit replay or the next instruction.
    await stop();
  }

  Future<void> setPaused(bool paused) async {
    if (_disposed || _muted) return;
    // Pausing during loading cancels that instruction's pending playback.
    if (value == SpeechStatus.loading) {
      if (paused) await stop();
      return;
    }
    final generation = ++_generation;
    try {
      await (paused ? _playback.pause() : _playback.resume());
      if (_disposed || generation != _generation) return;
      value = _playbackStatus;
    } catch (_) {
      if (!_disposed && generation == _generation) value = SpeechStatus.failed;
    }
  }

  Future<void> replay() => _text == null ? Future.value() : speak(_text!);

  Future<void> stop({bool clear = false}) async {
    if (_disposed) return;
    final generation = ++_generation;
    // Clear the instruction when leaving its procedure or item.
    if (clear) _text = null;
    try {
      await _playback.stop();
      if (!_disposed && generation == _generation) {
        value = _muted ? SpeechStatus.muted : SpeechStatus.idle;
      }
    } catch (_) {
      if (!_disposed && generation == _generation) value = SpeechStatus.failed;
    }
  }

  Future<void> speak(String text) async {
    if (_disposed) return;
    _text = text;
    if (_muted) return stop();
    final generation = ++_generation;
    try {
      await _playback.stop();
      if (_disposed || generation != _generation) return;
      value = SpeechStatus.loading;
      if (_disposed || generation != _generation) return;
      final bytes = await _audio.synthesize(text);
      if (_disposed || generation != _generation) return;
      await _playback.play(bytes);
      if (!_disposed && generation == _generation) value = _playbackStatus;
    } catch (_) {
      // A late failure belongs to its original instruction.
      if (!_disposed && generation == _generation) value = SpeechStatus.failed;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_states.cancel());
    unawaited(_playback.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
