// Gavin - Pair a frozen component location with the exact frame it came from.
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../models/camera_frame.dart';
import 'camera_tensor.dart';
import 'frame_controller.dart';

final class ComponentSnapshot {
  ComponentSnapshot._(this.frame, this.result, this.label);
  final CameraFrame frame;
  final FrameRecognition result;
  final String label;
  int get count => result.detections.where((box) => box.label == label).length;

  static ComponentSnapshot? capture(FrameController frames, String label) {
    final frame = frames.resultFrame;
    final result = frames.result;
    if (frame == null || result == null || result.blocked) return null;
    final age = frames.clock().difference(frame.capturedAt);
    if (age.isNegative ||
        age >= frames.freshness ||
        result.sessionId != frame.sessionId ||
        result.sequence != frame.sequence ||
        result.geometry?.clockwiseQuarterTurns != cameraQuarterTurns(frame) ||
        !result.detections.any((box) => box.label == label)) {
      return null;
    }
    return ComponentSnapshot._(frame, result, label);
  }

  Future<ui.Image> render() async {
    final pixels = await compute(_snapshotPixels, frame);
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels.rgba);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: pixels.width,
        height: pixels.height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

({Uint8List rgba, int width, int height}) _snapshotPixels(CameraFrame frame) {
  // Reuse the detector's tested rotation, mirroring and native-stride conversion.
  final input = prepareDetectorInput(frame);
  final width = input.resizedWidth, height = input.resizedHeight;
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final source = (input.top + y) * 640 + input.left + x;
      final destination = (y * width + x) * 4;
      for (var channel = 0; channel < 3; channel++) {
        rgba[destination +
            channel] = (input.pixels[channel * 640 * 640 + source] * 255)
            .round()
            .clamp(0, 255);
      }
      rgba[destination + 3] = 255;
    }
  }
  return (rgba: rgba, width: width, height: height);
}
