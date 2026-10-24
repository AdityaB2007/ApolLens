// Gavin - Play ApolLens speech and release the native player.
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

final class AudioPlayback {
  AudioPlayback({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  Future<void> _pending = Future.value();
  Future<void>? _closing;

  Future<void> play(Uint8List bytes) =>
      _run(() => _player.play(BytesSource(bytes, mimeType: 'audio/mpeg')));
  Future<void> stop() => _run(_player.stop);

  // Run native commands in order; closing skips anything still queued.
  Future<void> _run(Future<void> Function() operation) async {
    if (_closing != null) throw StateError('Audio player is closed.');
    final task = _pending.then((_) async {
      if (_closing == null) await operation();
    });
    _pending = task.catchError((Object _) {});
    return task;
  }

  Future<void> dispose() =>
      _closing ??= _pending.then((_) => _player.dispose());
}
