// Gavin - A 2.5-inch drive has a keyed plug and carrier, not an M.2 retainer.
import '../models/repair_progress.dart';
import '../models/repair_decision.dart';
import 'storage_repair_steps.dart';

RepairCard sataReplacementCard(RepairProgress progress) {
  if (progress.decision.issue == RepairIssue.batteryHazard) {
    return batteryHazardStop;
  }
  if (progress.decision.intent != RepairIntent.replace ||
      progress.decision.target != RepairTarget.storage ||
      !progress.has(RepairFact.sataDrive) ||
      (!progress.did('reassemble') &&
          (!progress.has(RepairFact.powerIsolated) ||
              !progress.has(RepairFact.coverOpen)))) {
    throw StateError(
      'Confirm access and power before handling the SATA drive.',
    );
  }
  if (!progress.has(RepairFact.sataDriveEndPlug)) {
    return const RepairCard(
      id: 'sata_connection',
      title: 'Identify the drive-end connection',
      detail:
          'This path covers a visible, friction-fit L-shaped SATA plug '
          'at the drive itself. Leave any board-end ribbon latch untouched. '
          'If the plug or its release is unclear, tell me more before continuing.',
      choices: {
        'Drive-end SATA plug, without a latch': RepairFact.sataDriveEndPlug,
      },
    );
  }
  if (!progress.has(RepairFact.sataCarrierScrews)) {
    return const RepairCard(
      id: 'sata_mount',
      title: 'Identify the carrier mounting',
      detail:
          'Confirm a removable, screw-secured carrier and identify its '
          'chassis fasteners. Do not confuse them with screws holding the drive '
          'cover or circuit board. Other mounts need their release established first.',
      choices: {
        'Screw-secured removable carrier': RepairFact.sataCarrierScrews,
      },
    );
  }
  final cards = [..._sataSteps, reassembleEquipment, verifyStorage];
  return cards.where((card) => !progress.did(card.id)).firstOrNull ??
      storageFinish;
}

const _sataSteps = [
  RepairCard(
    id: 'storage_compatibility',
    title: 'Match the replacement drive',
    detail:
        'Confirm a compatible 2.5-inch SATA drive with the correct height '
        'and carrier fit. Preserve any required original spacer. '
        'An M.2 or NVMe drive is not interchangeable with this connection.',
    confirms: {RepairFact.replacementReady},
  ),
  RepairCard(
    id: 'storage_release',
    title: 'Release the identified carrier fasteners',
    detail:
        'Touch an unpainted chassis surface or use an ESD strap. Support '
        'the drive and remove only the confirmed carrier-to-chassis fasteners. '
        'Keep them and avoid moving the drive against its cable or socket.',
  ),
  RepairCard(
    id: 'storage_remove',
    title: 'Separate the drive-end SATA connection',
    detail:
        'Hold the drive and any cable plug by its molded housing, never '
        'the wires or ribbon. Separate the confirmed friction-fit connection '
        'straight along its mating axis without twisting. Lift out the freed '
        'drive and carrier only after the connection is clear.',
  ),
  RepairCard(
    id: 'storage_carrier',
    title: 'Transfer the original carrier',
    detail:
        'Move the identified bracket or carrier to the replacement using '
        'its mounting screws and original orientation. Leave the drive cover '
        'and circuit-board screws alone. Stop if a spacer or mount does not fit.',
  ),
  RepairCard(
    id: 'storage_insert',
    title: 'Reconnect the replacement',
    detail:
        'Align the SATA connector’s L-shaped keys in the original '
        'orientation and seat the connection gently. Keep the board-end ribbon '
        'untouched and route the cable without tension or pinching.',
  ),
  RepairCard(
    id: 'storage_secure',
    title: 'Refit the carrier',
    detail:
        'Seat the carrier in its original mounting and refit its confirmed '
        'chassis fasteners. Keep cables clear and do not overtighten or bend the drive.',
  ),
];
