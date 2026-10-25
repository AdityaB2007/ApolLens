// Gavin - Model reasoning classifies reported evidence; it never invents hardware facts.
import 'dart:convert';

enum RepairIntent { diagnose, replace }

enum RepairTarget { storage, ram, fan, battery, unknown }

enum RepairIssue {
  bootMissing,
  bootConfiguration,
  memoryErrors,
  fanNoise,
  overheating,
  batteryHazard,
  unknown,
}

final class RepairDecision {
  const RepairDecision({
    required this.intent,
    required this.target,
    required this.issue,
    required this.evidence,
  });
  final RepairIntent intent;
  final RepairTarget target;
  final RepairIssue issue;
  final String evidence;

  static const _fields = {'intent', 'component', 'issue', 'evidence'};

  factory RepairDecision.decode(String raw, String reportedProblem) {
    if (raw.length > 8000) throw const FormatException('Response is too long.');
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value.length != _fields.length ||
        value.keys.any((key) => !_fields.contains(key)) ||
        value.values.any((entry) => entry is! String)) {
      throw const FormatException('Expected the repair classification schema.');
    }
    T choice<T extends Enum>(String field, List<T> options) {
      return options.where((entry) => entry.name == value[field]).firstOrNull ??
          (throw FormatException('Unknown $field.'));
    }

    var evidence = (value['evidence'] as String).trim();
    if (evidence.length >= 2 &&
        ((evidence.startsWith('"') && evidence.endsWith('"')) ||
            (evidence.startsWith('“') && evidence.endsWith('”')))) {
      evidence = evidence.substring(1, evidence.length - 1).trim();
    }
    String normalize(String text) =>
        text.replaceAll(RegExp(r'\s+'), ' ').replaceAll('’', "'").toLowerCase();
    if (evidence.isEmpty ||
        evidence.length > 350 ||
        !normalize(reportedProblem).contains(normalize(evidence))) {
      throw const FormatException('Evidence must quote the reported problem.');
    }
    final intent = choice('intent', RepairIntent.values);
    final target = choice('component', RepairTarget.values);
    final issue = choice('issue', RepairIssue.values);
    final expected = switch (issue) {
      RepairIssue.bootMissing ||
      RepairIssue.bootConfiguration => RepairTarget.storage,
      RepairIssue.memoryErrors => RepairTarget.ram,
      RepairIssue.fanNoise => RepairTarget.fan,
      RepairIssue.batteryHazard => RepairTarget.battery,
      _ => null,
    };
    if ((intent == RepairIntent.diagnose ||
            issue == RepairIssue.batteryHazard) &&
        expected != null &&
        target != expected) {
      throw FormatException(
        'For ${issue.name}, component must be ${expected.name}.',
      );
    }
    return RepairDecision(
      intent: intent,
      target: target,
      issue: issue,
      evidence: evidence,
    );
  }
}
