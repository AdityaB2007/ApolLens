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
  String? _itemId, _focusedPart;

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
      setState(() {
        _itemId = itemId;
        _focusedPart = null;
      });
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
      title: Text('ApolLens', style: Theme.of(context).textTheme.titleLarge),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final camera = ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CameraScreen(
                  frames: widget.frames,
                  focusedLabel: _focusedPart,
                ),
              );
              final guidance = SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: _guidance(),
              );
              if (constraints.maxWidth > constraints.maxHeight) {
                return Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 0, 20),
                        child: camera,
                      ),
                    ),
                    Expanded(child: guidance),
                  ],
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: SizedBox(
                      height: (constraints.maxHeight * .42).clamp(
                        0,
                        constraints.maxWidth,
                      ),
                      child: camera,
                    ),
                  ),
                  Expanded(child: guidance),
                ],
              );
            },
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
      onTargetChanged: (label) {
        if (mounted && _focusedPart != label) {
          setState(() => _focusedPart = label);
        }
      },
    );
  }
}
