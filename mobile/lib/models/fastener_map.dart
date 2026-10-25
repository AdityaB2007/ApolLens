// Gavin - Number only fasteners the person identifies inside the chosen part.
import 'dart:ui';
import '../services/component_snapshot.dart';
import 'detection.dart';

enum FastenerKind { screw, clip }

final class FastenerMark {
  FastenerMark(this.position, this.kind) {
    if (!position.dx.isFinite ||
        !position.dy.isFinite ||
        position.dx < 0 ||
        position.dx > 1 ||
        position.dy < 0 ||
        position.dy > 1) {
      throw ArgumentError(
        'Fastener position must be inside the inspection crop.',
      );
    }
  }
  final Offset position;
  final FastenerKind kind;
  String name(int index) =>
      '${kind == FastenerKind.screw ? 'Screw' : 'Clip'} ${index + 1}';
}

Rect componentInspectionRegion(Detection target) {
  final box = target.bounds;
  // Include the immediate mounting edge, never the rest of the chassis.
  final dx = box.width * .08, dy = box.height * .08;
  return Rect.fromLTRB(
    box.left - dx,
    box.top - dy,
    box.right + dx,
    box.bottom + dy,
  ).intersect(const Rect.fromLTWH(0, 0, 1, 1));
}

final class FastenerMap {
  FastenerMap(this.snapshot, this.target, List<FastenerMark> marks)
    : marks = List.unmodifiable(marks) {
    if (!snapshot.result.detections.contains(target) ||
        target.label != snapshot.label ||
        marks.isEmpty ||
        marks.length > 12) {
      throw ArgumentError(
        'Choose one detected part and 1–12 confirmed fasteners.',
      );
    }
    for (var i = 0; i < marks.length; i++) {
      if (marks
          .take(i)
          .any((mark) => (mark.position - marks[i].position).distance < .04)) {
        throw ArgumentError('Each marker must identify a separate fastener.');
      }
    }
  }
  final ComponentSnapshot snapshot;
  final Detection target;
  final List<FastenerMark> marks;
  Rect get region => componentInspectionRegion(target);
}
