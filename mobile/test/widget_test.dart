import 'dart:async';

import 'package:apollens/main.dart';
import 'package:apollens/widgets/galaxy_background.dart';
import 'package:apollens/services/local_repair_assistant.dart';
import 'package:apollens/services/offline_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const speechChannel = MethodChannel('flutter_tts');
  const cameraChannel = MethodChannel('plugins.flutter.io/camera');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (_) async => <Object?>[]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speechChannel, (call) async {
          if (call.method == 'getVoices') {
            return [
              {
                'name': 'Offline English',
                'locale': 'en-US',
                'network_required': '0',
              },
            ];
          }
          return 1;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speechChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, null);
  });

  testWidgets('galaxy pauses with lifecycle and reduced motion', (
    tester,
  ) async {
    Widget scene(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const GalaxyBackground(),
      ),
    );
    await tester.pumpWidget(scene(false));
    await tester.pump(const Duration(seconds: 1));
    final dynamic painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(GalaxyBackground),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter;
    expect(painter.motion.value, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = painter.motion.value;
    await tester.pump(const Duration(seconds: 2));
    expect(painter.motion.value, paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(painter.motion.value, greaterThan(paused));
    await tester.pumpWidget(scene(true));
    final reduced = painter.motion.value;
    await tester.pump(const Duration(seconds: 3));
    expect(painter.motion.value, reduced);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wires the local assistant into the camera-first app', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final assistant = LocalRepairAssistant(runtime: _TestModelRuntime());
    final speech = OfflineSpeechService();
    await tester.pumpWidget(
      ApolLensApp(localAssistant: assistant, offlineSpeech: speech),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mission support'), findsNothing);
    expect(find.text('ApolLens'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('ApolLens'))).brightness,
      Brightness.dark,
    );
    expect(find.text('Detected parts'), findsOneWidget);
    expect(find.text('Download assistant'), findsOneWidget);
    expect(find.text('About 1 GB. Works offline after setup.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('shows thinking and cancels a late native response', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final semantics = tester.ensureSemantics();
    try {
      final pending = Completer<String>();
      final assistant = LocalRepairAssistant(
        runtime: _TestModelRuntime(ready: true, pending: pending),
      );
      addTearDown(() async {
        await assistant.cancel();
        if (!pending.isCompleted) pending.complete('{"checks":[]}');
      });
      final speech = OfflineSpeechService();
      await tester.pumpWidget(
        ApolLensApp(localAssistant: assistant, offlineSpeech: speech),
      );
      await tester.pumpAndSettle();
      final request = assistant.describeProblem(['RAM'], null, '', 'No boot.');
      final canceled = expectLater(request, throwsStateError);
      await tester.pump();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Generating a response')),
        findsOneWidget,
      );
      expect(find.text('Thinking on this device…'), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('Thinking on this device…'), findsNothing);
      pending.complete('{"checks":["startup"]}');
      await canceled;
      await tester.pump();
      expect(find.text('Watch startup'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    } finally {
      semantics.dispose();
    }
  });
}

final class _TestModelRuntime implements LocalModelRuntime {
  _TestModelRuntime({this.ready = false, this.pending});
  final bool ready;
  final Completer<String>? pending;
  @override
  Future<void> initialize() async {}

  @override
  Future<void> install(void Function(int progress) onProgress) async {
    onProgress(100);
  }

  @override
  Future<bool> loadActiveModel() async => ready;

  @override
  Future<String> generate(String systemInstruction, String prompt) async =>
      pending == null ? '{"question":"","checks":[]}' : await pending!.future;

  @override
  Future<void> cancelGeneration() async {}

  @override
  Future<void> dispose() async {}
}
