// Gavin - Validated manual and item metadata for ApolLens guidance.
import 'inspection_step.dart';

final class RepairProcedure {
  RepairProcedure({
    required this.id,
    required this.revision,
    required this.title,
    required this.source,
    required Iterable<String> supportedItemIds,
    required Map<String, InspectionStep> steps,
  }) : supportedItemIds = Set.unmodifiable(supportedItemIds),
       steps = Map.unmodifiable(steps) {
    if (id.trim().isEmpty ||
        id != id.trim() ||
        revision.trim().isEmpty ||
        revision != revision.trim() ||
        title.trim().isEmpty) {
      throw ArgumentError(
        'Procedure identity, revision and title are required.',
      );
    }
    if (!['http', 'https'].contains(source.scheme) ||
        source.host.isEmpty ||
        source.userInfo.isNotEmpty) {
      throw ArgumentError('A manual source URL is required.');
    }
    if (this.supportedItemIds.isEmpty ||
        this.supportedItemIds.any(
          (id) => id.trim().isEmpty || id != id.trim(),
        )) {
      throw ArgumentError('Supported item IDs must be explicit and nonempty.');
    }
    if (this.steps.isEmpty ||
        this.steps.entries.any(
          (entry) =>
              entry.key.trim().isEmpty ||
              entry.key != entry.key.trim() ||
              entry.value.title.trim().isEmpty ||
              entry.value.detail.trim().isEmpty,
        )) {
      throw ArgumentError(
        'Every procedure step needs an ID and written guidance.',
      );
    }
  }

  final String id;
  final String revision;
  final String title;
  final Uri source;
  final Set<String> supportedItemIds;
  // Preserve the supplied order; keys are stable step IDs, not list indexes.
  final Map<String, InspectionStep> steps;

  bool supports(String itemId) => supportedItemIds.contains(itemId);
}
