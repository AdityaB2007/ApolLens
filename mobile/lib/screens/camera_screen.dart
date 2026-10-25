// Gavin - Camera viewport for ApolLens repair instructions.
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/camera_frame.dart';
import '../widgets/detection_overlay.dart';
import '../services/frame_controller.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.frames, this.focusedLabel});
  final String? focusedLabel;
  final FrameController? frames;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  static int _sessions = 0;
  CameraController? _camera;
  bool _active = true;
  String? _streamError;
  final _cadence = Stopwatch()..start();
  String _status = 'Starting camera…';
  int _request = 0;
  Future<void> _closing = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
    if (_active) _openCamera();
  }

  @override
  void didUpdateWidget(CameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frames == widget.frames) return;
    scheduleMicrotask(() => oldWidget.frames?.reset());
    _closeCamera();
    if (_active) _openCamera();
  }

  Future<void> _openCamera() async {
    if (!_active || _camera != null) return;
    final request = ++_request;
    _streamError = null;
    setState(() => _status = 'Starting camera…');
    try {
      await _closing;
      if (!mounted || request != _request) return;
      final cameras = await availableCameras();
      if (!mounted || request != _request) return;
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera found.');
      }
      final camera = CameraController(
        cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
        widget.frames?.recognize == null
            ? ResolutionPreset.medium
            : ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _camera = camera;
      await camera.initialize();
      if (!mounted || request != _request) return;
      camera.addListener(() {
        if (mounted && request == _request && camera.value.hasError) {
          _closeCamera();
          setState(() => _status = 'Camera unavailable. Check camera access.');
        }
      });
      setState(() {});
      _startFrames(camera, request);
    } catch (_) {
      if (mounted && request == _request) {
        _closeCamera();
        setState(() => _status = 'Camera unavailable. Check camera access.');
      }
    }
  }

  void _startFrames(CameraController camera, int request) {
    final frames = widget.frames;
    if (frames?.recognize == null) return;
    final session =
        'camera-${++_sessions}-${DateTime.now().microsecondsSinceEpoch}';
    var sequence = 0;
    var last = -250;
    // Android and iOS adapters preserve native planes; no image upload here.
    runZonedGuarded(() async {
      if (kIsWeb ||
          !(defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS) ||
          !camera.supportsImageStreaming()) {
        throw UnsupportedError('Image streaming unavailable.');
      }
      await camera.startImageStream((image) {
        if (!mounted || request != _request || _streamError != null) return;
        if (_cadence.elapsedMilliseconds - last < 250) return;
        last = _cadence.elapsedMilliseconds;
        frames!.submit(
          CameraFrame.capture(
            image: image,
            sessionId: session,
            sequence: sequence++,
            capturedAt: DateTime.now(),
            camera: camera.description,
            orientation: camera.value.deviceOrientation,
            platform: defaultTargetPlatform,
            previewMirrored:
                camera.description.lensDirection == CameraLensDirection.front,
          ),
        );
      });
    }, (_, _) => _streamFailed(camera, request));
  }

  void _streamFailed(CameraController camera, int request) {
    if (!mounted || request != _request || _streamError != null) return;
    widget.frames?.reset();
    setState(() => _streamError = 'Live recognition unavailable.');
    if (camera.value.isStreamingImages) {
      unawaited(camera.stopImageStream().catchError((_) {}));
    }
  }

  Future<void> _release(CameraController camera) async {
    await Future<void>.value();
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } finally {
      await camera.dispose();
    }
  }

  // Ignore callbacks from a camera released while the app was hidden.
  void _closeCamera() {
    _request++;
    final camera = _camera;
    _camera = null;
    final frames = widget.frames;
    // Reset after widget updates finish, before any new camera can deliver frames.
    scheduleMicrotask(() => frames?.reset());
    _closing = (camera == null ? _closing : _release(camera)).catchError(
      (_) {},
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _openCamera();
    } else {
      _closeCamera();
    }
    setState(() => _status = 'Starting camera…');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeCamera();
    _cadence.stop();
    super.dispose();
  }

  Widget _preview(CameraController camera) {
    final frames = widget.frames;
    if (frames == null) return CameraPreview(camera);
    return ListenableBuilder(
      listenable: Listenable.merge([frames, camera]),
      builder: (context, _) {
        final frame = frames.resultFrame;
        final result = frames.result;
        final aligned = frame?.orientation == camera.value.deviceOrientation;
        return CameraPreview(
          camera,
          child: DetectionOverlay(
            const SizedBox.expand(),
            aligned ? result?.detections ?? [] : [],
            focusedLabel: widget.focusedLabel,
            frame: aligned ? frame : null,
            geometry: aligned ? result?.geometry : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return camera?.value.isInitialized == true
        ? Column(
            children: [
              Expanded(
                child: ValueListenableBuilder<CameraValue>(
                  valueListenable: camera!,
                  builder: (context, value, _) {
                    final landscape =
                        value.deviceOrientation ==
                            DeviceOrientation.landscapeLeft ||
                        value.deviceOrientation ==
                            DeviceOrientation.landscapeRight;
                    return CameraViewport(
                      aspectRatio: landscape
                          ? value.aspectRatio
                          : 1 / value.aspectRatio,
                      child: _preview(camera),
                    );
                  },
                ),
              ),
              if (_streamError != null) ...[
                Text(_streamError!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: () {
                    _closeCamera();
                    _openCamera();
                  },
                  child: const Text('Retry recognition'),
                ),
              ],
            ],
          )
        : SingleChildScrollView(
            child: Column(
              children: [
                Text(_status, textAlign: TextAlign.center),
                TextButton(
                  onPressed: _camera == null ? _openCamera : null,
                  child: const Text('Retry camera'),
                ),
              ],
            ),
          );
  }
}

// Scale the image and its overlay together, then crop them to the same viewport.
class CameraViewport extends StatelessWidget {
  const CameraViewport({
    super.key,
    required this.aspectRatio,
    required this.child,
  });
  final double aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxWidth / aspectRatio,
            child: child,
          ),
        ),
      ),
    ),
  );
}
