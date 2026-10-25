// Gavin - Ask about user-confirmed live detections and show manual steps verbatim.
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/inspection_step.dart';
import '../models/repair_procedure.dart';
import '../services/frame_controller.dart';
import '../services/local_repair_assistant.dart';
import '../services/offline_speech_service.dart';
import '../services/procedure_service.dart';

typedef _ConfirmedPart = ({String label, int count});

class LocalAssistantPanel extends StatefulWidget {
  const LocalAssistantPanel({
    super.key,
    required this.assistant,
    required this.speech,
    required this.itemId,
    this.frames,
    this.procedures,
  });

  final LocalRepairAssistant assistant;
  final OfflineSpeechService speech;
  final String? itemId;
  final FrameController? frames;
  final ProcedureService? procedures;

  @override
  State<LocalAssistantPanel> createState() => _LocalAssistantPanelState();
}

class _LocalAssistantPanelState extends State<LocalAssistantPanel> {
  final _symptoms = TextEditingController();
  final Set<String> _selectedParts = {};
  List<InspectionStep> _steps = [];
  List<String> _confirmedParts = const [];
  int _conversation = 0, _stepIndex = 0;
  String? _question;
  String? _notice;
  String _reportedProblem = '';
  String? _guideKey;
  bool _awaitingSymptoms = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.frames?.addListener(_onFrame);
    final guide = _currentGuide;
    _guideKey = guide == null ? null : '${guide.id}:${guide.revision}';
  }

  @override
  void didUpdateWidget(LocalAssistantPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frames != widget.frames) {
      oldWidget.frames?.removeListener(_onFrame);
      widget.frames?.addListener(_onFrame);
    }
    final guide = _currentGuide;
    final key = guide == null ? null : '${guide.id}:${guide.revision}';
    if (widget.itemId != oldWidget.itemId ||
        _guideKey != key ||
        widget.frames != oldWidget.frames) {
      _guideKey = key;
      _resetConversation();
    }
  }

  RepairProcedure? get _currentGuide {
    final state = widget.procedures?.value;
    if (state?.status != ProcedureStatus.ready ||
        state?.itemId != widget.itemId ||
        widget.itemId == null ||
        !state!.procedure!.supports(widget.itemId!)) {
      return null;
    }
    return state.procedure;
  }

  List<_ConfirmedPart> get _parts {
    final counts = <String, int>{};
    for (final detection in widget.frames?.result?.detections ?? const []) {
      counts.update(detection.label, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts.entries
        .map((entry) => (label: entry.key, count: entry.value))
        .toList(growable: false);
  }

  void _onFrame() {
    if (!mounted) return;
    if (_confirmedParts.isNotEmpty) return;
    final available = _parts.map((part) => part.label).toSet();
    setState(
      () => _selectedParts.removeWhere((label) => !available.contains(label)),
    );
  }

  void _resetConversation() {
    _conversation++;
    _busy = false;
    _confirmedParts = const [];
    _stepIndex = 0;
    _selectedParts.clear();
    _steps = [];
    _question = null;
    _notice = null;
    _reportedProblem = '';
    _awaitingSymptoms = false;
    _symptoms.clear();
    unawaited(widget.assistant.cancel());
    unawaited(widget.speech.stop());
  }

  Future<void> _askAboutParts() async {
    if (_busy || _selectedParts.isEmpty) return;
    final conversation = ++_conversation;
    _confirmedParts = List.unmodifiable(_selectedParts);
    setState(() {
      _busy = true;
      _notice = null;
      _steps = [];
    });
    try {
      final reply = await widget.assistant.askAbout(
        _confirmedParts,
        _currentGuide,
        widget.itemId ?? '',
      );
      if (!mounted || conversation != _conversation) return;
      final question = reply.question ?? 'What seems wrong with these parts?';
      setState(() {
        _question = question;
        _awaitingSymptoms = true;
      });
      unawaited(widget.speech.speak(question));
    } catch (_) {
      if (mounted && conversation == _conversation) {
        setState(() {
          _confirmedParts = const [];
          _notice = 'The local model could not respond. Please retry.';
        });
      }
    } finally {
      if (mounted && conversation == _conversation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendSymptoms() async {
    if (_busy || !_awaitingSymptoms) return;
    final conversation = _conversation;
    final response = _symptoms.text.trim();
    if (response.isEmpty) return;
    final combined = [
      _reportedProblem,
      response,
    ].where((part) => part.isNotEmpty).join('\n');
    if (combined.length > 500) {
      setState(
        () => _notice =
            'Keep the combined description within 500 characters, or start over.',
      );
      return;
    }
    final guide = _currentGuide;
    if (guide == null) {
      const message =
          'No matching repair manual is available on this device. I cannot provide repair steps.';
      setState(() {
        _notice = message;
        _question = null;
        _awaitingSymptoms = false;
      });
      unawaited(widget.speech.speak(message));
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final reply = await widget.assistant.describeProblem(
        _confirmedParts,
        guide,
        widget.itemId!,
        combined,
      );
      if (!mounted || conversation != _conversation) return;
      _reportedProblem = combined;
      if (reply.stepIds.isNotEmpty) {
        final chosen = reply.stepIds.map((id) => guide.steps[id]!).toList();
        setState(() {
          _steps = chosen;
          _stepIndex = 0;
          _question = null;
          _awaitingSymptoms = false;
          _symptoms.clear();
        });
        _showStep(0);
      } else {
        final question = reply.question ?? 'What else can you tell me?';
        setState(() {
          _question = question;
          _awaitingSymptoms = true;
          _symptoms.clear();
        });
        unawaited(widget.speech.speak(question));
      }
    } catch (_) {
      if (mounted && conversation == _conversation) {
        setState(
          () => _notice = 'The local model could not respond. Please retry.',
        );
      }
    } finally {
      if (mounted && conversation == _conversation) {
        setState(() => _busy = false);
      }
    }
  }

  void _showStep(int index) {
    setState(() => _stepIndex = index);
    final step = _steps[index];
    unawaited(widget.speech.speak('${step.title}. ${step.detail}'));
  }

  Future<void> _install() async {
    await widget.assistant.installModel();
  }

  @override
  void dispose() {
    widget.frames?.removeListener(_onFrame);
    _conversation++;
    unawaited(widget.assistant.cancel());
    _symptoms.dispose();
    unawaited(widget.speech.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: widget.assistant,
        builder: (context, _) => _content(context),
      ),
    ),
  );

  Widget _content(BuildContext context) {
    final state = widget.assistant.state;
    final parts = _parts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Local repair assistant',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Confirmed component names stay on this device.'),
        if (state.status == LocalAssistantStatus.checking)
          const LinearProgressIndicator(),
        if (state.status == LocalAssistantStatus.modelNeeded ||
            state.status == LocalAssistantStatus.failed) ...[
          Text(
            state.message ??
                'Install the on-device Qwen model once before offline use.',
          ),
          const SizedBox(height: 8),
          const Text(
            'One-time online install: about 329 MB. Inference is on-device afterward.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _install,
              icon: const Icon(Icons.download),
              label: const Text('Install local model'),
            ),
          ),
        ],
        if (state.status == LocalAssistantStatus.installing) ...[
          LinearProgressIndicator(
            value: state.progress == 0 ? null : state.progress / 100,
          ),
          Text('Installing local model: ${state.progress}%'),
        ],
        if (state.status == LocalAssistantStatus.ready ||
            state.status == LocalAssistantStatus.generating) ...[
          const SizedBox(height: 8),
          if (_confirmedParts.isNotEmpty) ...[
            Text('Confirmed: ${_confirmedParts.join(', ')}'),
            TextButton(
              onPressed: () => setState(_resetConversation),
              child: const Text('Start over'),
            ),
          ] else if (widget.frames == null)
            const Text('No live component detector is connected yet.')
          else if (parts.isEmpty)
            const Text('Waiting for fresh live component boxes.')
          else ...[
            const Text(
              'Confirm the detected parts before sending their names to the model:',
            ),
            for (final part in parts)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selectedParts.contains(part.label),
                title: Text(part.label),
                subtitle: part.count > 1 ? Text('${part.count} boxes') : null,
                onChanged: _busy
                    ? null
                    : (selected) => setState(() {
                        if (selected == true) {
                          _selectedParts.add(part.label);
                        } else {
                          _selectedParts.remove(part.label);
                        }
                      }),
              ),
            if (!_awaitingSymptoms && _steps.isEmpty)
              FilledButton(
                onPressed: _busy || _selectedParts.isEmpty
                    ? null
                    : _askAboutParts,
                child: const Text('Confirm parts and ask what is wrong'),
              ),
          ],
          if (_question != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(_question!)),
            if (_awaitingSymptoms) ...[
              TextField(
                controller: _symptoms,
                enabled: !_busy,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Describe the problem',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendSymptoms(),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _busy ? null : _sendSymptoms,
                  child: const Text('Get manual-based steps'),
                ),
              ),
            ],
          ],
          if (_steps.isNotEmpty) ...[
            Text('Step ${_stepIndex + 1} of ${_steps.length}'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_steps[_stepIndex].title),
              subtitle: Text(_steps[_stepIndex].detail),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _stepIndex == 0
                      ? null
                      : () => _showStep(_stepIndex - 1),
                  child: const Text('Previous step'),
                ),
                FilledButton(
                  onPressed: () {
                    if (_stepIndex + 1 < _steps.length) {
                      _showStep(_stepIndex + 1);
                    } else {
                      unawaited(widget.speech.stop());
                      setState(() {
                        _steps = [];
                        _notice =
                            'Steps reviewed. Repair outcome has not been verified.';
                      });
                    }
                  },
                  child: Text(
                    _stepIndex + 1 < _steps.length
                        ? 'Next step'
                        : 'Finish review',
                  ),
                ),
              ],
            ),
          ],
          if (_steps.isNotEmpty) ...[
            if (_currentGuide case final guide?)
              SelectableText('Source manual: ${guide.source}'),
            const Text(
              'Review the manual steps; the app cannot verify safe repair.',
            ),
          ],
          if (_busy || state.status == LocalAssistantStatus.generating)
            const LinearProgressIndicator(),
        ],
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(liveRegion: true, child: Text(_notice!)),
          ),
        const Divider(),
        AnimatedBuilder(
          animation: widget.speech,
          builder: (context, _) => Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => widget.speech.setMuted(!widget.speech.muted),
                child: Text(
                  widget.speech.muted ? 'Turn audio on' : 'Mute audio',
                ),
              ),
              if (widget.speech.lastText != null && !widget.speech.muted)
                TextButton(
                  onPressed: widget.speech.replay,
                  child: const Text('Replay voice'),
                ),
              if (widget.speech.status == OfflineSpeechStatus.speaking)
                TextButton(
                  onPressed: widget.speech.stop,
                  child: const Text('Stop voice'),
                ),
              if (widget.speech.status == OfflineSpeechStatus.failed)
                const Text(
                  'Offline voice unavailable. Check installed device voices.',
                ),
            ],
          ),
        ),
      ],
    );
  }
}
