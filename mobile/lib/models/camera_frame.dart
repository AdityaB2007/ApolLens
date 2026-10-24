// Gavin - Owned camera buffers and the recognizer's frame-specific response.
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'detection.dart';
import 'recognition_state.dart';

final class CameraFrame {
  CameraFrame.capture({
    required CameraImage image,
    required this.sessionId,
    required this.sequence,
    required DateTime capturedAt,
    required this.camera,
    required this.orientation,
    required this.platform,
    required this.previewMirrored,
  })  : capturedAt = capturedAt.toUtc(),
        width = image.width,
        height = image.height,
        format = image.format.group,
        rawFormat = image.format.raw as int {
    final size = image.planes.fold(0, (n, plane) => n + plane.bytes.length);
    if (sessionId.trim().isEmpty ||
        sessionId != sessionId.trim() ||
        sequence < 0 ||
        width <= 0 ||
        height <= 0 ||
        format == ImageFormatGroup.unknown ||
        image.planes.isEmpty ||
        size > maxBytes ||
        !const [0, 90, 180, 270].contains(camera.sensorOrientation)) {
      throw ArgumentError('Invalid camera frame metadata or buffer size.');
    }
    for (final plane in image.planes) {
      if (plane.bytes.isEmpty ||
          plane.bytesPerRow <= 0 ||
          (plane.bytesPerPixel != null && plane.bytesPerPixel! <= 0) ||
          (plane.width != null && plane.width! <= 0) ||
          (plane.height != null && plane.height! <= 0)) {
        throw ArgumentError('Invalid camera plane metadata.');
      }
    }
    // Copy before returning to the camera callback; plugin buffers may be reused.
    planes = List.unmodifiable(image.planes.map(FramePlane._copy));
  }

  static const maxBytes = 16 * 1024 * 1024;
  final String sessionId;
  final int sequence;
  // Client receipt time, not a hardware sensor timestamp.
  final DateTime capturedAt;
  final int width, height;
  final ImageFormatGroup format;
  final int rawFormat;
  final CameraDescription camera;
  final DeviceOrientation orientation;
  final TargetPlatform platform;
  final bool previewMirrored;
  late final List<FramePlane> planes;
}

final class FramePlane {
  FramePlane._copy(Plane plane)
      : bytes = Uint8List.fromList(plane.bytes).asUnmodifiableView(),
        bytesPerRow = plane.bytesPerRow,
        bytesPerPixel = plane.bytesPerPixel,
        width = plane.width,
        height = plane.height;

  final Uint8List bytes;
  // Preserve native strides and nullable dimensions; no pixel conversion here.
  final int bytesPerRow;
  final int? bytesPerPixel, width, height;
}

typedef FrameRecognizer = Future<FrameRecognition> Function(
  CameraFrame frame,
  Future<void> cancel,
);

final class FrameRecognition {
  FrameRecognition({
    required this.sessionId,
    required this.sequence,
    required this.recognition,
    this.blocked = false,
    List<Detection> detections = const [],
  }) : detections = List.unmodifiable(detections) {
    if (sessionId.trim().isEmpty ||
        sessionId != sessionId.trim() ||
        sequence < 0 ||
        detections.length > 100 ||
        !const [RecognitionStatus.unknown, RecognitionStatus.identified]
            .contains(recognition.status) ||
        (blocked &&
            (recognition.status != RecognitionStatus.unknown ||
                detections.isNotEmpty))) {
      throw ArgumentError('Invalid frame recognition result.');
    }
  }

  final String sessionId;
  final int sequence;
  final RecognitionState recognition;
  final bool blocked;
  // Upright, unmirrored source coordinates; the preview handles presentation.
  final List<Detection> detections;
}
