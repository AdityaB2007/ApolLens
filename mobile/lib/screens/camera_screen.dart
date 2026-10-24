// Gavin - Camera viewport for ApolLens repair instructions.
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _camera;
  String _status = 'Starting camera…';

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
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
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Camera unavailable. Check camera access.');
      }
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
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
