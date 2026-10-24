// Gavin - App entry point and theme.
// Starts the Flutter interface for ApolLens.
import 'dart:async';

import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/audio_playback.dart';
import 'services/audio_service.dart';
import 'services/speech_controller.dart';
import 'package:apollens/screens/home_screen.dart';

void main() => runApp(const ApolLensApp());

class ApolLensApp extends StatefulWidget {
  const ApolLensApp({super.key, this.backend, this.createPlayback});

  // The app owns this configured client. No client means text-only guidance.
  final ApiService? backend;
  final AudioPlayback Function()? createPlayback;

  @override
  State<ApolLensApp> createState() => _ApolLensAppState();
}

class _ApolLensAppState extends State<ApolLensApp> with WidgetsBindingObserver {
  SpeechController? _speech;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureSpeech();
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
      home: HomeScreen(speech: _speech),
    );
  }
}
