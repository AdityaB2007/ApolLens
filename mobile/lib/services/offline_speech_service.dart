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
      if (!_disposed && !_muted) {
        _setStatus(OfflineSpeechStatus.speaking);
      }
    });

    _tts.setCompletionHandler(() {
      if (!_disposed && !_muted) {
        _setStatus(OfflineSpeechStatus.idle);
      }
    });

    _tts.setPauseHandler(() {
      if (!_disposed && !_muted) {
        _setStatus(OfflineSpeechStatus.paused);
      }
    });

    _tts.setContinueHandler(() {
      if (!_disposed && !_muted) {
        _setStatus(OfflineSpeechStatus.speaking);
      }
    });

    _tts.setErrorHandler((message) {
      if (!_disposed) {
        _errorMessage = message.toString();
        _setStatus(OfflineSpeechStatus.failed);
      }
    });
  }

  final FlutterTts _tts;

  Future<void>? _initialization;
  String? _lastText;
  String? _errorMessage;

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
      throw UnsupportedError(
        'Offline system speech requires Android or iOS.',
      );
    }

    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');

    final raw = await _tts.getVoices;
    final voices = raw is List ? raw.whereType<Map>().toList() : <Map>[];

    if (defaultTargetPlatform == TargetPlatform.android) {
      final candidates = voices.where((voice) {
        final locale = voice['locale']?.toString().toLowerCase() ?? '';
        final network = voice['network_required'];

        final offline = network == false ||
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

  /// Speak the currently displayed instruction.
  /// Calling this with a new instruction stops the previous utterance.
  Future<void> speak(String text) async {
    if (_disposed || text.trim().isEmpty) return;

    _lastText = text;

    if (_muted) return;

    final generation = ++_generation;
    _paused = false;
    _errorMessage = null;

    try {
      // Stop old speech before initializing or starting the new instruction.
      await _tts.stop();

      if (!_isCurrent(generation)) return;

      await initialize();

      if (!_isCurrent(generation)) return;

      _setStatus(OfflineSpeechStatus.speaking);

      final result = await _tts.speak(text);

      if (result == 0) {
        throw StateError('The system speech engine did not start.');
      }

      if (_isCurrent(generation) && !_paused) {
        _setStatus(OfflineSpeechStatus.idle);
      }
    } catch (error) {
      if (_isCurrent(generation)) {
        _errorMessage = error.toString();
        _setStatus(OfflineSpeechStatus.failed);
      }
    }
  }

  /// Replay the last instruction from the beginning.
  Future<void> replay() async {
    final text = _lastText;
    if (_disposed || _muted || text == null) return;
    await speak(text);
  }

  /// Pause the current utterance.
  ///
  /// Android pause requires SDK 26 or newer in flutter_tts.
  Future<void> pause() async {
    if (_disposed || _status != OfflineSpeechStatus.speaking) return;

    try {
      final result = await _tts.pause();

      if (_disposed) return;

      if (result == 1) {
        _paused = true;
        _setStatus(OfflineSpeechStatus.paused);
      } else {
        _errorMessage = 'The device could not pause speech.';
        _setStatus(OfflineSpeechStatus.failed);
      }
    } catch (error) {
      if (!_disposed) {
        _errorMessage = error.toString();
        _setStatus(OfflineSpeechStatus.failed);
      }
    }
  }

  /// Continue a paused utterance.
  ///
  /// flutter_tts uses platform-specific continuation behavior when speak()
  /// is called after pause(); verify this on both target platforms.
  Future<void> resume() async {
    if (_disposed ||
        _muted ||
        !_paused ||
        _status != OfflineSpeechStatus.paused ||
        _lastText == null) {
      return;
    }

    final generation = _generation;
    final text = _lastText!;

    try {
      // Do not stop() here: Android uses the saved speech position to resume.
      _paused = false;

      final result = await _tts.speak(text);

      if (result == 0) {
        throw StateError('The system speech engine could not resume.');
      }

      if (_isCurrent(generation) && !_paused) {
        _setStatus(OfflineSpeechStatus.idle);
      }
    } catch (error) {
      if (_isCurrent(generation)) {
        _errorMessage = error.toString();
        _setStatus(OfflineSpeechStatus.failed);
      }
    }
  }

  /// Stop playback without removing the displayed instruction.
  Future<void> stop() async {
    if (_disposed) return;

    _generation++;
    _paused = false;

    try {
      await _tts.stop();

      if (!_disposed) {
        _setStatus(
          _muted ? OfflineSpeechStatus.muted : OfflineSpeechStatus.idle,
        );
      }
    } catch (error) {
      if (!_disposed) {
        _errorMessage = error.toString();
        _setStatus(OfflineSpeechStatus.failed);
      }
    }
  }

  /// Muting stops current speech. Unmuting does not start speech automatically.
  Future<void> setMuted(bool muted) async {
    if (_disposed || _muted == muted) return;

    _muted = muted;

    if (muted) {
      await stop();
      if (!_disposed) {
        _setStatus(OfflineSpeechStatus.muted);
      }
    } else {
      _setStatus(OfflineSpeechStatus.idle);
    }
  }

  /// Stop speech when the application leaves the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(stop());
    }
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
    unawaited(_tts.stop());

    super.dispose();
  }
}
