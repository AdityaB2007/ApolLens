// Gavin - Speak repair guidance with an installed local system voice.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum OfflineSpeechStatus { idle, speaking, muted, failed }

final class OfflineSpeechService extends ChangeNotifier {
  OfflineSpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts.setCompletionHandler(() {
      if (!_disposed && !_muted) _setStatus(OfflineSpeechStatus.idle);
    });
    _tts.setErrorHandler((_) {
      if (!_disposed) _setStatus(OfflineSpeechStatus.failed);
    });
  }

  final FlutterTts _tts;
  Future<void>? _initialization;
  Future<void> _pending = Future.value();
  String? _lastText;
  bool _muted = false;
  bool _disposed = false;
  int _generation = 0;
  OfflineSpeechStatus _status = OfflineSpeechStatus.idle;

  OfflineSpeechStatus get status => _status;
  bool get muted => _muted;
  String? get lastText => _lastText;

  Future<void> initialize() async {
    final pending = _initialization;
    if (pending != null) return pending;
    final next = _configureVoice();
    _initialization = next;
    try {
      await next;
    } catch (_) {
      if (identical(_initialization, next)) _initialization = null;
      rethrow;
    }
  }

  Future<void> _configureVoice() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    final raw = await _tts.getVoices;
    final voices = raw is List ? raw.whereType<Map>().toList() : const [];
    if (defaultTargetPlatform == TargetPlatform.android) {
      final voice = voices.where((voice) {
        final locale = voice['locale']?.toString().toLowerCase() ?? '';
        final network = voice['network_required'];
        final offline =
            network == false ||
            network == 0 ||
            network?.toString().toLowerCase() == 'false' ||
            network?.toString().toLowerCase() == '0';
        return locale.startsWith('en') && offline;
      }).firstOrNull;
      if (voice == null) {
        throw StateError(
          'Install an offline English voice in Android settings.',
        );
      }
      await _tts.setVoice({
        'name': voice['name'].toString(),
        'locale': voice['locale'].toString(),
      });
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final english = voices.where(
        (voice) =>
            voice['locale']?.toString().toLowerCase().startsWith('en') == true,
      );
      final compact = english.where((voice) => voice['quality'] == 'default');
      final voice = compact.firstOrNull ?? english.firstOrNull;
      if (voice == null || voice['identifier'] == null) {
        throw StateError('Install an English system voice in device settings.');
      }
      await _tts.setVoice({'identifier': voice['identifier'].toString()});
      return;
    }
    throw UnsupportedError('Offline system speech requires Android or iOS.');
  }

  Future<void> speak(String text) async {
    if (_disposed || _muted || text.trim().isEmpty) return;
    _lastText = text;
    final generation = ++_generation;
    // Interrupt old speech before queueing the new displayed instruction.
    try {
      await _tts.stop();
    } catch (_) {}
    final task = _pending.then((_) async {
      if (_disposed || _muted || generation != _generation) return;
      try {
        await initialize();
        if (_disposed || _muted || generation != _generation) return;
        _setStatus(OfflineSpeechStatus.speaking);
        final result = await _tts.speak(text);
        if (result == 0) throw StateError('System speech did not start.');
        if (!_disposed && generation == _generation && !_muted) {
          _setStatus(OfflineSpeechStatus.idle);
        }
      } catch (_) {
        if (!_disposed && generation == _generation) {
          _setStatus(OfflineSpeechStatus.failed);
        }
      }
    });
    _pending = task.catchError((Object _) {});
    await task;
  }

  Future<void> replay() async {
    final text = _lastText;
    if (text != null && !_muted) await speak(text);
  }

  Future<void> stop() async {
    if (_disposed) return;
    _generation++;
    try {
      await _tts.stop();
      if (!_disposed) {
        _setStatus(
          _muted ? OfflineSpeechStatus.muted : OfflineSpeechStatus.idle,
        );
      }
    } catch (_) {
      if (!_disposed) _setStatus(OfflineSpeechStatus.failed);
    }
  }

  Future<void> setMuted(bool muted) async {
    if (_disposed || _muted == muted) return;
    _muted = muted;
    await stop();
  }

  void _setStatus(OfflineSpeechStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    unawaited(_tts.stop());
    super.dispose();
  }
}
