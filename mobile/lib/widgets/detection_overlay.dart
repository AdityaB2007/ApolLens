// Gavin - Boxes over ApolLens camera previews; touches pass to the child.
import 'package:apollens/models/detection.dart';
import 'package:flutter/material.dart';

class DetectionOverlay extends CustomPaint {
  DetectionOverlay(Widget child, List<Detection> boxes, {super.key})
    : super(child: child, foregroundPainter: _DetectionPainter(boxes));
}

class _DetectionPainter extends CustomPainter {
  _DetectionPainter(this.detections);
  final List<Detection> detections;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB3452E)
      ..style = PaintingStyle.stroke;
    canvas.save();
    // Map normalized boxes to the full, uncropped preview.
    canvas.scale(size.width, size.height);
    for (final detection in detections) {
      canvas.drawRect(detection.bounds, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DetectionPainter oldDelegate) => true;
}
