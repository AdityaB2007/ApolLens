// Gavin - Show one actionable instruction and keep completed work in context.
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/repair_decision.dart';
import '../models/repair_progress.dart';
import '../services/laptop_repair_guide.dart';
import '../services/offline_speech_service.dart';

class RepairPlanPanel extends StatefulWidget {
  const RepairPlanPanel({
    super.key,
    required this.progress,
    required this.speech,
    required this.onTellMore,
  });
  final RepairProgress progress;
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
    final text = '${card.title}. ${card.detail}';
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
    widget.progress.decision = RepairDecision(
      intent: intent,
      target: decision.target,
      issue: decision.issue,
      evidence: decision.evidence,
      obstacle: RepairObstacle.none,
    );
    setState(() {});
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
    final canReplace =
        decision.intent == RepairIntent.diagnose &&
        decision.issue != RepairIssue.batteryHazard &&
        decision.obstacle == RepairObstacle.none &&
        {RepairTarget.storage, RepairTarget.ram}.contains(decision.target);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            card.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        Text(card.detail, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in card.choices.entries)
              FilledButton(
                onPressed: () => _confirm(card, choice.value),
                child: Text(choice.key),
              ),
            if (card.choices.isEmpty && !card.terminal)
              FilledButton(
                onPressed: () => _confirm(card),
                child: const Text('Done'),
              ),
            if (decision.obstacle != RepairObstacle.none &&
                decision.issue != RepairIssue.batteryHazard)
              OutlinedButton(
                onPressed: () => _replace(continueStep: true),
                child: const Text('Return to the current step'),
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
