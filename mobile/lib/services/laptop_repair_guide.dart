// Gavin - Symptoms choose the component; confirmed facts choose physical steps.
import '../models/repair_decision.dart';
import '../models/repair_progress.dart';
import 'ram_repair_guide.dart';
import 'storage_repair_guide.dart';
import 'storage_repair_steps.dart';
import 'repair_obstacle_guide.dart';

RepairCard nextLaptopRepairCard(RepairProgress progress) {
  final decision = progress.decision;
  if (decision.issue == RepairIssue.batteryHazard) return batteryHazardStop;
  final obstacle = repairObstacleCard(
    progress,
    obstacle: progress.has(RepairFact.verificationNeedsHelp)
        ? RepairObstacle.notRecognized
        : null,
  );
  if (obstacle != null) return obstacle;
  if (progress.did('reassemble')) {
    if (decision.target == RepairTarget.storage &&
        !progress.did('storage_verify')) {
      return verifyStorage;
    }
    if (decision.target == RepairTarget.ram && !progress.did('ram_verify')) {
      return verifyMemory;
    }
  }
  if (decision.intent == RepairIntent.replace) {
    return switch (decision.target) {
      RepairTarget.storage => storageReplacementCard(progress),
      RepairTarget.ram => ramReplacementCard(progress),
      _ => const RepairCard(
        id: 'mounting_details',
        title: 'Show the mounting and connection',
        detail:
            'I need the visible mounting and connector details before '
            'guiding removal. Keep power isolated and do not force an unknown connection.',
        terminal: true,
      ),
    };
  }
  if (decision.issue == RepairIssue.batteryRuntime) {
    return const RepairCard(
      id: 'battery_runtime',
      title: 'Check battery condition',
      detail:
          'Save work. Use the operating system’s battery-health or power report '
          'to note capacity, condition and whether it charges. Short runtime alone '
          'does not mean swelling. Report the result and equipment model. '
          'If swelling, unusual heat or a burning smell appears, stop using it.',
      terminal: true,
    );
  }
  if (decision.issue == RepairIssue.bootMissing ||
      decision.issue == RepairIssue.bootConfiguration ||
      decision.target == RepairTarget.storage) {
    if (!progress.has(RepairFact.drivePresent) &&
        !progress.has(RepairFact.driveAbsent) &&
        !progress.has(RepairFact.verificationMatches)) {
      return const RepairCard(
        id: 'firmware_drive',
        title: 'Is the drive listed in firmware?',
        detail:
            'Check the BIOS/UEFI storage list. If you already checked, '
            'confirm that finding here. A boot error alone does not prove a failed drive.',
        choices: {
          'Drive is listed': RepairFact.drivePresent,
          'Drive is missing': RepairFact.driveAbsent,
        },
      );
    }
    if (progress.has(RepairFact.driveAbsent)) {
      return const RepairCard(
        id: 'drive_absent',
        title: 'The drive is not being recognized',
        detail:
            'A connection problem or failed drive can cause this. Keep '
            'the old drive intact and report any built-in storage diagnostic result. '
            'If you have chosen replacement, I can guide that now.',
        terminal: true,
      );
    }
    for (final card in _bootChecks) {
      if (!progress.did(card.id)) return card;
    }
  }
  if (decision.target == RepairTarget.ram) {
    for (final card in _memoryChecks) {
      if (!progress.did(card.id)) return card;
    }
  }
  if (decision.issue == RepairIssue.fanNoise ||
      decision.issue == RepairIssue.overheating) {
    for (final card in _coolingChecks) {
      if (!progress.did(card.id)) return card;
    }
  }
  return const RepairCard(
    id: 'new_observation',
    title: 'Tell me the latest result',
    detail:
        'Describe the exact error, sound or change after the actions you '
        'completed. Include the equipment model if available. I will keep those actions in context.',
    terminal: true,
  );
}

bool confirmLaptopRepairCard(
  RepairProgress progress,
  RepairCard card, {
  RepairFact? choice,
}) {
  if (!identical(nextLaptopRepairCard(progress), card)) return false;
  return progress.confirm(card, choice: choice);
}

const _bootChecks = [
  RepairCard(
    id: 'boot_entry',
    title: 'Check the operating-system boot entry',
    detail:
        'With the drive listed, check whether the expected operating-system '
        'boot entry exists. Note its exact name or error. Do not change storage-controller modes.',
  ),
  RepairCard(
    id: 'boot_recovery',
    title: 'Use non-erasing recovery tools',
    detail:
        'If trusted recovery media is already available, use its boot-repair '
        'tools before erasing or replacing a detected drive. Report the result '
        'and the operating system. Keep the original files intact.',
  ),
];

const _memoryChecks = [
  RepairCard(
    id: 'memory_signal',
    title: 'Record the exact startup signal',
    detail:
        'Note the full error, beep sequence or light pattern and the equipment '
        'model. The same code can mean different things on different models.',
  ),
  RepairCard(
    id: 'memory_test',
    title: 'Check the memory diagnostic result',
    detail:
        'If startup is possible, save work and run the built-in or vendor '
        'memory diagnostic. Record its exact result. A crash alone does not '
        'establish that the memory module failed.',
  ),
];

const _coolingChecks = [
  RepairCard(
    id: 'cooling_airflow',
    title: 'Check airflow and load',
    detail:
        'Use a firm, flat surface and clear the vents. Save work and close '
        'demanding apps. Observe whether the heat or noise settles at idle.',
  ),
  RepairCard(
    id: 'cooling_condition',
    title: 'Distinguish airflow from mechanical noise',
    detail:
        'Grinding or rattling at idle needs closer fan inspection. Shut '
        'down before opening the equipment. Show the fan mounting and connector '
        'before attempting physical removal.',
  ),
];
