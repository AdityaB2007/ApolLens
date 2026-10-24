// Gavin - Connects ApolLens recognition requests to camera-view state.
import 'package:apollens/models/recognition_state.dart';
import 'package:flutter/foundation.dart';

final class VisionService extends ValueNotifier<RecognitionState> {
  VisionService({this.identify}) : super(RecognitionState.unavailable);

  // Indi's adapter supplies the request; no provider means unavailable.
  final Future<String?> Function()? identify;
  bool _disposed = false;
  int _generation = 0;

  Future<void> recognize() async {
    final request = identify;
    if (request == null || _disposed) return;
    final generation = ++_generation;
    value = RecognitionState.identifying;
    if (_disposed || generation != _generation) return;
    try {
      final label = await request();
      if (!_disposed && generation == _generation) {
        value = RecognitionState.result(label);
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        value = RecognitionState.unavailable;
      }
    }
  }

  // Clear identity and invalidate pending work when the camera session changes.
  void reset() {
    if (_disposed) return;
    _generation++;
    value = RecognitionState.unavailable;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
