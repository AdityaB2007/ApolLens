import 'dart:async';
import 'package:apollens/services/apple_local_model_runtime.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'local_repair_assistant_test.dart' show FakeLocalModelRuntime;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const method = MethodChannel('dev.shakib/apple_foundation_models');
  const events = MethodChannel('dev.shakib/apple_foundation_models/events');
  late AppleLocalModelRuntime runtime;
  late FakeLocalModelRuntime fallback;
  late Completer<void> entered;
  final calls = <String>[];
  var available = true, hold = false, request = 0, session = 0;

  void emit(int id, String type, [String? text]) {
    binding.channelBuffers.push(
      events.name,
      const StandardMethodCodec().encodeSuccessEnvelope({
        'type': type,
        'requestId': id,
        'text': text,
      }),
      (_) {},
    );
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    fallback = FakeLocalModelRuntime();
    runtime = AppleLocalModelRuntime(fallback: fallback);
    entered = Completer<void>();
    available = true;
    hold = false;
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      events,
      (_) async => null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(method, (
      call,
    ) async {
      calls.add(call.method);
      switch (call.method) {
        case 'availability':
          return {'available': available};
        case 'session.create':
          return ++session;
        case 'session.stream':
        case 'session.streamAs':
          request = call.arguments['requestId'] as int;
          if (!entered.isCompleted) entered.complete();
          if (!hold) {
            final id = request;
            unawaited(
              Future<void>(() {
                final structured = call.method == 'session.streamAs';
                emit(
                  id,
                  'delta',
                  structured ? '{"intent":"replace"}' : 'Hello',
                );
                emit(
                  id,
                  'delta',
                  structured
                      ? '{"intent":"replace","component":"storage"}'
                      : 'Hello world',
                );
                emit(id, 'done');
              }),
            );
          }
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    await runtime.dispose();
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(method, null);
  });

  test(
    'unavailable native model preserves downloaded offline fallback',
    () async {
      available = false;
      await runtime.initialize();
      expect(await runtime.loadActiveModel(), isTrue);
      var progress = 0;
      await runtime.install((value) => progress = value);
      expect(progress, 100);
      expect(await runtime.generate('system', 'prompt'), fallback.response);
      expect(fallback.generateCalls, 1);
      expect(calls, ['availability']);
    },
  );

  test('setup can retry a transient fallback initialization failure', () async {
    available = false;
    fallback.initializationFailures = 1;
    await expectLater(runtime.initialize(), throwsStateError);
    await Future.wait([runtime.initialize(), runtime.initialize()]);
    expect(fallback.initializeCalls, 2);
    expect(await runtime.loadActiveModel(), isTrue);
    await runtime.dispose();
    await expectLater(runtime.initialize(), throwsStateError);
  });

  test(
    'native snapshots replace prior text and release their session',
    () async {
      await runtime.initialize();
      expect(await runtime.loadActiveModel(), isTrue);
      expect(await runtime.generate('system', 'prompt'), 'Hello world');
      expect(calls, contains('session.dispose'));
      expect(fallback.generateCalls, 0);
    },
  );

  test('native routing is constrained by named enum fields', () async {
    await runtime.initialize();
    final reply = await runtime.generateConstrained('system', 'prompt', {
      'intent': ['diagnose', 'replace'],
      'component': ['storage', 'ram'],
    });
    expect(reply, '{"intent":"replace","component":"storage"}');
    expect(calls, contains('session.streamAs'));
  });

  test('Android keeps the offline fallback without probing Apple', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await runtime.initialize();
    expect(await runtime.generate('system', 'prompt'), fallback.response);
    expect(calls, isEmpty);
  });

  test('cancel ignores late snapshots and permits a fresh response', () async {
    hold = true;
    await runtime.initialize();
    final pending = runtime.generate('system', 'old');
    final canceled = expectLater(pending, throwsStateError);
    await entered.future;
    await expectLater(runtime.generate('system', 'overlap'), throwsStateError);
    final oldRequest = request;
    await runtime.cancelGeneration();
    await canceled;
    expect(calls, contains('session.cancel'));
    expect(calls, contains('session.dispose'));
    hold = false;
    final retry = runtime.generate('system', 'new');
    emit(oldRequest, 'delta', 'STALE');
    expect(await retry, 'Hello world');
    await runtime.dispose();
    await expectLater(runtime.generate('system', 'closed'), throwsStateError);
  });
}
