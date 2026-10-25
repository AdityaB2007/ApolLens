// Gavin - Model reasoning classifies reported evidence; it never invents hardware facts.
import 'dart:convert';

enum RepairIntent { diagnose, replace }

enum RepairTarget { storage, ram, fan, battery, unknown }

enum RepairObstacle {
  none,
  stuckFastener,
  unclearConnector,
  poorFit,
  notRecognized,
}

List<RepairObstacle> obstaclesForAction(String? action) {
  if (action?.endsWith('_verify') == true ||
      action?.endsWith('_finish') == true) {
    return const [RepairObstacle.none, RepairObstacle.notRecognized];
  }
  if (action?.endsWith('_insert') == true) {
    return const [
      RepairObstacle.none,
      RepairObstacle.unclearConnector,
      RepairObstacle.poorFit,
    ];
  }
  if (action?.endsWith('_release') == true ||
      action?.endsWith('_secure') == true) {
    return const [
      RepairObstacle.none,
      RepairObstacle.unclearConnector,
      RepairObstacle.stuckFastener,
    ];
  }
  if (action?.endsWith('_remove') == true) {
    return const [RepairObstacle.none, RepairObstacle.unclearConnector];
  }
  return const [RepairObstacle.none];
}

enum RepairIssue {
  bootMissing,
  bootConfiguration,
  memoryErrors,
  fanNoise,
  overheating,
  batteryHazard,
  batteryRuntime,
  unknown,
}

final class RepairDecision {
  const RepairDecision({
    required this.intent,
    required this.target,
    required this.issue,
    required this.evidence,
    this.obstacle = RepairObstacle.none,
  });
  final RepairIntent intent;
  final RepairTarget target;
  final RepairIssue issue;
  final String evidence;
  final RepairObstacle obstacle;

  RepairDecision copyWith({RepairIntent? intent, RepairObstacle? obstacle}) =>
      RepairDecision(
        intent: intent ?? this.intent,
        target: target,
        issue: issue,
        evidence: evidence,
        obstacle: obstacle ?? this.obstacle,
      );

  static const _fields = {'intent', 'component', 'issue', 'evidence'};

  factory RepairDecision.decode(String raw, String reportedProblem) {
    if (raw.length > 8000) throw const FormatException('Response is too long.');
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        !_fields.every(value.containsKey) ||
        value.keys.any((key) => !_fields.contains(key) && key != 'obstacle') ||
        value.values.any((entry) => entry is! String)) {
      throw const FormatException('Expected the repair classification schema.');
    }
    T choice<T extends Enum>(String field, List<T> options) {
      final name = (value[field] as String).trim().toLowerCase();
      return options
              .where((entry) => entry.name.toLowerCase() == name)
              .firstOrNull ??
          (throw FormatException('Unknown $field.'));
    }

    var evidence = (value['evidence'] as String).trim();
    if (evidence.length >= 2 &&
        ((evidence.startsWith('"') && evidence.endsWith('"')) ||
            (evidence.startsWith('“') && evidence.endsWith('”')) ||
            (evidence.startsWith("'") && evidence.endsWith("'")))) {
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
    var issue = choice('issue', RepairIssue.values);
    if (issue == RepairIssue.bootConfiguration &&
        !RegExp(
          r'boot manager|bootloader|boot files|boot configuration|bcd|grub',
          caseSensitive: false,
        ).hasMatch(reportedProblem)) {
      // An unsupported software diagnosis becomes unknown, never a hardware fault.
      issue = RepairIssue.unknown;
    }
    final expected = switch (issue) {
      RepairIssue.bootMissing ||
      RepairIssue.bootConfiguration => RepairTarget.storage,
      RepairIssue.memoryErrors => RepairTarget.ram,
      RepairIssue.fanNoise => RepairTarget.fan,
      RepairIssue.batteryHazard ||
      RepairIssue.batteryRuntime => RepairTarget.battery,
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
      obstacle: value.containsKey('obstacle')
          ? choice('obstacle', RepairObstacle.values)
          : RepairObstacle.none,
    );
  }
}
