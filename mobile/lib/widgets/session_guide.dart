// Gavin - Manual review of a supplied guide beside the live camera.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import '../models/repair_procedure.dart';
import '../models/repair_session.dart';
import '../services/session_service.dart';
import '../services/speech_controller.dart';
import 'instruction_audio.dart';

class SessionGuide extends StatefulWidget {
  const SessionGuide(
      {super.key,
      required this.procedure,
      required this.itemId,
      this.sessions,
      this.speech});
  final RepairProcedure procedure;
  final String itemId;
  final SessionService? sessions;
  final SpeechController? speech;

  @override
  State<SessionGuide> createState() => _SessionGuideState();
}

class _SessionGuideState extends State<SessionGuide> {
  late RepairSession _session;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final random = Random.secure();
    _session = RepairSession(
        id: base64Url.encode(List.generate(16, (_) => random.nextInt(256))),
        itemId: widget.itemId,
        procedure: widget.procedure);
    _index = 0;
    _saveAfterBuild();
  }

  @override
  void didUpdateWidget(SessionGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.procedure != widget.procedure ||
        oldWidget.itemId != widget.itemId) {
      _start();
    }
    if (oldWidget.sessions != widget.sessions) _saveAfterBuild();
  }

  void _saveAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.sessions?.save(_session);
    });
  }

  void _advance() {
    setState(() {
      final ids = _session.procedure.steps.keys.toList();
      _session = _session.revise(
          confirmedStepIds: _index == ids.length
              ? []
              : {..._session.confirmedStepIds, ids[_index]});
      _index = _index == ids.length ? 0 : _index + 1;
    });
    widget.sessions?.save(_session);
  }

  @override
  Widget build(BuildContext context) {
    final procedure = _session.procedure;
    final steps = procedure.steps.entries.toList();
    final complete = _index == steps.length;
    final step = complete ? null : steps[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(procedure.title, style: Theme.of(context).textTheme.headlineSmall),
        SelectableText('Source: ${procedure.source}'),
        Text(
            '${_session.confirmedStepIds.length} of ${steps.length} steps reviewed'),
        LinearProgressIndicator(
            value: _session.confirmedStepIds.length / steps.length),
        const SizedBox(height: 16),
        Text(complete ? 'Walkthrough complete' : step!.value.title,
            style: Theme.of(context).textTheme.titleLarge),
        Text(complete
            ? 'Steps reviewed manually. Repair and safety are not verified.'
            : step!.value.detail),
        InstructionAudio(
            key: ValueKey((_session.id, step?.key)),
            speech: widget.speech,
            text: complete
                ? null
                : '${step!.value.title}\n\n${step.value.detail}'),
        Wrap(spacing: 12, runSpacing: 8, children: [
          TextButton(
              onPressed: _index == 0 || complete
                  ? null
                  : () => setState(() => _index--),
              child: const Text('Previous')),
          FilledButton(
              onPressed: _advance,
              child: Text(complete
                  ? 'Start again'
                  : (_index == steps.length - 1
                      ? 'Confirm and finish'
                      : 'Confirm and next'))),
        ]),
        if (widget.sessions case final sessions?)
          ValueListenableBuilder<SessionSaveState>(
            valueListenable: sessions,
            builder: (context, state, _) {
              if (state.session?.id != _session.id) {
                return const Text('Starting review…');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                      liveRegion: true,
                      child: Text(switch (state.status) {
                        SessionSaveStatus.offline =>
                          'Progress is local to this visit.',
                        SessionSaveStatus.saving => 'Saving progress…',
                        SessionSaveStatus.saved => 'Progress saved.',
                        SessionSaveStatus.failed =>
                          'Progress could not be saved.',
                      })),
                  if (state.status == SessionSaveStatus.failed)
                    TextButton(
                        onPressed: sessions.retry,
                        child: const Text('Retry save')),
                ],
              );
            },
          ),
      ],
    );
  }
}
