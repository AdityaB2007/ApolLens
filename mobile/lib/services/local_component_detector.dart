// Gavin - Run the bundled component model locally; component labels are not item IDs.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import '../models/camera_frame.dart';
import '../models/detection.dart';
import '../models/recognition_state.dart';
import 'camera_tensor.dart';

const componentClasses = [
  '__background__',
  'main_battery',
  'cooling_fan',
  'ram_module',
  'storage_drive',
];

List<Detection> decodeComponentOutputs(
  List<dynamic> boxes,
  List<dynamic> scores,
  List<dynamic> labels,
  DetectorInput input,
) {
  if (boxes.length != scores.length * 4 ||
      labels.length != scores.length ||
      scores.length > 10000) {
    throw const FormatException('Invalid detector output lengths.');
  }
  final indices = List<int>.generate(scores.length, (i) => i);
  if (scores.any((score) => score is! num) ||
      boxes.any((coordinate) => coordinate is! num)) {
    throw const FormatException('Invalid detector output values.');
  }
  indices.sort((a, b) => (scores[b] as num).compareTo(scores[a] as num));
  final result = <Detection>[];
  for (final i in indices) {
    final score = (scores[i] as num).toDouble();
    final label = labels[i];
    if (!score.isFinite ||
        score < .5 ||
        score > 1 ||
        label is! int ||
        label <= 0 ||
        label >= componentClasses.length) {
      continue;
    }
    final raw = boxes.sublist(i * 4, i * 4 + 4).cast<num>();
    if (raw.any((value) => !value.isFinite)) continue;
    final box = Rect.fromLTRB(
      ((raw[0] * 640 - input.left) / input.resizedWidth).clamp(0, 1).toDouble(),
      ((raw[1] * 640 - input.top) / input.resizedHeight).clamp(0, 1).toDouble(),
      ((raw[2] * 640 - input.left) / input.resizedWidth).clamp(0, 1).toDouble(),
      ((raw[3] * 640 - input.top) / input.resizedHeight).clamp(0, 1).toDouble(),
    );
    if (box.isEmpty) continue;
    result.add(Detection(label: componentClasses[label], bounds: box));
    if (result.length == 20) break;
  }
  return result;
}

final class LocalComponentDetector {
  OrtSession? _session;
  Future<void>? _active;
  bool _busy = false, _disposed = false;
  static const modelAsset = 'assets/models/components.onnx';

  Future<FrameRecognition> recognize(CameraFrame frame, Future<void> cancel) {
    if (_disposed || _busy) {
      return Future.error(StateError('Local detector is closed or busy.'));
    }
    _busy = true;
    final task = _detect(frame, cancel).whenComplete(() => _busy = false);
    _active = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  Future<FrameRecognition> _detect(
    CameraFrame frame,
    Future<void> cancel,
  ) async {
    var cancelled = false;
    unawaited(cancel.then((_) => cancelled = true));
    void check() {
      if (_disposed || cancelled) throw StateError('Frame cancelled.');
    }

    check();
    final input = await compute(prepareDetectorInput, frame);
    check();
    var session = _session;
    if (session == null) {
      session = await OnnxRuntime().createSessionFromAsset(
        modelAsset,
        options: OrtSessionOptions(
          intraOpNumThreads: 2,
          interOpNumThreads: 1,
          providers: [OrtProvider.CPU],
        ),
      );
      _session = session;
      if (!listEquals(session.inputNames, ['images']) ||
          !setEquals(session.outputNames.toSet(), {
            'boxes',
            'scores',
            'labels',
          })) {
        _session = null;
        await session.close();
        throw const FormatException('Bundled detector contract mismatch.');
      }
    }
    check();
    OrtValue? tensor;
    Map<String, OrtValue> outputs = {};
    try {
      tensor = await OrtValue.fromList(input.pixels, [1, 3, 640, 640]);
      check();
      outputs = await session.run({'images': tensor});
      check();
      final boxesValue = outputs['boxes'];
      final scoresValue = outputs['scores'];
      final labelsValue = outputs['labels'];
      if (boxesValue == null ||
          scoresValue == null ||
          labelsValue == null ||
          boxesValue.dataType != OrtDataType.float32 ||
          scoresValue.dataType != OrtDataType.float32 ||
          labelsValue.dataType != OrtDataType.int64 ||
          boxesValue.shape.length != 2 ||
          boxesValue.shape[1] != 4 ||
          !listEquals(scoresValue.shape, [boxesValue.shape[0]]) ||
          !listEquals(labelsValue.shape, scoresValue.shape)) {
        throw const FormatException('Invalid native detector output schema.');
      }
      final boxes = await boxesValue.asFlattenedList();
      final scores = await outputs['scores']!.asFlattenedList();
      final labels = await outputs['labels']!.asFlattenedList();
      check();
      return FrameRecognition(
        sessionId: frame.sessionId,
        sequence: frame.sequence,
        recognition: RecognitionState.result(null),
        detections: decodeComponentOutputs(boxes, scores, labels, input),
        geometry: FrameGeometry(
          clockwiseQuarterTurns: input.turns,
          previewCrop: const Rect.fromLTWH(0, 0, 1, 1),
        ),
      );
    } finally {
      await Future.wait([
        for (final output in outputs.values) output.dispose(),
        if (tensor != null) tensor.dispose(),
      ]);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _active;
    final session = _session;
    _session = null;
    await session?.close();
  }
}
