import 'package:apollens/models/repair_decision.dart';
import 'package:apollens/models/repair_progress.dart';
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
