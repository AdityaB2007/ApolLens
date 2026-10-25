// Gavin - Confirmed component boxes; preview gestures pass through.
import '../models/camera_frame.dart';
import '../models/detection.dart';
import 'package:flutter/material.dart';

class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay(
    this.child,
    this.boxes, {
    super.key,
    this.frame,
    this.geometry,
  });
  final Widget child;
  final List<Detection> boxes;
  final CameraFrame? frame;
  final FrameGeometry? geometry;

  @override
  Widget build(BuildContext context) => Semantics(
    label: boxes.isEmpty
        ? null
        : 'Components: ${boxes.map((box) => componentName(box.label)).join(', ')}',
    child: CustomPaint(
      foregroundPainter: _DetectionPainter(boxes, frame, geometry),
      child: child,
    ),
  );
}

class _DetectionPainter extends CustomPainter {
  _DetectionPainter(this.detections, this.frame, this.geometry);
  final List<Detection> detections;
  final CameraFrame? frame;
  final FrameGeometry? geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final source = frame;
    final transform = geometry;
    if (source == null || transform == null) return;
    final paint = Paint()
      ..color = const Color(0xFFF4C77D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final detection in detections) {
      final box = transform.mapBox(detection.bounds, source, size);
      if (box == null) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(4)),
        paint,
      );
      final label = TextPainter(
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: componentName(detection.label),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      )..layout(maxWidth: (size.width - 16).clamp(1, size.width));
      final origin = Offset(
        box.left.clamp(0, (size.width - label.width - 12).clamp(0, size.width)),
        (box.top - label.height - 8).clamp(
          0,
          (size.height - label.height - 8).clamp(0, size.height),
        ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          origin & Size(label.width + 12, label.height + 6),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xE6202923),
      );
      label.paint(canvas, origin + const Offset(6, 3));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DetectionPainter oldDelegate) => true;
}
