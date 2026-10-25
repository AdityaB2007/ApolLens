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
import '../widgets/galaxy_background.dart';
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
    appBar: AppBar(
      title: const Text('ApolLens'),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 20),
          child: Row(
            children: [
              Icon(Icons.phonelink_lock_outlined, size: 16),
              SizedBox(width: 6),
              Text('On device', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const GalaxyBackground(),
        SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mission support',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Offline guidance · Laptop demo',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFBDC8D4),
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ColoredBox(
                          color: const Color(0xFF18211E),
                          child: CameraScreen(frames: widget.frames),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        color: const Color(0xFF18211E),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: widget.recognition == null
                            ? _status(RecognitionState.unavailable)
                            : ValueListenableBuilder<RecognitionState>(
                                valueListenable: widget.recognition!,
                                builder: (context, state, _) => _status(state),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _guidance(),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _guidance() {
    final procedures = widget.procedures;
    if (procedures == null) return _localAssistant();
    return ValueListenableBuilder<ProcedureState>(
      valueListenable: procedures,
      builder: (context, state, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.status == ProcedureStatus.ready &&
              state.itemId == widget.recognition?.value.itemId)
            SessionGuide(
              procedure: state.procedure!,
              itemId: state.itemId!,
              sessions: widget.sessions,
              speech: widget.speech,
            ),
          if (state.status == ProcedureStatus.loading)
            const Text('Finding the repair guide…'),
          if (state.status == ProcedureStatus.failed)
            TextButton(
              onPressed: () => procedures.load(state.itemId, retry: true),
              child: const Text('Retry repair guide'),
            ),
          _localAssistant(),
        ],
      ),
    );
  }

  Widget _localAssistant() {
    final assistant = widget.localAssistant;
    final speech = widget.offlineSpeech;
    if (assistant == null || speech == null) {
      return const Text('The assistant is not available on this device.');
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
    final text = result?.blocked == true
        ? 'Clear the camera’s view'
        : switch (state.status) {
            RecognitionStatus.unavailable =>
              'Camera view · Detection unavailable',
            RecognitionStatus.identifying => 'Looking for components…',
            RecognitionStatus.unknown =>
              result?.detections.isNotEmpty == true
                  ? 'Components in view · Review below'
                  : 'Point at the equipment',
            RecognitionStatus.identified => state.label ?? 'Device in view',
          };
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
    );
  }
}
