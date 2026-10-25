// Gavin - Confirm one component, then mark only its visible mounting fasteners.
import 'package:flutter/material.dart';
import '../models/detection.dart';
import '../models/fastener_map.dart';
import '../services/component_snapshot.dart';
import '../widgets/component_photo.dart';

class ComponentInspection extends StatefulWidget {
  const ComponentInspection({
    super.key,
    required this.snapshot,
    this.kind,
    this.requiredCount,
  });
  final ComponentSnapshot snapshot;
  final FastenerKind? kind;
  final int? requiredCount;
  @override
  State<ComponentInspection> createState() => _ComponentInspectionState();
}

class _ComponentInspectionState extends State<ComponentInspection> {
  final _marks = <FastenerMark>[];
  int? _selected;
  List<Detection> get _targets => widget.snapshot.result.detections
      .where((box) => box.label == widget.snapshot.label)
      .toList();
  @override
  void initState() {
    super.initState();
    if (_targets.length == 1) _selected = 0;
  }

  void _mark(Offset point) {
    if (_marks.length >= 12 ||
        _marks.any((mark) => (mark.position - point).distance < .04)) {
      return;
    }
    setState(() => _marks.add(FastenerMark(point, widget.kind!)));
  }

  @override
  Widget build(BuildContext context) {
    final target = _selected == null ? null : _targets[_selected!];
    final name = componentName(widget.snapshot.label);
    return Scaffold(
      appBar: AppBar(title: Text('Locate $name')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Frozen reference · pinch to zoom'),
                      if (_targets.length > 1) ...[
                        Text('Choose which $name you are working on.'),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (var i = 0; i < _targets.length; i++)
                              ChoiceChip(
                                label: Text('$name ${i + 1}'),
                                selected: i == _selected,
                                onSelected: (_) => setState(() {
                                  _selected = i;
                                  _marks.clear();
                                }),
                              ),
                          ],
                        ),
                      ],
                      if (widget.requiredCount != null)
                        Text(
                          'Mark ${widget.requiredCount} mounting locations.',
                        ),
                      if (target != null && widget.kind != null)
                        Text(
                          widget.kind == FastenerKind.screw
                              ? 'Tap each mounting screw for this part. Leave cover and circuit-board screws unmarked.'
                              : 'Tap the retaining clips for this part. Mark only releases you can identify.',
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: (constraints.maxHeight * .55).clamp(220, 480),
                  child: ComponentPhoto(
                    key: ValueKey(_selected),
                    snapshot: widget.snapshot,
                    region: target == null
                        ? const Rect.fromLTWH(0, 0, 1, 1)
                        : componentInspectionRegion(target),
                    marks: _marks,
                    onMark: target != null && widget.kind != null
                        ? _mark
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_marks.isNotEmpty)
                        Text(
                          'Marked by you: ${[for (var i = 0; i < _marks.length; i++) _marks[i].name(i)].join(', ')}',
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (_marks.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(() {
                                _marks.removeLast();
                              }),
                              child: const Text('Undo last mark'),
                            ),
                          if (widget.kind != null)
                            FilledButton(
                              onPressed:
                                  _marks.isEmpty ||
                                      (widget.requiredCount != null &&
                                          _marks.length != widget.requiredCount)
                                  ? null
                                  : () => Navigator.pop(
                                      context,
                                      FastenerMap(
                                        widget.snapshot,
                                        _targets[_selected!],
                                        _marks,
                                      ),
                                    ),
                              child: const Text('Confirm mounting locations'),
                            ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Return to live camera'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
