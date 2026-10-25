// Gavin - A difficulty pauses the current action without erasing completed work.
import '../models/repair_decision.dart';
import '../models/repair_progress.dart';

RepairCard? repairObstacleCard(
  RepairProgress progress, {
  RepairObstacle? obstacle,
}) {
  final kind = obstacle ?? progress.decision.obstacle;
  if (kind == RepairObstacle.notRecognized &&
      !progress.did('storage_insert') &&
      !progress.did('ram_insert')) {
    return null;
  }
  return switch (kind) {
    RepairObstacle.none => null,
    RepairObstacle.stuckFastener => const RepairCard(
      id: 'stuck_fastener',
      title: 'Stop before the screw head gets worse',
      detail:
          'Keep power isolated. Check that the bit fully matches the head '
          'and sits straight. If it slips or the head is damaged, stop turning; '
          'use proper extraction assistance rather than drilling or forcing it.',
      terminal: true,
    ),
    RepairObstacle.unclearConnector => const RepairCard(
      id: 'unclear_connector',
      title: 'Leave the connector in place for now',
      detail:
          'Keep power isolated. Describe the visible socket, tabs and cable '
          'direction. A hinged latch, sliding lock and direct plug release '
          'differently. Do not pull or pry until the type is established.',
      terminal: true,
    ),
    RepairObstacle.poorFit => const RepairCard(
      id: 'poor_fit',
      title: 'Do not force the replacement',
      detail:
          'Keep power isolated. Compare the old and new part’s keying, '
          'length and interface specification. Describe what does not line up. '
          'A similar shape does not establish compatibility.',
      terminal: true,
    ),
    RepairObstacle.notRecognized => const RepairCard(
      id: 'replacement_missing',
      title: 'Check the installation result',
      detail:
          'The installation remains recorded. With the equipment closed, '
          'note whether firmware lists the new part and report any exact '
          'error or built-in diagnostic result. Keep the old part intact; '
          'do not erase a drive holding files you need.',
      terminal: true,
    ),
  };
}
