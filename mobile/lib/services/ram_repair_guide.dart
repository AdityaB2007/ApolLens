// Gavin - Removable memory has its own sequence; soldered chips never get latch steps.
import '../models/repair_decision.dart';
import '../models/repair_progress.dart';
import 'storage_repair_steps.dart';

RepairCard ramReplacementCard(RepairProgress progress) {
  if (progress.decision.issue == RepairIssue.batteryHazard) {
    return batteryHazardStop;
  }
  if (progress.decision.intent != RepairIntent.replace ||
      progress.decision.target != RepairTarget.ram) {
    throw ArgumentError('RAM replacement requires a matching request.');
  }
  if (!progress.did('reassemble')) {
    for (final card in replacementPreparation) {
      if (!card.confirms.every(progress.has)) return card;
    }
  }
  if (progress.has(RepairFact.solderedRam)) {
    return const RepairCard(
      id: 'ram_soldered',
      title: 'This memory is soldered',
      detail:
          'These chips do not release with side clips. Do not pry or heat '
          'them; replacing them requires board-level repair expertise.',
      terminal: true,
    );
  }
  if (!progress.has(RepairFact.sodimmRam)) {
    return const RepairCard(
      id: 'ram_form',
      title: 'How is the memory mounted?',
      detail: 'Look at the actual module and its mounting before releasing it.',
      choices: {
        'Removable SO-DIMM with two side clips': RepairFact.sodimmRam,
        'Chips soldered to the board': RepairFact.solderedRam,
      },
    );
  }
  final cards = [..._memorySteps, reassembleEquipment, verifyMemory];
  return cards.where((card) => !progress.did(card.id)).firstOrNull ??
      _memoryFinish;
}

const _memorySteps = [
  RepairCard(
    id: 'ram_compatibility',
    title: 'Check the new memory',
    detail:
        'Use a replacement with the required SO-DIMM generation and '
        'specification. Confirm compatibility before removing the old module; '
        'a similar shape alone is not enough.',
    confirms: {RepairFact.replacementReady},
  ),
  RepairCard(
    id: 'ram_release',
    title: 'Release both side clips',
    detail:
        'Touch an unpainted chassis surface or use an ESD strap. Ease the '
        'two visible side clips outward until the module rises naturally. '
        'Do not flex the board or pry against chips.',
  ),
  RepairCard(
    id: 'ram_remove',
    title: 'Slide out the old module',
    detail:
        'Hold the module by its edges and slide it out at its raised socket '
        'angle. Avoid touching the gold contacts and keep it safe.',
  ),
  RepairCard(
    id: 'ram_insert',
    title: 'Seat the replacement',
    detail:
        'Match the notch to the socket key. Insert the module fully at the '
        'same angle, then lower it until both side clips engage. '
        'If it will not latch, recheck seating without force.',
  ),
];

const verifyMemory = RepairCard(
  id: 'ram_verify',
  title: 'Check the reported memory',
  choices: {
    'Expected capacity is shown': RepairFact.verificationMatches,
    'Capacity is wrong or it will not start': RepairFact.verificationNeedsHelp,
  },
  detail:
      'Start the laptop and check the memory capacity in firmware or the '
      'operating system. Note any startup error, beep or light pattern.',
);

const _memoryFinish = RepairCard(
  id: 'ram_finish',
  title: 'Check the original problem',
  detail:
      'Try the activity that showed the problem. If it persists, report '
      'the exact new result before changing another component.',
  terminal: true,
);
