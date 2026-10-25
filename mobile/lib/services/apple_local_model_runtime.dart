// Gavin - Use Apple's on-device model when ready; keep the offline LiteRT fallback.
import 'dart:async';
import 'package:apple_foundation_models/apple_foundation_models.dart' as apple;
import 'package:flutter/foundation.dart';
import 'local_model_runtime.dart';

final class AppleLocalModelRuntime implements LocalModelRuntime {
  AppleLocalModelRuntime({required this.fallback});
  final LocalModelRuntime fallback;
  Future<void>? _initialization, _active;
  StreamIterator<String>? _tokens;
  bool _native = false, _disposed = false, _generating = false;
  int _generation = 0;

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      try {
        _native = await apple.AppleFoundationModels.isAvailable;
      } catch (_) {
        _native = false;
      }
    }
    if (_disposed) throw StateError('Local runtime is closed.');
    if (!_native) await fallback.initialize();
  }

  @override
  Future<bool> loadActiveModel() async {
    if (_disposed) throw StateError('Local runtime is closed.');
    return _native || await fallback.loadActiveModel();
  }

  @override
  Future<void> install(void Function(int) onProgress) async {
    if (_disposed) throw StateError('Local runtime is closed.');
    if (_native) {
      onProgress(100);
    } else {
      await fallback.install(onProgress);
    }
  }

  @override
  Future<String> generate(String systemInstruction, String prompt) {
    if (_disposed) return Future.error(StateError('Local runtime is closed.'));
    if (!_native) return fallback.generate(systemInstruction, prompt);
    if (_generating) {
      return Future.error(StateError('A response is in progress.'));
    }
    _generating = true;
    final result = _generate(systemInstruction, prompt, _generation);
    _active = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<String> _generate(
    String instructions,
    String prompt,
    int generation,
  ) async {
    apple.LanguageModelSession? session;
    StreamIterator<String>? tokens;
    try {
      session = await apple.LanguageModelSession.create(
        instructions: instructions,
      );
      if (_disposed || generation != _generation) {
        throw StateError('Cancelled.');
      }
      tokens = _tokens = StreamIterator(
        session.stream(
          prompt,
          options: const apple.GenerationOptions(
            sampling: apple.GreedySampling(),
            maximumResponseTokens: 384,
          ),
        ),
      );
      var response = '';
      while (await tokens.moveNext()) {
        if (_disposed || generation != _generation) {
          throw StateError('Cancelled.');
        }
        // Native events contain the full text so far, rather than token deltas.
        response = tokens.current;
      }
      if (_disposed || generation != _generation) {
        throw StateError('Cancelled.');
      }
      return response;
    } finally {
      if (identical(_tokens, tokens)) _tokens = null;
      try {
        await tokens?.cancel();
      } finally {
        try {
          await session?.dispose();
        } finally {
          _generating = false;
        }
      }
    }
  }

  @override
  Future<void> cancelGeneration() async {
    if (!_native) return fallback.cancelGeneration();
    _generation++;
    final active = _active;
    await _tokens?.cancel();
    await active;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancelGeneration();
    await fallback.dispose();
  }
}
