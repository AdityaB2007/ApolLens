// Gavin - Keep live recognition bounded and discard old camera-session results.
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/camera_frame.dart';
import '../models/recognition_state.dart';

final class FrameController extends ValueNotifier<RecognitionState> {
  FrameController({
    this.recognize,
    this.freshness = const Duration(seconds: 2),
    this.timeout = const Duration(seconds: 5),
    this.clock = DateTime.now,
  }) : super(RecognitionState.unavailable) {
    if (freshness <= Duration.zero || timeout <= Duration.zero) {
      throw ArgumentError('Frame deadlines must be positive.');
    }
  }

  final FrameRecognizer? recognize;
  final Duration freshness, timeout;
  final DateTime Function() clock;
  FrameRecognition? get result => _result;
  CameraFrame? get resultFrame => _resultFrame;
  FrameRecognition? _result;
  CameraFrame? _resultFrame, _latest;
  String? _session;
  int _sequence = -1, _generation = 0, _publishing = 0;
  bool _busy = false, _disposed = false;
  Completer<void>? _cancel;
  Timer? _expiry, _deadline;

  bool _fresh(CameraFrame frame) {
    final age = clock().difference(frame.capturedAt);
    return !age.isNegative && age < freshness;
  }

  void submit(CameraFrame frame) {
    if (_disposed || recognize == null || !_fresh(frame)) return;
    _session ??= frame.sessionId;
    if (frame.sessionId != _session || frame.sequence <= _sequence) return;
    _sequence = frame.sequence;
    _latest = frame;
    unawaited(_drain());
  }

  void _publish(RecognitionState state) {
    _publishing++;
    try {
      if (identical(value, state)) {
        notifyListeners();
      } else {
        value = state;
      }
    } finally {
      _publishing--;
      if (_disposed && _publishing == 0) super.dispose();
    }
  }

  Future<void> _drain() async {
    if (_busy || _disposed || _latest == null) return;
    final frame = _latest!;
    _latest = null;
    if (!_fresh(frame)) return;
    _busy = true;
    final generation = _generation;
    final cancel = _cancel = Completer<void>();
    final deadline = _deadline = Timer(timeout, () {
      if (!_disposed && generation == _generation) _invalidate();
    });
    try {
      if (value.status == RecognitionStatus.unavailable) {
        _publish(RecognitionState.identifying);
      }
      if (_disposed || generation != _generation) return;
      final response = await recognize!(frame, cancel.future);
      if (_disposed || generation != _generation) return;
      if (response.sessionId != frame.sessionId ||
          response.sequence != frame.sequence ||
          !_fresh(frame)) {
        throw StateError('Recognition does not match a fresh requested frame.');
      }
      _expiry?.cancel();
      _result = response;
      _resultFrame = frame;
      _expiry = Timer(freshness - clock().difference(frame.capturedAt), () {
        if (_disposed || generation != _generation) return;
        _result = null;
        _resultFrame = null;
        _publish(value);
      });
      // A refresh does not briefly erase the existing manual or progress.
      _publish(response.recognition);
    } catch (_) {
      if (!_disposed && generation == _generation) _invalidate();
    } finally {
      deadline.cancel();
      if (!cancel.isCompleted) cancel.complete();
      _cancel = null;
      // Even cancellation/timeout waits for the provider to settle before reuse.
      _busy = false;
      if (!_disposed) unawaited(_drain());
    }
  }

  void _invalidate() {
    _generation++;
    _deadline?.cancel();
    final cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
    _latest = null;
    _expiry?.cancel();
    _result = null;
    _resultFrame = null;
    if (!_disposed) _publish(RecognitionState.unavailable);
  }

  void reset() {
    if (_disposed) return;
    _session = null;
    _sequence = -1;
    _invalidate();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _invalidate();
    if (_publishing == 0) super.dispose();
  }
}
