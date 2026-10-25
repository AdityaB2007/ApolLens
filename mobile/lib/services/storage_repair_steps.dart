// Gavin - Offline handling steps; hardware details are confirmed before use.
import '../models/repair_progress.dart';

const replacementPreparation = [
  RepairCard(
    id: 'prepare_data',
    title: 'Protect your work',
    detail:
        'Save any open work. Keep the old drive intact; do not initialize, '
        'erase or format it. Preserve it for recovery if files are not backed up.',
    confirms: {RepairFact.dataPlanReady},
  ),
  RepairCard(
    id: 'isolate_power',
    title: 'Isolate power',
    detail:
        'Shut down and unplug the charger. The battery must be safely '
        'disconnected or service-disabled before touching internals. Stop if '
        'the battery is swollen, leaking, unusually hot or smells burnt.',
    confirms: {RepairFact.powerIsolated},
  ),
  RepairCard(
    id: 'confirm_access',
    title: 'Confirm access',
    detail:
        'Keep the exposed component in view. If a cover blocks it, identify '
        'its access fasteners before opening it. Do not pry an unidentified assembly.',
    confirms: {RepairFact.coverOpen},
  ),
];

const m2Compatibility = RepairCard(
  id: 'storage_compatibility',
  title: 'Check the replacement',
  detail:
      'Confirm the new drive supports this laptop’s interface, length and '
      'keying. A matching M.2 shape alone does not prove SATA/NVMe compatibility.',
  confirms: {RepairFact.replacementReady},
);

const m2ScrewRelease = RepairCard(
  id: 'storage_release',
  title: 'Remove the retaining screw',
  detail:
      'Touch an unpainted chassis surface or use an ESD strap. Support the '
      'card’s free end and remove only its identified retaining screw with a '
      'correctly fitting driver. Keep the screw.',
);

const m2ClipRelease = RepairCard(
  id: 'storage_release',
  title: 'Open the marked retainer',
  detail:
      'Touch an unpainted chassis surface or use an ESD strap. Support the '
      'card and move its identified retainer to the marked open position. '
      'Stop if the release motion is unclear; do not force it.',
);

const m2Remove = RepairCard(
  id: 'storage_remove',
  title: 'Slide out the old drive',
  detail:
      'Let the released end rise naturally. Hold the card by its edges and '
      'slide it straight out along the socket’s axis. Do not lift it out of '
      'the connector or force resistance.',
);

const m2Insert = RepairCard(
  id: 'storage_insert',
  title: 'Seat the replacement',
  detail:
      'Align the matching key and use the same entry angle as the old card. '
      'Slide the replacement fully into the socket by its edges before lowering '
      'its free end. Stop if it does not fit freely.',
);

const m2ScrewSecure = RepairCard(
  id: 'storage_secure',
  title: 'Secure the new drive',
  detail:
      'Lower the free end onto its support and refit the original retaining '
      'screw. Tighten it snugly without overtightening or bending the card.',
);

const m2ClipSecure = RepairCard(
  id: 'storage_secure',
  title: 'Close the marked retainer',
  detail:
      'Lower the free end onto its support and return the confirmed retainer '
      'to its marked closed position. The card should stay flat without force.',
);

const reassembleEquipment = RepairCard(
  id: 'reassemble',
  title: 'Close up before powering on',
  detail:
      'Check for loose screws and tools. Reconnect the undamaged battery '
      'using its confirmed connection, replace the covers, then reconnect the charger.',
);

const verifyStorage = RepairCard(
  id: 'storage_verify',
  title: 'Check the new drive is recognized',
  detail:
      'Start the laptop and check the firmware storage list. Record whether '
      'the new drive appears and any error. Recognition alone does not mean '
      'the operating system is installed or the problem is resolved.',
);

const storageFinish = RepairCard(
  id: 'storage_finish',
  title: 'Next: restore your system',
  detail:
      'Use prepared installation media or restore a backup to boot the new '
      'drive. Keep the old drive intact if you still need its files.',
  terminal: true,
);
