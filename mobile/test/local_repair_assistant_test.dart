import 'dart:async';
import 'dart:convert';

import 'package:apollens/models/inspection_step.dart';
import 'package:apollens/models/repair_procedure.dart';
import 'package:apollens/services/local_repair_assistant.dart';
import 'package:apollens/services/offline_speech_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeLocalModelRuntime runtime;
  late LocalRepairAssistant assistant;

  setUp(() async {
    runtime = FakeLocalModelRuntime();
    assistant = LocalRepairAssistant(runtime: runtime);
    await assistant.initialize();
  });

  tearDown(() => assistant.dispose());

  test('asks about confirmed parts before proposing repair steps', () async {
    runtime.response = '{"question":"Which part is affected?","step_ids":[]}';
    final reply = await assistant.askAbout(['RAM'], _manual(), 'laptop-x');

    expect(reply.question, 'Which part is affected?');
    expect(reply.stepIds, isEmpty);
    expect(assistant.state.status, LocalAssistantStatus.ready);
    final prompt = jsonDecode(runtime.lastPrompt!) as Map<String, dynamic>;
    expect(prompt['confirmed_components'], ['RAM']);
    expect(prompt['manual_steps'], isNotEmpty);
    expect(prompt['reported_problem'], isNull);
    expect(prompt['task'], contains('Ask one short question'));
  });

  test('returns permitted manual IDs in supplied manual order', () async {
    runtime.response = '{"question":"","step_ids":["remove-ssd","power-off"]}';
    final reply = await assistant.describeProblem(
      ['SSD'],
      _manual(),
      'laptop-x',
      'The drive is not detected.',
    );

    expect(reply.stepIds, ['power-off', 'remove-ssd']);
    expect(reply.question, isNull);
    expect(assistant.state.status, LocalAssistantStatus.ready);
  });

  test('does not invent steps without a matching manual', () async {
    final reply = await assistant.describeProblem(
      ['SSD'],
      _manual(),
      'different-item',
      'The drive is not detected.',
    );

    expect(reply.stepIds, isEmpty);
    expect(reply.question, contains('no matching repair manual'));
    expect(runtime.generateCalls, 0);
  });

  test(
    'rejects IDs absent from the supplied manual and stays retryable',
    () async {
      runtime.response = '{"question":"","step_ids":["made-up-step"]}';
      await expectLater(
        assistant.describeProblem(
          ['SSD'],
          _manual(),
          'laptop-x',
          'The drive is not detected.',
        ),
        throwsA(isA<FormatException>()),
      );

      expect(assistant.state.status, LocalAssistantStatus.ready);
      expect(assistant.state.message, contains('retry'));
    },
  );

  test(
    'stops model work and ignores replies arriving after cancellation',
    () async {
      final pending = Completer<String>();
      runtime.pending = pending;
      final request = assistant.askAbout(['RAM'], _manual(), 'laptop-x');
      final rejected = expectLater(request, throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);
      expect(runtime.generateCalls, 1);

      await assistant.cancel();
      expect(runtime.cancelCalls, 1);
      pending.complete('{"question":"Late reply","step_ids":[]}');

      await rejected;
      expect(assistant.state.status, LocalAssistantStatus.ready);
    },
  );

  test('limits symptom text before invoking the model', () {
    expect(
      () =>
          assistant.describeProblem(['RAM'], _manual(), 'laptop-x', 'x' * 501),
      throwsArgumentError,
    );
    expect(runtime.generateCalls, 0);
  });

  group('OfflineSpeechService', () {
    const channel = MethodChannel('flutter_tts');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'getVoices' => [
                {
                  'name': 'Online English',
                  'locale': 'en-US',
                  'network_required': '1',
                },
                {
                  'name': 'Offline English',
                  'locale': 'en-US',
                  'network_required': '0',
                },
              ],
              _ => 1,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test(
      'selects an installed offline Android voice and speaks locally',
      () async {
        final speech = OfflineSpeechService();
        await speech.speak('Disconnect power first.');

        final voiceCall = calls.singleWhere(
          (call) => call.method == 'setVoice',
        );
        expect(voiceCall.arguments, {
          'name': 'Offline English',
          'locale': 'en-US',
        });
        final speakCall = calls.singleWhere((call) => call.method == 'speak');
        expect(speakCall.arguments, 'Disconnect power first.');
        expect(speech.status, OfflineSpeechStatus.idle);
        await speech.stop();
      },
    );
  });
}

RepairProcedure _manual() => RepairProcedure(
  id: 'laptop-service-manual',
  revision: '1',
  title: 'Laptop service manual',
  source: Uri.parse('https://example.org/manual'),
  supportedItemIds: const ['laptop-x'],
  steps: const {
    'power-off': InspectionStep('Power off', 'Disconnect power first.'),
    'remove-ssd': InspectionStep(
      'Remove drive',
      'Release the SSD retaining screw.',
    ),
  },
);

final class FakeLocalModelRuntime implements LocalModelRuntime {
  String response = '{"question":"","step_ids":[]}';
  String? lastPrompt;
  Completer<String>? pending;
  int generateCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> install(void Function(int progress) onProgress) async {
    onProgress(100);
  }

  @override
  Future<bool> loadActiveModel() async => true;

  @override
  Future<String> generate(String systemInstruction, String prompt) {
    generateCalls++;
    lastPrompt = prompt;
    return pending?.future ?? Future.value(response);
  }

  @override
  Future<void> cancelGeneration() async {
    cancelCalls++;
  }

  @override
  Future<void> dispose() async {}
}
