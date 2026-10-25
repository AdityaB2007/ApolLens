import 'dart:async';

import 'package:apollens/services/offline_speech_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:apollens/services/local_repair_assistant.dart';
import 'package:apollens/widgets/local_assistant_panel.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settleCalls() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class NativeSpeechFixture extends FlutterTts {
  final requests = <String>[];
  final commands = <String>[];
  Completer<int>? pauseReply;
  bool? awaitCompletion;
  int speakResult = 1;
  @override
  Future<dynamic> awaitSpeakCompletion(bool value) async {
    awaitCompletion = value;
    return 1;
  }

  @override
  Future<dynamic> setLanguage(String value) async => 1;
  @override
  Future<dynamic> get getVoices async => [
    {
      'name': 'Installed English',
      'locale': 'en-US',
      'network_required': false,
      'identifier': 'installed.english',
    },
  ];
  @override
  Future<dynamic> setVoice(Map<String, String> value) async => 1;
  @override
  Future<dynamic> stop() async {
    commands.add('stop');
    return 1;
  }

  @override
  Future<dynamic> pause() async {
    commands.add('pause');
    return pauseReply == null ? 1 : await pauseReply!.future;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    commands.add('speak');
    requests.add(text);
    return speakResult;
  }

  void finish() => completionHandler?.call();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$platform pause/resume preserves one completion future', () async {
      debugDefaultTargetPlatformOverride = platform;
      final engine = NativeSpeechFixture();
      final speech = OfflineSpeechService(tts: engine);
      addTearDown(speech.dispose);
      var finished = false;
      final request = speech
          .speak('Remove screw one.')
          .then((_) => finished = true);
      await settleCalls();
      expect(engine.awaitCompletion, isFalse);
      expect(finished, isFalse);
      await speech.pause();
      expect(speech.status, OfflineSpeechStatus.paused);
      expect(finished, isFalse);
      final resumed = speech.resume();
      await settleCalls();
      expect(speech.status, OfflineSpeechStatus.speaking);
      expect(engine.commands, ['stop', 'speak', 'pause', 'speak']);
      engine.finish();
      await Future.wait([request, resumed]);
      expect(finished, isTrue);
      expect(speech.status, OfflineSpeechStatus.idle);
    });
  }

  test('late pause cannot restore paused state after stop', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final engine = NativeSpeechFixture()..pauseReply = Completer<int>();
    final speech = OfflineSpeechService(tts: engine);
    addTearDown(speech.dispose);
    final speaking = speech.speak('Old instruction.');
    await settleCalls();
    final pause = speech.pause();
    await settleCalls();
    final stopped = speech.stop();
    expect(speech.status, OfflineSpeechStatus.idle);
    await speaking;
    engine.pauseReply!.complete(1);
    await Future.wait([pause, stopped]);
    expect(speech.status, OfflineSpeechStatus.idle);
  });

  test(
    'new instruction replaces a pending pause without racing native calls',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final engine = NativeSpeechFixture()..pauseReply = Completer<int>();
      final speech = OfflineSpeechService(tts: engine);
      addTearDown(speech.dispose);
      final first = speech.speak('First.');
      await settleCalls();
      final pause = speech.pause();
      await settleCalls();
      final second = speech.speak('Second.');
      await first;
      expect(engine.requests, ['First.']);
      engine.pauseReply!.complete(1);
      await pause;
      await settleCalls();
      expect(engine.requests, ['First.', 'Second.']);
      expect(speech.status, OfflineSpeechStatus.speaking);
      engine.finish();
      await second;
    },
  );

  test(
    'mute cancels pending speech and retains the next displayed instruction',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final engine = NativeSpeechFixture();
      final speech = OfflineSpeechService(tts: engine);
      addTearDown(speech.dispose);
      final first = speech.speak('Old.');
      await settleCalls();
      await speech.setMuted(true);
      await first;
      engine.startHandler?.call();
      engine.finish();
      engine.errorHandler?.call('old error');
      await speech.speak('Current.');
      expect(speech.status, OfflineSpeechStatus.muted);
      expect(engine.requests, ['Old.']);
      await speech.setMuted(false);
      final replay = speech.replay();
      await settleCalls();
      expect(engine.requests.last, 'Current.');
      engine.finish();
      await replay;
    },
  );

  test('native error settles speech and replay retries', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final engine = NativeSpeechFixture();
    final speech = OfflineSpeechService(tts: engine);
    addTearDown(speech.dispose);
    final failed = speech.speak('Instruction.');
    await settleCalls();
    engine.errorHandler?.call('voice unavailable');
    await failed;
    expect(speech.status, OfflineSpeechStatus.failed);
    expect(speech.errorMessage, contains('voice unavailable'));
    final retry = speech.replay();
    await settleCalls();
    expect(speech.errorMessage, isNull);
    engine.finish();
    await retry;
  });

  test(
    'native cancellation settles speech without reporting a voice error',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final engine = NativeSpeechFixture();
      final speech = OfflineSpeechService(tts: engine);
      addTearDown(speech.dispose);
      final request = speech.speak('Instruction.');
      await settleCalls();
      engine.cancelHandler?.call();
      await request;
      expect(speech.status, OfflineSpeechStatus.idle);
      expect(speech.errorMessage, isNull);
    },
  );

  testWidgets('pause and resume controls stay usable with large text', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final engine = NativeSpeechFixture();
    final speech = OfflineSpeechService(tts: engine);
    final assistant = LocalRepairAssistant(runtime: _LocalRuntime());
    await assistant.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LocalAssistantPanel(
              assistant: assistant,
              speech: speech,
              itemId: null,
            ),
          ),
        ),
      ),
    );
    final spoken = speech.speak('Read the component label.');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pause voice'));
    await tester.tap(find.text('Pause voice'));
    await tester.pumpAndSettle();
    expect(speech.status, OfflineSpeechStatus.paused);
    await tester.ensureVisible(find.text('Resume voice'));
    await tester.tap(find.text('Resume voice'));
    await tester.pumpAndSettle();
    expect(speech.status, OfflineSpeechStatus.speaking);
    engine.finish();
    await spoken;
    await tester.pumpAndSettle();
    expect(find.text('Replay voice'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    speech.dispose();
    assistant.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test('background and disposal settle pending requests', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final engine = NativeSpeechFixture();
    final speech = OfflineSpeechService(tts: engine);
    final first = speech.speak('First.');
    await settleCalls();
    speech.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await first;
    expect(speech.status, OfflineSpeechStatus.idle);
    final second = speech.speak('Second.');
    await settleCalls();
    speech.dispose();
    await second;
    engine.finish();
    engine.startHandler?.call();
  });
}

final class _LocalRuntime implements LocalModelRuntime {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> loadActiveModel() async => true;
  @override
  Future<void> install(void Function(int) onProgress) async {}
  @override
  Future<String> generate(String systemInstruction, String prompt) async =>
      '{}';
  @override
  Future<void> cancelGeneration() async {}
  @override
  Future<void> dispose() async {}
}
