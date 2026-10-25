// Gavin - Speak repair guidance with an installed local system voice.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum OfflineSpeechStatus { idle, speaking, paused, muted, failed }

final class OfflineSpeechService extends ChangeNotifier
    with WidgetsBindingObserver {
  OfflineSpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    WidgetsBinding.instance.addObserver(this);

    _tts.setStartHandler(() {
      if (_acceptEvents && _utterance != null && !_pauseRequested && !_paused) {
        _setStatus(OfflineSpeechStatus.speaking);
      }
    });
    _tts.setCompletionHandler(() {
      if (!_acceptEvents || _utterance == null) return;
      _finish();
      _setStatus(OfflineSpeechStatus.idle);
    });
    _tts.setCancelHandler(() {
      if (!_acceptEvents || _utterance == null) return;
      _finish();
      _setStatus(OfflineSpeechStatus.idle);
    });
    _tts.setErrorHandler((message) {
      if (_acceptEvents && _utterance != null) _fail(message);
    });
  }

  final FlutterTts _tts;

  Future<void>? _initialization;
  String? _lastText;
  String? _errorMessage;
  Future<void> _commands = Future.value();
  Completer<void>? _utterance;
  bool _pauseRequested = false;
  bool _acceptEvents = false;

  bool _initialized = false;
  bool _muted = false;
  bool _disposed = false;
  bool _paused = false;

  int _generation = 0;

  OfflineSpeechStatus _status = OfflineSpeechStatus.idle;

  OfflineSpeechStatus get status => _status;
  bool get muted => _muted;
  String? get lastText => _lastText;
  String? get errorMessage => _errorMessage;

  /// Initialize the native speech engine and select an available voice.
  Future<void> initialize() async {
    if (_disposed) {
      throw StateError('Speech service has been disposed.');
    }

    if (_initialized) return;

    final existing = _initialization;
    if (existing != null) {
      await existing;
      return;
    }

    final initialization = _configureVoice();
    _initialization = initialization;

    try {
      await initialization;
      _initialized = true;
    } catch (_) {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
      rethrow;
    }
  }

  Future<void> _configureVoice() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw UnsupportedError('Offline system speech requires Android or iOS.');
    }

    // Native calls return on acceptance; the service owns utterance completion.
    // This avoids flutter_tts replacing the pending iOS result on resume.
    await _tts.awaitSpeakCompletion(false);
    await _tts.setLanguage('en-US');

    final raw = await _tts.getVoices;
    final voices = raw is List ? raw.whereType<Map>().toList() : <Map>[];

    if (defaultTargetPlatform == TargetPlatform.android) {
      final candidates = voices.where((voice) {
        final locale = voice['locale']?.toString().toLowerCase() ?? '';
        final network = voice['network_required'];

        final offline =
            network == false ||
            network == 0 ||
            network?.toString().toLowerCase() == 'false' ||
            network?.toString() == '0';

        return locale.startsWith('en') &&
            offline &&
            voice['name'] != null &&
            voice['locale'] != null;
      }).toList();

      if (candidates.isEmpty) {
        throw StateError(
          'No confirmed offline English voice was found. '
          'Install an English voice in Android text-to-speech settings.',
        );
      }

      candidates.sort((a, b) {
        final aUs = a['locale'].toString().toLowerCase() == 'en-us';
        final bUs = b['locale'].toString().toLowerCase() == 'en-us';
        if (aUs == bUs) return 0;
        return aUs ? -1 : 1;
      });

      final voice = candidates.first;

      await _tts.setVoice({
        'name': voice['name'].toString(),
        'locale': voice['locale'].toString(),
      });

      return;
    }

    // iOS voice metadata does not reliably indicate offline availability.
    final candidates = voices.where((voice) {
      final locale = voice['locale']?.toString().toLowerCase() ?? '';
      return locale.startsWith('en') && voice['identifier'] != null;
    }).toList();

    if (candidates.isEmpty) {
      throw StateError(
        'No English system voice was found. '
        'Check the available voices in iOS settings.',
      );
    }

    candidates.sort((a, b) {
      final aUs = a['locale'].toString().toLowerCase() == 'en-us';
      final bUs = b['locale'].toString().toLowerCase() == 'en-us';
      if (aUs == bUs) return 0;
      return aUs ? -1 : 1;
    });

    await _tts.setVoice({
      'identifier': candidates.first['identifier'].toString(),
    });
  }

  /// Completes when the instruction finishes or is intentionally canceled.
  Future<void> speak(String text) {
    if (_disposed || text.trim().isEmpty) return Future.value();
    _lastText = text;
    if (_muted) return Future.value();
    final generation = ++_generation;
    _finish();
    final utterance = _utterance = Completer<void>();
    _errorMessage = null;
    _setStatus(OfflineSpeechStatus.idle);
    unawaited(
      _enqueue(generation, () async {
        await _tts.stop();
        if (!_isCurrent(generation)) return;
        await initialize();
        if (!_isCurrent(generation)) return;
        _acceptEvents = true;
        _setStatus(OfflineSpeechStatus.speaking);
        if (await _tts.speak(text) == 0 && _isCurrent(generation)) {
          _fail('The system speech engine did not start.');
        }
      }),
    );
    return utterance.future;
  }

  Future<void> replay() =>
      _lastText == null ? Future.value() : speak(_lastText!);

  Future<void> pause() {
    if (_disposed ||
        _muted ||
        _status != OfflineSpeechStatus.speaking ||
        _pauseRequested) {
      return Future.value();
    }
    final generation = _generation;
    final utterance = _utterance;
    _pauseRequested = true;
    return _enqueue(generation, () async {
      final result = await _tts.pause();
      if (!_isCurrent(generation) ||
          _utterance != utterance ||
          !_pauseRequested) {
        return;
      }
      if (result != 1) {
        _fail('The device could not pause speech.');
        return;
      }
      _paused = true;
      _setStatus(OfflineSpeechStatus.paused);
    });
  }

  Future<void> resume() async {
    if (_disposed || _muted || !_paused || _utterance == null) return;
    final generation = _generation;
    final utterance = _utterance!;
    _paused = false;
    _pauseRequested = false;
    await _enqueue(generation, () async {
      _setStatus(OfflineSpeechStatus.speaking);
      // No stop: flutter_tts continues the saved position on both platforms.
      if (await _tts.speak(_lastText!) == 0 && _isCurrent(generation)) {
        _fail('The system speech engine could not resume.');
      }
    });
    await utterance.future;
  }

  Future<void> stop() {
    if (_disposed) return Future.value();
    final generation = ++_generation;
    _finish();
    _setStatus(_muted ? OfflineSpeechStatus.muted : OfflineSpeechStatus.idle);
    return _enqueue(generation, () async {
      await _tts.stop();
    }, allowMuted: true);
  }

  Future<void> setMuted(bool muted) async {
    if (_disposed || _muted == muted) return;
    _muted = muted;
    if (muted) {
      await stop();
    } else {
      _setStatus(OfflineSpeechStatus.idle);
    }
  }

  Future<void> _enqueue(
    int generation,
    Future<void> Function() command, {
    bool allowMuted = false,
  }) {
    final next = _commands.then((_) async {
      if (_disposed || generation != _generation || (_muted && !allowMuted)) {
        return;
      }
      try {
        await command().timeout(const Duration(seconds: 10));
      } catch (error) {
        if (!_disposed && generation == _generation) _fail(error);
      }
    });
    _commands = next;
    return next;
  }

  void _finish() {
    final utterance = _utterance;
    _utterance = null;
    _acceptEvents = false;
    _paused = false;
    _pauseRequested = false;
    if (utterance != null && !utterance.isCompleted) utterance.complete();
  }

  void _fail(Object error) {
    _generation++;
    _errorMessage = error.toString();
    _finish();
    _setStatus(OfflineSpeechStatus.failed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(stop());
  }

  bool _isCurrent(int generation) {
    return !_disposed && !_muted && generation == _generation;
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
    WidgetsBinding.instance.removeObserver(this);
    _finish();
    unawaited(_commands.then((_) => _tts.stop()).catchError((Object _) => 0));

    super.dispose();
  }
}
