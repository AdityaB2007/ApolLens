// Gavin - Keep the camera first and route confirmed detections to local guidance.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/recognition_state.dart';
import '../services/frame_controller.dart';
import '../services/local_repair_assistant.dart';
import '../services/offline_speech_service.dart';
import '../services/procedure_service.dart';
import '../services/session_service.dart';
import '../services/speech_controller.dart';
import '../widgets/local_assistant_panel.dart';
import '../widgets/session_guide.dart';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.recognition,
    this.frames,
    this.speech,
    this.procedures,
    this.sessions,
    this.localAssistant,
    this.offlineSpeech,
  });

  final ValueListenable<RecognitionState>? recognition;
  final FrameController? frames;
  final SpeechController? speech;
  final ProcedureService? procedures;
  final SessionService? sessions;
  final LocalRepairAssistant? localAssistant;
  final OfflineSpeechService? offlineSpeech;

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
      setState(() => _itemId = itemId);
    }
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ApolLens')),
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
          Card(
            child: SizedBox(
              height: 320,
              child: Center(child: CameraScreen(frames: widget.frames)),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.recognition == null)
            _status(RecognitionState.unavailable)
          else
            ValueListenableBuilder<RecognitionState>(
              valueListenable: widget.recognition!,
              builder: (context, state, _) => _status(state),
            ),
          const SizedBox(height: 8),
          _guidance(),
        ],
      ),
    ),
  );

  Widget _guidance() {
    final procedures = widget.procedures;
    if (procedures == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Repair guide lookup is unavailable.'),
          _localAssistant(),
        ],
      );
    }
    return ValueListenableBuilder<ProcedureState>(
      valueListenable: procedures,
      builder: (context, state, _) {
        final currentItem = widget.recognition?.value.itemId;
        final guide = state.itemId != currentItem
            ? const Text('Waiting for a matching repair guide.')
            : switch (state.status) {
                ProcedureStatus.ready => SessionGuide(
                  procedure: state.procedure!,
                  itemId: state.itemId!,
                  sessions: widget.sessions,
                  speech: widget.speech,
                ),
                ProcedureStatus.loading => const Text('Loading repair guide…'),
                ProcedureStatus.unsupported => const Text(
                  'No matching repair guide is available.',
                ),
                ProcedureStatus.failed => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Repair guide could not be loaded.'),
                    TextButton(
                      onPressed: () =>
                          procedures.load(state.itemId, retry: true),
                      child: const Text('Retry guide'),
                    ),
                  ],
                ),
                ProcedureStatus.unavailable => const Text(
                  'Repair guidance is unavailable.',
                ),
              };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [guide, _localAssistant()],
        );
      },
    );
  }

  Widget _localAssistant() {
    final assistant = widget.localAssistant;
    final speech = widget.offlineSpeech;
    if (assistant == null || speech == null) {
      return const Text('On-device assistant is unavailable.');
    }
    return LocalAssistantPanel(
      key: ValueKey(_itemId),
      assistant: assistant,
      speech: speech,
      itemId: _itemId,
      frames: widget.frames,
      procedures: widget.procedures,
    );
  }

  Widget _status(RecognitionState state) {
    final result = widget.frames?.result;
    final notice = result?.blocked == true
        ? 'View is blocked. Clear the camera and try another angle.'
        : (widget.frames != null &&
                  result == null &&
                  state.status == RecognitionStatus.identified
              ? 'Last recognized: ${state.label}'
              : null);
    final placementMissing =
        result != null &&
        result.detections.isNotEmpty &&
        result.geometry == null;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notice ??
                switch (state.status) {
                  RecognitionStatus.unavailable =>
                    'Item recognition unavailable',
                  RecognitionStatus.identifying => 'Identifying item…',
                  RecognitionStatus.unknown =>
                    result?.detections.isNotEmpty == true
                        ? 'Components detected. Confirm them below.'
                        : 'No components detected. Try another angle.',
                  RecognitionStatus.identified => 'Detected: ${state.label}',
                },
          ),
          if (placementMissing) const Text('Component positions unavailable.'),
        ],
      ),
    );
  }
}
