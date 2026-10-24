// Gavin - Component data used by the live camera overlay.
import 'dart:ui';

final class Detection {
  Detection({required this.label, required this.bounds}) {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'Expected a component name');
    }
    if (!bounds.isFinite ||
        bounds.left < 0 ||
        bounds.top < 0 ||
        bounds.right > 1 ||
        bounds.bottom > 1 ||
        bounds.isEmpty) {
      throw ArgumentError.value(bounds, 'bounds', 'Expected a box within 0..1');
    }
  }

  final String label;

  // Normalized upright-image coordinates, before preview scaling or cropping.
  final Rect bounds;
}
