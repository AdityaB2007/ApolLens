// Gavin - Opens ApolLens on the camera without selecting an item first.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:apollens/models/recognition_state.dart';
import 'package:apollens/screens/camera_screen.dart';
import 'package:apollens/services/speech_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.recognition, this.speech});

  // The session owner supplies and disposes the recognition service.
  final ValueListenable<RecognitionState>? recognition;
  final SpeechController? speech;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ApolLens')),
      // Keep the camera and status readable on smaller screens.
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Point your camera at the item',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const Card(
            child: SizedBox(height: 320, child: Center(child: CameraScreen())),
          ),
          const SizedBox(height: 24),
          if (recognition == null)
            _status(RecognitionState.unavailable)
          else
            ValueListenableBuilder<RecognitionState>(
              valueListenable: recognition!,
              builder: (context, state, child) => _status(state),
            ),
          const SizedBox(height: 8),
          Text(speech == null
              ? 'Repair and audio guidance are not connected yet.'
              : 'Repair instructions are not connected yet.'),
        ],
      ),
    );
  }

  Widget _status(RecognitionState state) => Semantics(
        liveRegion: true,
        child: Text(switch (state.status) {
          RecognitionStatus.unavailable => 'Item recognition unavailable',
          RecognitionStatus.identifying => 'Identifying item…',
          RecognitionStatus.unknown =>
            'Item not recognized. Try another angle.',
          RecognitionStatus.identified => 'Detected: ${state.label}',
        }),
      );
}
