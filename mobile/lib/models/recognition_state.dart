// Gavin - Recognition states for the ApolLens camera view.
enum RecognitionStatus { unavailable, identifying, unknown, identified }

final class RecognitionState {
  const RecognitionState._(this.status, [this.label]);

  static const unavailable = RecognitionState._(RecognitionStatus.unavailable);
  static const identifying = RecognitionState._(RecognitionStatus.identifying);

  // A missing or blank label must never become an identified item.
  factory RecognitionState.result(String? label) {
    final normalized = label?.trim();
    return normalized == null || normalized.isEmpty
        ? const RecognitionState._(RecognitionStatus.unknown)
        : RecognitionState._(RecognitionStatus.identified, normalized);
  }

  final RecognitionStatus status;
  final String? label;
}
