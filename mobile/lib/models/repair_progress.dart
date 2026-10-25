// Gavin - Touch-confirmed repair progress stays separate from camera observations.
import 'repair_decision.dart';

enum RepairFact {
  dataPlanReady,
  powerIsolated,
  coverOpen,
  replacementReady,
  m2Drive,
  sataDrive,
  solderedStorage,
  sodimmRam,
  solderedRam,
  screwRetainer,
  clipRetainer,
  drivePresent,
  driveAbsent,
  bootManagerMissing,
}

final class RepairCard {
  const RepairCard({
    required this.id,
    required this.title,
    required this.detail,
    this.choices = const {},
    this.confirms = const {},
    this.terminal = false,
  });
  final String id, title, detail;
  final Map<String, RepairFact> choices;
  final Set<RepairFact> confirms;
  final bool terminal;
}

final class RepairProgress {
  RepairProgress(this.decision);
  RepairDecision decision;
  final _facts = <RepairFact>{};
  final _completed = <String>{};
  Set<RepairFact> get facts => Set.unmodifiable(_facts);
  List<String> get completedActions => List.unmodifiable(_completed);
  bool has(RepairFact fact) => _facts.contains(fact);
  bool did(String id) => _completed.contains(id);

  void requireReadinessReview() {
    if (did('reassemble')) return;
    _facts.removeAll({RepairFact.powerIsolated, RepairFact.coverOpen});
    _completed.removeAll({'isolate_power', 'confirm_access'});
  }

  static const _exclusive = [
    {RepairFact.m2Drive, RepairFact.sataDrive, RepairFact.solderedStorage},
    {RepairFact.sodimmRam, RepairFact.solderedRam},
    {RepairFact.screwRetainer, RepairFact.clipRetainer},
    {RepairFact.drivePresent, RepairFact.driveAbsent},
  ];

  bool confirm(RepairCard card, {RepairFact? choice}) {
    if (card.terminal || card.id.isEmpty || card.id.length > 80) {
      throw StateError('This card cannot confirm progress.');
    }
    if (card.choices.isNotEmpty && !card.choices.containsValue(choice)) {
      throw ArgumentError('Choose a displayed observation.');
    }
    if (card.choices.isEmpty && choice != null) {
      throw ArgumentError('This action does not accept an observation.');
    }
    if (_completed.contains(card.id)) return false;
    final additions = card.choices.isEmpty ? card.confirms : {choice!};
    final next = {..._facts};
    for (final group in _exclusive) {
      final selected = group.intersection(additions);
      if (selected.length > 1) throw StateError('Conflicting physical facts.');
      if (selected.isNotEmpty) next.removeAll(group);
    }
    next.addAll(additions);
    if (_completed.length >= 40) {
      throw StateError('Start a new repair session.');
    }
    // This records the person's acknowledgement, never automatic verification.
    _facts
      ..clear()
      ..addAll(next);
    _completed.add(card.id);
    return true;
  }
}
