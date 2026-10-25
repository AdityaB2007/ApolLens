// Gavin - Expose one grounded action at a time, only after its prerequisites.
import '../models/repair_decision.dart';
import '../models/repair_progress.dart';
import 'storage_repair_steps.dart';

RepairCard storageReplacementCard(RepairProgress progress) {
  if (progress.decision.issue == RepairIssue.batteryHazard) {
    return batteryHazardStop;
  }
  if (progress.decision.intent != RepairIntent.replace ||
      progress.decision.target != RepairTarget.storage) {
    throw ArgumentError('Storage replacement requires a matching request.');
  }
  for (final card in replacementPreparation) {
    if (!card.confirms.every(progress.has)) return card;
  }
  if (progress.has(RepairFact.solderedStorage)) {
    return const RepairCard(
      id: 'storage_soldered',
      title: 'This storage is soldered',
      detail:
          'It cannot be unplugged as a removable drive. Do not pry or heat '
          'the board; this needs board-level repair equipment and expertise.',
      terminal: true,
    );
  }
  if (progress.has(RepairFact.sataDrive)) {
    return const RepairCard(
      id: 'storage_connector',
      title: 'Show the drive connector',
      detail:
          'A cabled drive can use different ribbon latches and caddies. '
          'Show the connector and mounting clearly before disconnecting them.',
      terminal: true,
    );
  }
  if (!progress.has(RepairFact.m2Drive)) {
    return const RepairCard(
      id: 'storage_form',
      title: 'What shape is the drive?',
      detail: 'Match the actual storage hardware, not just the word SSD.',
      choices: {
        'Slim M.2 card': RepairFact.m2Drive,
        'Cabled 2.5-inch drive': RepairFact.sataDrive,
        'Soldered chips': RepairFact.solderedStorage,
      },
    );
  }
  if (!progress.has(RepairFact.screwRetainer) &&
      !progress.has(RepairFact.clipRetainer)) {
    return const RepairCard(
      id: 'storage_retainer',
      title: 'What holds its free end?',
      detail:
          'Look at the end opposite the socket. If a shield hides it, '
          'get a clear view before releasing anything.',
      choices: {
        'Visible retaining screw': RepairFact.screwRetainer,
        'Latch with marked open/close positions': RepairFact.clipRetainer,
      },
    );
  }
  final screw = progress.has(RepairFact.screwRetainer);
  final cards = [
    m2Compatibility,
    screw ? m2ScrewRelease : m2ClipRelease,
    m2Remove,
    m2Insert,
    screw ? m2ScrewSecure : m2ClipSecure,
    reassembleEquipment,
    verifyStorage,
  ];
  return cards.where((card) => !progress.did(card.id)).firstOrNull ??
      storageFinish;
}

bool confirmStorageCard(
  RepairProgress progress,
  RepairCard card, {
  RepairFact? choice,
}) {
  // Ignore stale taps; model-authored cards cannot advance this guide.
  if (!identical(storageReplacementCard(progress), card)) return false;
  return progress.confirm(card, choice: choice);
}
