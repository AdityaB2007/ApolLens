// Gavin - Recognition states for the ApolLens camera view.
enum RecognitionStatus { unavailable, identifying, unknown, identified }

final class RecognitionState {
  const RecognitionState._(this.status, [this.label, this.itemId]);

  static const unavailable = RecognitionState._(RecognitionStatus.unavailable);
  static const identifying = RecognitionState._(RecognitionStatus.identifying);

  // A missing or blank label must never become an identified item.
  factory RecognitionState.result(String? label, {String? itemId}) {
    if (itemId != null && (itemId.trim().isEmpty || itemId != itemId.trim())) {
      throw ArgumentError('Item ID must be a nonempty exact catalog ID.');
    }
    final normalized = label?.trim();
    return normalized == null || normalized.isEmpty
        ? const RecognitionState._(RecognitionStatus.unknown)
        : RecognitionState._(RecognitionStatus.identified, normalized, itemId);
  }

  final RecognitionStatus status;
  final String? label;
  // A display label alone does not select a repair manual.
  final String? itemId;
}
