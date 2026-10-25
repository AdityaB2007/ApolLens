import 'dart:async';

import 'package:apollens/main.dart';
import 'package:apollens/screens/camera_screen.dart';
import 'package:apollens/models/repair_decision.dart';
import 'package:apollens/models/repair_progress.dart';
import 'package:apollens/widgets/repair_plan_panel.dart';
import 'package:apollens/widgets/galaxy_background.dart';
import 'package:apollens/widgets/galaxy_credit.dart';
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

  testWidgets('galaxy image credit is readable and available offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GalaxyCredit())),
    );
    await tester.tap(find.text('Galaxy image credit'));
    await tester.pumpAndSettle();
    expect(find.text('Whirlpool Galaxy · M51'), findsOneWidget);
    expect(find.textContaining('The Hubble Heritage Team'), findsOneWidget);
    expect(
      find.text('https://esahubble.org/images/heic0506a/'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('galaxy pauses with lifecycle and reduced motion', (
    tester,
  ) async {
    Widget scene(bool reduced, {bool ticking = true}) => MaterialApp(
      home: TickerMode(
        enabled: ticking,
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const GalaxyBackground(),
        ),
      ),
    );
    List<double> position() => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(GalaxyBackground),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage
        .toList();
    await tester.pumpWidget(scene(true));
    await tester.runAsync(
      () => precacheImage(
        const ResizeImage(AssetImage(galaxyImageAsset), width: 1280),
        tester.element(find.byType(GalaxyBackground)),
      ),
    );
    await tester.pumpWidget(scene(false));
    final initial = position();
    await tester.pump(const Duration(milliseconds: 49));
    expect(position(), initial);
    await tester.pump(const Duration(milliseconds: 1));
    expect(position(), isNot(initial));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final paused = position();
    await tester.pump(const Duration(seconds: 2));
    expect(position(), paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(position(), isNot(paused));
    await tester.pumpWidget(scene(true));
    final reduced = position();
    await tester.pump(const Duration(seconds: 3));
    expect(position(), reduced);
    await tester.pumpWidget(scene(false, ticking: false));
    final hidden = position();
    await tester.pump(const Duration(seconds: 1));
    expect(position(), hidden);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('replacement controls keep text and recheck interrupted work', (
    tester,
  ) async {
    final progress = RepairProgress(
      const RepairDecision(
        intent: RepairIntent.diagnose,
        target: RepairTarget.storage,
        issue: RepairIssue.bootMissing,
        evidence: 'no boot device',
      ),
    );
    final speech = OfflineSpeechService();
    await speech.setMuted(true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepairPlanPanel(
              progress: progress,
              speech: speech,
              onTellMore: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Help me replace the drive'));
    await tester.tap(find.text('Help me replace the drive'));
    await tester.pump();
    expect(find.text('Protect your work'), findsOneWidget);
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(find.text('Isolate power'), findsOneWidget);
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(progress.has(RepairFact.powerIsolated), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Isolate power'), findsOneWidget);
    expect(progress.has(RepairFact.powerIsolated), isFalse);
    expect(progress.did('prepare_data'), isTrue);
    expect(speech.status, OfflineSpeechStatus.muted);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    speech.dispose();
  });

  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets(
      'camera stays visible while guidance scrolls at ${size.width}',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ApolLensApp(
            localAssistant: LocalRepairAssistant(runtime: _TestModelRuntime()),
            offlineSpeech: OfflineSpeechService(),
          ),
        );
        await tester.pumpAndSettle();
        final before = tester.getRect(find.byType(CameraScreen));
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -250),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(CameraScreen)), before);
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).last)
              .position
              .pixels,
          greaterThan(0),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

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
