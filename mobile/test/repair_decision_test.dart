import 'dart:convert';
import 'package:apollens/models/repair_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String reply({
    String intent = 'diagnose',
    String evidence = 'boot device not found',
  }) => jsonEncode({
    'intent': intent,
    'component': 'storage',
    'issue': 'bootMissing',
    'evidence': evidence,
  });
  test('accepts bounded classification with actual symptom evidence', () {
    final decision = RepairDecision.decode(
      reply(),
      'It says boot device not found.',
    );
    expect(decision.intent, RepairIntent.diagnose);
    expect(decision.target, RepairTarget.storage);
    expect(decision.issue, RepairIssue.bootMissing);
  });
  test(
    'obstacle output stays bounded and cannot replace required evidence',
    () {
      final value = jsonDecode(reply()) as Map<String, dynamic>;
      value['obstacle'] = 'stuckFastener';
      expect(
        RepairDecision.decode(
          jsonEncode(value),
          'boot device not found',
        ).obstacle,
        RepairObstacle.stuckFastener,
      );
      value['obstacle'] = 'invented_release_motion';
      expect(
        () => RepairDecision.decode(jsonEncode(value), 'boot device not found'),
        throwsFormatException,
      );
      value['obstacle'] = 'none';
      value.remove('evidence');
      expect(
        () => RepairDecision.decode(jsonEncode(value), 'boot device not found'),
        throwsFormatException,
      );
    },
  );

  test('preserves replacement intent without asserting proof of a fault', () {
    final decision = RepairDecision.decode(
      reply(intent: 'replace', evidence: 'I want to replace my SSD'),
      'I want to replace my SSD. It might still work.',
    );
    expect(decision.intent, RepairIntent.replace);
  });
  test('rejects invented evidence and instructions outside the schema', () {
    expect(
      () => RepairDecision.decode(
        reply(evidence: 'failed diagnostic'),
        'boot device not found',
      ),
      throwsFormatException,
    );
    expect(
      () => RepairDecision.decode(
        '{"steps":["Pull out the drive"]}',
        'boot device not found',
      ),
      throwsFormatException,
    );
    expect(
      () => RepairDecision.decode(
        reply(intent: 'remove_live_hardware'),
        'boot device not found',
      ),
      throwsFormatException,
    );
    expect(
      () => RepairDecision.decode(reply(evidence: ''), 'boot device not found'),
      throwsFormatException,
    );
  });
  test('rejects a diagnosis that targets the wrong subsystem', () {
    final wrong = reply().replaceFirst(
      '"component":"storage"',
      '"component":"battery"',
    );
    expect(
      () => RepairDecision.decode(wrong, 'boot device not found'),
      throwsFormatException,
    );
  });

  test('boot configuration requires an actual boot-entry or files report', () {
    final raw = reply().replaceFirst('bootMissing', 'bootConfiguration');
    expect(
      RepairDecision.decode(raw, 'boot device not found').issue,
      RepairIssue.unknown,
    );
    final valid = raw.replaceFirst(
      'boot device not found',
      'Boot Manager is missing',
    );
    expect(
      RepairDecision.decode(
        valid,
        'The SSD is listed; Boot Manager is missing',
      ).issue,
      RepairIssue.bootConfiguration,
    );
  });

  test('accepts enclosing quotation marks only around real source text', () {
    final decision = RepairDecision.decode(
      reply(evidence: '"boot device not found"'),
      'boot device not found',
    );
    expect(decision.evidence, 'boot device not found');
  });

  test(
    'normalizes whitespace and case without accepting paraphrased facts',
    () {
      final decision = RepairDecision.decode(
        reply(evidence: 'Boot device\nnot found'),
        'boot device not found',
      );
      expect(decision.target, RepairTarget.storage);
      expect(
        () => RepairDecision.decode(
          reply(evidence: 'The SSD is faulty'),
          'The SSD is absent from setup',
        ),
        throwsFormatException,
      );
    },
  );
}
