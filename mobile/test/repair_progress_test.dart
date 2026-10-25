import 'package:apollens/models/repair_decision.dart';
import 'package:apollens/models/repair_progress.dart';
import 'package:apollens/services/storage_repair_guide.dart';
import 'package:apollens/services/ram_repair_guide.dart';
import 'package:apollens/services/laptop_repair_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RepairProgress progress;
  setUp(
    () => progress = RepairProgress(
      const RepairDecision(
        intent: RepairIntent.replace,
        target: RepairTarget.storage,
        issue: RepairIssue.bootMissing,
        evidence: 'replace the SSD',
      ),
    ),
  );
  test('M.2 replacement progresses without repeating diagnosis', () {
    for (var i = 0; i < 3; i++) {
      final card = storageReplacementCard(progress);
      confirmStorageCard(progress, card);
    }
    expect(progress.has(RepairFact.powerIsolated), isTrue);
    confirmStorageCard(
      progress,
      storageReplacementCard(progress),
      choice: RepairFact.m2Drive,
    );
    expect(storageReplacementCard(progress).id, 'storage_retainer');
    confirmStorageCard(
      progress,
      storageReplacementCard(progress),
      choice: RepairFact.screwRetainer,
    );
    final actions = <String>[];
    for (var i = 0; i < 10 && !storageReplacementCard(progress).terminal; i++) {
      final card = storageReplacementCard(progress);
      actions.add(card.id);
      confirmStorageCard(progress, card);
    }
    expect(actions, [
      'storage_compatibility',
      'storage_release',
      'storage_remove',
      'storage_insert',
      'storage_secure',
      'reassemble',
      'storage_verify',
    ]);
    expect(storageReplacementCard(progress).id, 'storage_finish');
  });

  test('stale or fabricated cards cannot skip power isolation', () {
    final stale = storageReplacementCard(progress);
    confirmStorageCard(progress, stale);
    expect(confirmStorageCard(progress, stale), isFalse);
    const fake = RepairCard(
      id: 'isolate_power',
      title: 'Skip power',
      detail: 'Invented',
    );
    expect(confirmStorageCard(progress, fake), isFalse);
    expect(progress.has(RepairFact.powerIsolated), isFalse);
  });

  test('missing-drive output cannot claim an unrecorded installation', () {
    progress.decision = const RepairDecision(
      intent: RepairIntent.replace,
      target: RepairTarget.storage,
      issue: RepairIssue.bootMissing,
      evidence: 'drive is absent',
      obstacle: RepairObstacle.notRecognized,
    );
    expect(nextLaptopRepairCard(progress).id, 'prepare_data');
    expect(progress.did('storage_insert'), isFalse);
  });

  for (final form in [RepairFact.sodimmRam, RepairFact.solderedRam]) {
    test('RAM mount: ${form.name}', () {
      progress.decision = const RepairDecision(
        intent: RepairIntent.replace,
        target: RepairTarget.ram,
        issue: RepairIssue.memoryErrors,
        evidence: 'Replace the RAM',
      );
      for (var i = 0; i < 3; i++) {
        progress.confirm(ramReplacementCard(progress));
      }
      expect(ramReplacementCard(progress).id, 'ram_form');
      progress.confirm(ramReplacementCard(progress), choice: form);
      if (form == RepairFact.solderedRam) {
        expect(ramReplacementCard(progress).terminal, isTrue);
        expect(progress.did('ram_release'), isFalse);
        return;
      }
      final actions = <String>[];
      for (var i = 0; i < 8 && !ramReplacementCard(progress).terminal; i++) {
        final card = ramReplacementCard(progress);
        actions.add(card.id);
        progress.confirm(card);
      }
      expect(actions, [
        'ram_compatibility',
        'ram_release',
        'ram_remove',
        'ram_insert',
        'reassemble',
        'ram_verify',
      ]);
      expect(ramReplacementCard(progress).id, 'ram_finish');
    });
  }

  test('replacement bypasses diagnosis and cannot replay stale checks', () {
    progress.decision = const RepairDecision(
      intent: RepairIntent.diagnose,
      target: RepairTarget.storage,
      issue: RepairIssue.bootMissing,
      evidence: 'boot device not found',
    );
    final diagnosis = nextLaptopRepairCard(progress);
    expect(diagnosis.id, 'firmware_drive');
    expect(
      confirmLaptopRepairCard(
        progress,
        diagnosis,
        choice: RepairFact.drivePresent,
      ),
      isTrue,
    );
    final check = nextLaptopRepairCard(progress);
    expect(check.id, 'boot_entry');
    confirmLaptopRepairCard(progress, check);
    expect(nextLaptopRepairCard(progress).id, 'boot_recovery');
    progress.decision = const RepairDecision(
      intent: RepairIntent.replace,
      target: RepairTarget.storage,
      issue: RepairIssue.bootMissing,
      evidence: 'replace the drive',
    );
    expect(nextLaptopRepairCard(progress).id, 'prepare_data');
    expect(confirmLaptopRepairCard(progress, check), isFalse);
    expect(progress.completedActions, contains('boot_entry'));
  });

  test('manual actions are recorded once with stable IDs', () {
    const card = RepairCard(
      id: 'isolate',
      title: 'Power off',
      detail: 'Confirm power is isolated.',
      confirms: {RepairFact.powerIsolated},
    );
    expect(progress.confirm(card), isTrue);
    expect(progress.confirm(card), isFalse);
    expect(progress.has(RepairFact.powerIsolated), isTrue);
    expect(progress.completedActions, ['isolate']);
    expect(
      () => progress.facts.add(RepairFact.coverOpen),
      throwsUnsupportedError,
    );
  });
  test('only a displayed choice can set a physical fact', () {
    const card = RepairCard(
      id: 'drive_form',
      title: 'Drive shape',
      detail: 'Which is visible?',
      choices: {'M.2': RepairFact.m2Drive, '2.5 inch': RepairFact.sataDrive},
    );
    expect(
      () => progress.confirm(card, choice: RepairFact.powerIsolated),
      throwsArgumentError,
    );
    expect(progress.facts, isEmpty);
    progress.confirm(card, choice: RepairFact.m2Drive);
    expect(progress.has(RepairFact.m2Drive), isTrue);
    expect(progress.has(RepairFact.sataDrive), isFalse);
  });
  test('conflicting actions and terminal cards never change progress', () {
    const invalid = RepairCard(
      id: 'invalid',
      title: '',
      detail: '',
      confirms: {RepairFact.m2Drive, RepairFact.sataDrive},
    );
    expect(() => progress.confirm(invalid), throwsStateError);
    const done = RepairCard(
      id: 'done',
      title: 'Reviewed',
      detail: '',
      terminal: true,
    );
    expect(() => progress.confirm(done), throwsStateError);
    expect(progress.facts, isEmpty);
    expect(progress.completedActions, isEmpty);
  });
}
