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
        : 'Components: ${boxes.map((box) => box.label).join(', ')}',
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
      ..color = const Color(0xFFB3452E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final detection in detections) {
      final box = transform.mapBox(detection.bounds, source, size);
      if (box == null) continue;
      canvas.drawRect(box, paint);
      final label = TextPainter(
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: detection.label,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Roboto',
            color: Colors.white,
            backgroundColor: Color(0xFFB3452E),
          ),
        ),
      )..layout(maxWidth: size.width);
      label.paint(
        canvas,
        Offset(
          box.left.clamp(0, size.width - label.width),
          box.top.clamp(0, (size.height - label.height).clamp(0, size.height)),
        ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DetectionPainter oldDelegate) => true;
}
