// Gavin - Camera viewport for ApolLens repair instructions.
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String _status = 'Starting camera…';
  int _request = 0;
  Future<void> _closing = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
  }

  Future<void> _openCamera() async {
    final request = ++_request;
    try {
      await _closing;
      final cameras = await availableCameras();
      if (!mounted || request != _request) return;
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera found.');
      }
      final camera = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _camera = camera;
      await camera.initialize();
      if (mounted && request == _request) setState(() {});
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _status = 'Camera unavailable. Check camera access.');
      }
    }
  }

  // Ignore callbacks from a camera released while the app was hidden.
  void _closeCamera() {
    _request++;
    final camera = _camera;
    _camera = null;
    _closing = (camera?.dispose() ?? _closing).catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return camera?.value.isInitialized == true
        ? CameraPreview(camera!)
        : Center(child: Text(_status));
  }
}
