// Gavin - App entry point and owner of the on-device assistant services.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/recognition_state.dart';
import 'models/camera_frame.dart';
import 'services/api_service.dart';
import 'services/audio_playback.dart';
import 'services/audio_service.dart';
import 'services/frame_controller.dart';
import 'services/local_repair_assistant.dart';
import 'services/local_component_detector.dart';
import 'services/offline_speech_service.dart';
import 'services/procedure_service.dart';
import 'services/session_service.dart';
import 'services/speech_controller.dart';
import 'screens/home_screen.dart';

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
    this.localAssistant,
    this.offlineSpeech,
  }) : assert(recognition == null || recognizeFrame == null);

  final ApiService? backend;
  final AudioPlayback Function()? createPlayback;
  final ProcedureLookup? lookupProcedure;
  final SessionWriter? writeSession;
  final ValueListenable<RecognitionState>? recognition;
  final FrameRecognizer? recognizeFrame;
  final LocalRepairAssistant? localAssistant;
  final OfflineSpeechService? offlineSpeech;

  @override
  State<ApolLensApp> createState() => _ApolLensAppState();
}

class _ApolLensAppState extends State<ApolLensApp> with WidgetsBindingObserver {
  SpeechController? _speech;
  FrameController? _frames;
  LocalComponentDetector? _detector;
  late ProcedureService _procedures;
  late SessionService _sessions;
  late LocalRepairAssistant _localAssistant;
  late OfflineSpeechService _offlineSpeech;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _procedures = ProcedureService(lookup: widget.lookupProcedure);
    _sessions = SessionService(write: widget.writeSession);
    _configureLocalAssistant();
    _configureOfflineSpeech();
    _configureSpeech();
    _configureFrames();
  }

  void _configureFrames() {
    var recognize = widget.recognizeFrame;
    if (recognize == null &&
        widget.recognition == null &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      _detector = LocalComponentDetector();
      recognize = _detector!.recognize;
    }
    _frames = recognize == null ? null : FrameController(recognize: recognize);
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

  void _configureLocalAssistant() {
    _localAssistant = widget.localAssistant ?? LocalRepairAssistant();
    unawaited(_localAssistant.initialize());
  }

  void _configureOfflineSpeech() {
    _offlineSpeech = widget.offlineSpeech ?? OfflineSpeechService();
    unawaited(_offlineSpeech.initialize().catchError((Object _) {}));
  }

  @override
  void didUpdateWidget(ApolLensApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recognizeFrame != widget.recognizeFrame ||
        oldWidget.recognition != widget.recognition) {
      _frames?.dispose();
      unawaited(_detector?.dispose());
      _detector = null;
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
    if (oldWidget.localAssistant != widget.localAssistant) {
      _localAssistant.dispose();
      _configureLocalAssistant();
    }
    if (oldWidget.offlineSpeech != widget.offlineSpeech) {
      _offlineSpeech.dispose();
      _configureOfflineSpeech();
    }
    if (oldWidget.backend == widget.backend &&
        oldWidget.createPlayback == widget.createPlayback) {
      return;
    }
    _speech?.dispose();
    if (oldWidget.backend != widget.backend) {
      oldWidget.backend?.dispose();
    }
    _configureSpeech();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (!active) {
      unawaited(_localAssistant.cancel());
      unawaited(_offlineSpeech.stop());
    }
    if (_speech case final speech?) unawaited(speech.setActive(active));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech?.dispose();
    _procedures.dispose();
    _sessions.dispose();
    _frames?.dispose();
    unawaited(_detector?.dispose());
    _localAssistant.dispose();
    _offlineSpeech.dispose();
    widget.backend?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'ApolLens',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB3452E)),
      scaffoldBackgroundColor: const Color(0xFFF4F3EF),
    ),
    home: HomeScreen(
      speech: _speech,
      procedures: _procedures,
      sessions: _sessions,
      frames: _frames,
      recognition: _frames ?? widget.recognition,
      localAssistant: _localAssistant,
      offlineSpeech: _offlineSpeech,
    ),
  );
}
