// Gavin - App entry point and theme.
// Starts the Flutter interface for ApolLens.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/recognition_state.dart';
import 'models/camera_frame.dart';
import 'services/frame_controller.dart';

import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/audio_playback.dart';
import 'services/audio_service.dart';
import 'services/speech_controller.dart';
import 'services/procedure_service.dart';
import 'services/session_service.dart';
import 'package:apollens/screens/home_screen.dart';

void main() => runApp(const ApolLensApp());

class ApolLensApp extends StatefulWidget {
  const ApolLensApp({
    super.key,
    this.backend,
    this.createPlayback,
    this.lookupProcedure,
    this.writeSession,
    this.recognition,
    this.recognizeFrame,
  }) : assert(recognition == null || recognizeFrame == null);

  // The app owns this configured client. No client means text-only guidance.
  final ApiService? backend;
  final AudioPlayback Function()? createPlayback;
  final ProcedureLookup? lookupProcedure;
  final SessionWriter? writeSession;
  final ValueListenable<RecognitionState>? recognition;
  final FrameRecognizer? recognizeFrame;

  @override
  State<ApolLensApp> createState() => _ApolLensAppState();
}

class _ApolLensAppState extends State<ApolLensApp> with WidgetsBindingObserver {
  SpeechController? _speech;
  FrameController? _frames;
  late ProcedureService _procedures;
  late SessionService _sessions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _procedures = ProcedureService(lookup: widget.lookupProcedure);
    _sessions = SessionService(write: widget.writeSession);
    _configureSpeech();
    _configureFrames();
  }

  void _configureFrames() {
    _frames = widget.recognizeFrame == null
        ? null
        : FrameController(recognize: widget.recognizeFrame);
  }

  void _configureSpeech() {
    final backend = widget.backend;
    _speech = backend == null
        ? null
        : SpeechController(
            AudioService(backend),
            widget.createPlayback?.call() ?? AudioPlayback(),
          );
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null) didChangeAppLifecycleState(state);
  }

  @override
  void didUpdateWidget(ApolLensApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recognizeFrame != widget.recognizeFrame) {
      _frames?.dispose();
      _configureFrames();
    }
    if (oldWidget.writeSession != widget.writeSession) {
      _sessions.dispose();
      _sessions = SessionService(write: widget.writeSession);
    }
    if (oldWidget.lookupProcedure != widget.lookupProcedure) {
      _procedures.dispose();
      _procedures = ProcedureService(lookup: widget.lookupProcedure);
    }
    if (oldWidget.backend == widget.backend &&
        oldWidget.createPlayback == widget.createPlayback) return;
    _speech?.dispose();
    if (oldWidget.backend != widget.backend) oldWidget.backend?.dispose();
    _configureSpeech();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final speech = _speech;
    if (speech != null) {
      unawaited(speech.setActive(state == AppLifecycleState.resumed));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech?.dispose();
    _procedures.dispose();
    _sessions.dispose();
    _frames?.dispose();
    widget.backend?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ApolLens',
      // Keep the shared colors here as more screens are added.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB3452E)),
        scaffoldBackgroundColor: const Color(0xFFF4F3EF),
      ),
      home: HomeScreen(
          speech: _speech,
          procedures: _procedures,
          sessions: _sessions,
          frames: _frames,
          recognition: _frames ?? widget.recognition),
    );
  }
}
