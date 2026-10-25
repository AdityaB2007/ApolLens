import 'package:apollens/main.dart';
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

  testWidgets('wires the local assistant into the camera-first app', (
    tester,
  ) async {
    final assistant = LocalRepairAssistant(runtime: _TestModelRuntime());
    final speech = OfflineSpeechService();
    await tester.pumpWidget(
      ApolLensApp(localAssistant: assistant, offlineSpeech: speech),
    );
    await tester.pumpAndSettle();

    expect(find.text('Point your camera at the item'), findsOneWidget);
    expect(find.text('Local repair assistant'), findsOneWidget);
    expect(find.text('Install local model'), findsOneWidget);
    expect(
      find.text(
        'One-time online install: about 329 MB. Inference is on-device afterward.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

final class _TestModelRuntime implements LocalModelRuntime {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> install(void Function(int progress) onProgress) async {
    onProgress(100);
  }

  @override
  Future<bool> loadActiveModel() async => false;

  @override
  Future<String> generate(String systemInstruction, String prompt) async =>
      '{"question":"","step_ids":[]}';

  @override
  Future<void> cancelGeneration() async {}

  @override
  Future<void> dispose() async {}
}
