// Gavin - Connects ApolLens recognition requests to camera-view state.
import 'package:apollens/models/recognition_state.dart';
import 'package:flutter/foundation.dart';

final class VisionService extends ValueNotifier<RecognitionState> {
  VisionService({this.identify}) : super(RecognitionState.unavailable);

  // Indi's adapter supplies the request; no provider means unavailable.
  final Future<String?> Function()? identify;
  bool _disposed = false;

  Future<void> recognize() async {
    final request = identify;
    if (request == null || _disposed) return;
    value = RecognitionState.identifying;
    try {
      final label = await request();
      if (!_disposed) value = RecognitionState.result(label);
    } catch (_) {
      if (!_disposed) value = RecognitionState.unavailable;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
