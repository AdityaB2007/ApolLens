// Gavin - Opens ApolLens on the camera without selecting an item first.
import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/session_guide.dart';
import 'package:flutter/foundation.dart';
import 'package:apollens/models/recognition_state.dart';
import 'package:apollens/screens/camera_screen.dart';
import 'package:apollens/services/speech_controller.dart';
import 'package:apollens/services/procedure_service.dart';
import 'package:apollens/services/session_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.recognition,
    this.speech,
    this.procedures,
    this.sessions,
  });

  // The session owner supplies and disposes the recognition service.
  final ValueListenable<RecognitionState>? recognition;
  final SpeechController? speech;
  final ProcedureService? procedures;
  final SessionService? sessions;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _itemId;

  @override
  void initState() {
    super.initState();
    widget.recognition?.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.recognition?.removeListener(_sync);
    widget.recognition?.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!mounted) return;
    final itemId = widget.recognition?.value.itemId;
    if (_itemId != itemId) {
      unawaited(widget.speech?.stop(clear: true));
      widget.sessions?.reset();
    }
    _itemId = itemId;
    unawaited(widget.procedures?.load(itemId));
  }

  @override
  void dispose() {
    widget.recognition?.removeListener(_sync);
    unawaited(widget.speech?.stop(clear: true));
    widget.procedures?.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ApolLens')),
      // Keep the camera and status readable on smaller screens.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Point your camera at the item',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Card(
              child:
                  SizedBox(height: 320, child: Center(child: CameraScreen())),
            ),
            const SizedBox(height: 24),
            if (widget.recognition == null)
              _status(RecognitionState.unavailable)
            else
              ValueListenableBuilder<RecognitionState>(
                valueListenable: widget.recognition!,
                builder: (context, state, child) => _status(state),
              ),
            const SizedBox(height: 8),
            _guidance(),
          ],
        ),
      ),
    );
  }

  Widget _guidance() {
    final procedures = widget.procedures;
    if (procedures == null)
      return const Text('Repair guidance is unavailable.');
    return ValueListenableBuilder<ProcedureState>(
      valueListenable: procedures,
      builder: (context, state, _) {
        if (state.itemId != widget.recognition?.value.itemId) {
          return const Text('Waiting for a matching repair guide.');
        }
        if (state.status == ProcedureStatus.ready) {
          return SessionGuide(
              procedure: state.procedure!,
              itemId: state.itemId!,
              sessions: widget.sessions,
              speech: widget.speech);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(switch (state.status) {
            ProcedureStatus.loading => 'Loading repair guide…',
            ProcedureStatus.unsupported =>
              'No matching repair guide is available.',
            ProcedureStatus.failed => 'Repair guide could not be loaded.',
            _ => 'Repair guidance is unavailable.',
          }),
          if (state.status == ProcedureStatus.failed)
            TextButton(
                onPressed: () => procedures.load(state.itemId, retry: true),
                child: const Text('Retry guide')),
        ]);
      },
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
