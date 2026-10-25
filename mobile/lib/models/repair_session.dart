// Gavin - Manual progress and separate observations for an ApolLens session.
import 'repair_procedure.dart';

final class RepairSession {
  RepairSession({
    required this.id,
    required this.itemId,
    required this.procedure,
    this.revision = 0,
    Iterable<String> confirmedStepIds = const [],
    Map<String, String> observations = const {},
  }) : confirmedStepIds = Set.unmodifiable(confirmedStepIds),
       observations = Map.unmodifiable(observations) {
    if (id.trim().isEmpty ||
        id != id.trim() ||
        revision < 0 ||
        !procedure.supports(itemId)) {
      throw ArgumentError(
        'Session identity, revision or matching item is invalid.',
      );
    }
    if (!this.confirmedStepIds.every(procedure.steps.containsKey)) {
      throw ArgumentError('Confirmed steps must belong to this procedure.');
    }
    if (this.observations.entries.any(
      (entry) =>
          entry.key.trim().isEmpty ||
          entry.key != entry.key.trim() ||
          entry.value.trim().isEmpty,
    )) {
      throw ArgumentError('Observations need a stable ID and text.');
    }
  }

  final String id;
  final String itemId;
  final RepairProcedure procedure;
  final int revision;
  final Set<String> confirmedStepIds;
  final Map<String, String> observations;

  // Reviewed steps are touch confirmations, not proof of repair or safety.
  bool get allReviewed => confirmedStepIds.length == procedure.steps.length;

  RepairSession revise({
    Iterable<String>? confirmedStepIds,
    Map<String, String>? observations,
  }) => RepairSession(
    id: id,
    itemId: itemId,
    procedure: procedure,
    revision: revision + 1,
    confirmedStepIds: confirmedStepIds ?? this.confirmedStepIds,
    observations: observations ?? this.observations,
  );
}
