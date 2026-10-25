// Gavin - Show one actionable instruction and keep completed work in context.
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/repair_decision.dart';
import '../models/repair_progress.dart';
import '../models/fastener_map.dart';
import '../models/detection.dart';
import '../services/component_snapshot.dart';
import '../services/frame_controller.dart';
import '../screens/component_inspection.dart';
import 'component_photo.dart';
import '../services/laptop_repair_guide.dart';
import '../services/offline_speech_service.dart';

class RepairPlanPanel extends StatefulWidget {
  const RepairPlanPanel({
    super.key,
    required this.progress,
    required this.speech,
    required this.onTellMore,
    this.frames,
  });
  final RepairProgress progress;
  final FrameController? frames;
  final OfflineSpeechService speech;
  final VoidCallback onTellMore;
  @override
  State<RepairPlanPanel> createState() => _RepairPlanPanelState();
}

class _RepairPlanPanelState extends State<RepairPlanPanel>
    with WidgetsBindingObserver {
  String? _announced;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _announce();
  }

  @override
  void didUpdateWidget(RepairPlanPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _announce();
  }

  void _announce() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }
    final card = nextLaptopRepairCard(widget.progress);
    final text = '${_title(card)}. ${card.detail}';
    if (_announced == text) return;
    _announced = text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _announced == text) unawaited(widget.speech.speak(text));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.speech.stop());
      widget.progress.requireReadinessReview();
      _announced = null;
      if (mounted) setState(() {});
    } else {
      _announce();
    }
  }

  void _confirm(RepairCard card, [RepairFact? choice]) {
    if (!identical(nextLaptopRepairCard(widget.progress), card)) return;
    final map = widget.progress.fasteners;
    if (widget.frames != null && _kind(card) != null && map == null) return;
    final position = widget.progress.fastenerPositions[card.id] ?? 0;
    if (_kind(card) == FastenerKind.screw &&
        map != null &&
        position + 1 < map.marks.length) {
      setState(() => widget.progress.fastenerPositions[card.id] = position + 1);
      _announce();
      return;
    }
    if (!confirmLaptopRepairCard(widget.progress, card, choice: choice)) return;
    setState(() {});
    _announce();
  }

  void _replace({bool continueStep = false}) {
    final decision = widget.progress.decision;
    final intent = continueStep
        ? widget.progress.did('prepare_data') &&
                  !widget.progress.did('reassemble')
              ? RepairIntent.replace
              : RepairIntent.diagnose
        : RepairIntent.replace;
    widget.progress.decision = decision.copyWith(
      intent: intent,
      obstacle: RepairObstacle.none,
    );
    setState(() {});
    _announce();
  }

  void _retryVerification() {
    widget.progress.retryVerification();
    setState(() {});
    _announce();
  }

  FastenerKind? _kind(RepairCard card) {
    if (!{
      'storage_release',
      'storage_secure',
      'ram_release',
      'ram_insert',
    }.contains(card.id)) {
      return null;
    }
    return widget.progress.decision.target == RepairTarget.ram ||
            widget.progress.has(RepairFact.clipRetainer)
        ? FastenerKind.clip
        : FastenerKind.screw;
  }

  String _title(RepairCard card) {
    final map = widget.progress.fasteners;
    final kind = _kind(card);
    if (map == null || kind == null) return card.title;
    if (kind == FastenerKind.clip) {
      final verb = card.id == 'ram_insert'
          ? 'Seat the module between'
          : card.id == 'storage_secure'
          ? 'Close'
          : 'Release';
      return '$verb ${[for (var i = 0; i < map.marks.length; i++) map.marks[i].name(i)].join(' and ')}';
    }
    final index = widget.progress.fastenerPositions[card.id] ?? 0;
    return '${card.id == 'storage_secure' ? 'Refit' : 'Remove'} ${map.marks[index].name(index)}';
  }

  Future<void> _locate(RepairCard card) async {
    if (_kind(card) != null && widget.progress.fasteners != null) return;
    final label = switch (widget.progress.decision.target) {
      RepairTarget.storage => 'storage_drive',
      RepairTarget.ram => 'ram_module',
      RepairTarget.fan => 'cooling_fan',
      RepairTarget.battery => 'main_battery',
      _ => null,
    };
    final frames = widget.frames;
    final snapshot = frames == null || label == null
        ? null
        : ComponentSnapshot.capture(frames, label);
    if (snapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bring ${label == null ? 'the part' : componentName(label)} into view and retry.',
          ),
        ),
      );
      return;
    }
    final progress = widget.progress;
    final kind = _kind(card);
    unawaited(widget.speech.stop());
    final map = await Navigator.push<FastenerMap>(
      context,
      MaterialPageRoute(
        builder: (_) => ComponentInspection(
          snapshot: snapshot,
          kind: kind,
          requiredCount: kind == null
              ? null
              : progress.decision.target == RepairTarget.ram
              ? 2
              : progress.has(RepairFact.m2Drive)
              ? 1
              : null,
        ),
      ),
    );
    if (!mounted || widget.progress != progress || map == null) return;
    setState(() {
      progress.fasteners = map;
      progress.fastenerPositions.clear();
      _announced = null;
    });
    _announce();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = nextLaptopRepairCard(widget.progress);
    final decision = widget.progress.decision;
    final needsMap =
        widget.frames != null &&
        _kind(card) != null &&
        widget.progress.fasteners == null;
    final canReplace =
        decision.intent == RepairIntent.diagnose &&
        !widget.progress.did('reassemble') &&
        decision.issue != RepairIssue.batteryHazard &&
        decision.obstacle == RepairObstacle.none &&
        {RepairTarget.storage, RepairTarget.ram}.contains(decision.target);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            _title(card),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        Text(card.detail, style: Theme.of(context).textTheme.bodyLarge),
        if (widget.progress.fasteners case final map?
            when _kind(card) != null) ...[
          const SizedBox(height: 12),
          const Text('Your numbered reference · not a live view'),
          SizedBox(
            height: 180,
            child: ComponentPhoto(
              snapshot: map.snapshot,
              region: map.region,
              marks: map.marks,
              activeMark: _kind(card) == FastenerKind.screw
                  ? widget.progress.fastenerPositions[card.id] ?? 0
                  : null,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.frames != null &&
                decision.target != RepairTarget.unknown &&
                decision.issue != RepairIssue.batteryHazard)
              OutlinedButton.icon(
                onPressed:
                    _kind(card) != null && widget.progress.fasteners != null
                    ? null
                    : () => _locate(card),
                icon: const Icon(Icons.center_focus_strong),
                label: Text(
                  _kind(card) == null
                      ? 'Locate part'
                      : widget.progress.fasteners == null
                      ? 'Map mounting fasteners'
                      : 'Locations confirmed',
                ),
              ),
            for (final choice in card.choices.entries)
              FilledButton(
                onPressed: () => _confirm(card, choice.value),
                child: Text(choice.key),
              ),
            if (card.choices.isEmpty && !card.terminal)
              FilledButton(
                onPressed: needsMap ? null : () => _confirm(card),
                child: const Text('Done'),
              ),
            if (decision.obstacle != RepairObstacle.none &&
                !widget.progress.did('reassemble') &&
                decision.issue != RepairIssue.batteryHazard)
              OutlinedButton(
                onPressed: () => _replace(continueStep: true),
                child: const Text('Return to the current step'),
              ),
            if (decision.issue != RepairIssue.batteryHazard &&
                widget.progress.did('reassemble') &&
                (widget.progress.has(RepairFact.verificationNeedsHelp) ||
                    decision.obstacle == RepairObstacle.notRecognized))
              OutlinedButton(
                onPressed: _retryVerification,
                child: const Text('Recheck the result'),
              ),
            if (canReplace)
              OutlinedButton(
                onPressed: _replace,
                child: Text(
                  decision.target == RepairTarget.storage
                      ? 'Help me replace the drive'
                      : 'Help me replace the RAM',
                ),
              ),
            TextButton(
              onPressed: widget.onTellMore,
              child: const Text('Tell you more'),
            ),
          ],
        ),
      ],
    );
  }
}
