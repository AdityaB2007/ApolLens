// Gavin - Convert owned native camera planes to the detector's RGB letterbox.
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import '../models/camera_frame.dart';

final class DetectorInput {
  DetectorInput(
    this.pixels,
    this.turns,
    this.width,
    this.height,
    this.resizedWidth,
    this.resizedHeight,
    this.left,
    this.top,
  );
  final Float32List pixels;
  final int turns, width, height, resizedWidth, resizedHeight, left, top;
}

int cameraQuarterTurns(CameraFrame frame) {
  // AVFoundation rotates the video output before delivering its pixel buffer.
  if (frame.platform == TargetPlatform.iOS) return 0;
  if (frame.platform != TargetPlatform.android) {
    throw UnsupportedError('Camera inference requires Android or iOS.');
  }
  final device = switch (frame.orientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };
  final front = frame.camera.lensDirection == CameraLensDirection.front;
  return ((frame.camera.sensorOrientation + (front ? device : -device)) %
          360) ~/
      90;
}

DetectorInput prepareDetectorInput(CameraFrame frame) {
  const size = 640;
  final turns = cameraQuarterTurns(frame);
  final width = turns.isOdd ? frame.height : frame.width;
  final height = turns.isOdd ? frame.width : frame.height;
  final scale = math.min(size / width, size / height);
  final rw = math.max(1, (width * scale).round());
  final rh = math.max(1, (height * scale).round());
  final left = (size - rw) ~/ 2, top = (size - rh) ~/ 2;
  final tensor = Float32List(3 * size * size)
    ..fillRange(0, 3 * size * size, 114 / 255);
  if (!((frame.format == ImageFormatGroup.bgra8888 &&
          frame.planes.length == 1) ||
      (frame.format == ImageFormatGroup.yuv420 && frame.planes.length == 3))) {
    throw UnsupportedError('Unsupported native camera pixel format.');
  }

  List<double> pixel(int ux, int uy) {
    // AVFoundation mirrors front-camera video buffers, unlike Android YUV.
    if (frame.platform == TargetPlatform.iOS &&
        frame.camera.lensDirection == CameraLensDirection.front) {
      ux = width - 1 - ux;
    }
    final (x, y) = switch (turns) {
      1 => (uy, frame.height - 1 - ux),
      2 => (frame.width - 1 - ux, frame.height - 1 - uy),
      3 => (frame.width - 1 - uy, ux),
      _ => (ux, uy),
    };
    final planes = frame.planes;
    if (frame.format == ImageFormatGroup.bgra8888) {
      final index = y * planes[0].bytesPerRow + x * 4;
      return [
        planes[0].bytes[index + 2].toDouble(),
        planes[0].bytes[index + 1].toDouble(),
        planes[0].bytes[index].toDouble(),
      ];
    }
    int sample(int plane, int px, int py) {
      final p = planes[plane];
      return p.bytes[py * p.bytesPerRow + px * (p.bytesPerPixel ?? 1)];
    }

    // Android YUV_420_888: independently strided Y, U and V planes.
    final yValue = math.max(0, sample(0, x, y) - 16);
    final u = sample(1, x ~/ 2, y ~/ 2) - 128;
    final v = sample(2, x ~/ 2, y ~/ 2) - 128;
    return [
      1.164 * yValue + 1.596 * v,
      1.164 * yValue - .392 * u - .813 * v,
      1.164 * yValue + 2.017 * u,
    ].map((v) => v.clamp(0, 255).toDouble()).toList();
  }

  // Bilinear sampling and CHW normalization run in a worker isolate.
  for (var dy = 0; dy < rh; dy++) {
    final sy = ((dy + .5) * height / rh - .5).clamp(0, height - 1).toDouble();
    final y0 = sy.floor(), y1 = math.min(y0 + 1, height - 1);
    final fy = sy - y0;
    for (var dx = 0; dx < rw; dx++) {
      final sx = ((dx + .5) * width / rw - .5).clamp(0, width - 1).toDouble();
      final x0 = sx.floor(), x1 = math.min(x0 + 1, width - 1);
      final fx = sx - x0;
      final a = pixel(x0, y0), b = pixel(x1, y0);
      final c = pixel(x0, y1), d = pixel(x1, y1);
      for (var channel = 0; channel < 3; channel++) {
        final upper = a[channel] * (1 - fx) + b[channel] * fx;
        final lower = c[channel] * (1 - fx) + d[channel] * fx;
        tensor[channel * size * size + (top + dy) * size + left + dx] =
            (upper * (1 - fy) + lower * fy) / 255;
      }
    }
  }
  return DetectorInput(tensor, turns, width, height, rw, rh, left, top);
}
