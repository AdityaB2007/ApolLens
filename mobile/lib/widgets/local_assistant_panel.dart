// Gavin - Confirm observations, then guide an offline troubleshooting conversation.
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/inspection_step.dart';
import '../models/camera_frame.dart';
import '../models/detection.dart';
import '../models/recognition_state.dart';
import '../models/repair_procedure.dart';
import '../services/frame_controller.dart';
import '../services/local_repair_assistant.dart';
import '../services/offline_speech_service.dart';
import '../services/procedure_service.dart';

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
  List<String>? _reviewParts;
  CameraFrame? _reviewFrame;
  List<InspectionStep> _steps = [];
  List<InspectionStep> _previousChecks = [];
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

  List<String> get _parts {
    final labels = (widget.frames?.result?.detections ?? const <Detection>[])
        .map((detection) => detection.label)
        .toSet()
        .toList();
    labels.sort((a, b) => componentName(a).compareTo(componentName(b)));
    return labels;
  }

  void _onFrame() {
    if (!mounted || _confirmedParts.isNotEmpty) return;
    final current = widget.frames?.resultFrame;
    final changed =
        current != null &&
        _reviewFrame != null &&
        (current.sessionId != _reviewFrame!.sessionId ||
            current.orientation != _reviewFrame!.orientation);
    if (changed ||
        widget.frames?.value.status == RecognitionStatus.unavailable) {
      _reviewParts = null;
      _reviewFrame = null;
      _selectedParts.clear();
    }
    // Missed detections never move the held list or undo a touch selection.
    setState(() {});
  }

  void _review() {
    final parts = _parts;
    if (parts.isEmpty || widget.frames?.result?.blocked == true) return;
    setState(() {
      _reviewParts = List.unmodifiable(parts);
      _reviewFrame = widget.frames?.resultFrame;
      _selectedParts.clear();
    });
  }

  void _resetConversation() {
    _conversation++;
    _reviewParts = null;
    _reviewFrame = null;
    _busy = false;
    _confirmedParts = const [];
    _stepIndex = 0;
    _selectedParts.clear();
    _steps = [];
    _question = null;
    _notice = null;
    _reportedProblem = '';
    _previousChecks = [];
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
        _confirmedParts.map(componentName).toList(),
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
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final reply = await widget.assistant.describeProblem(
        _confirmedParts.map(componentName).toList(),
        guide,
        widget.itemId ?? '',
        combined,
        previousSteps: _previousChecks,
      );
      if (!mounted || conversation != _conversation) return;
      _reportedProblem = combined;
      if (reply.steps.isNotEmpty) {
        final chosen = reply.steps;
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
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(20),
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
          _steps.isNotEmpty
              ? 'Suggested checks'
              : _confirmedParts.isNotEmpty
              ? 'Troubleshoot'
              : 'Select components',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),

        if (state.status == LocalAssistantStatus.checking)
          const LinearProgressIndicator(),
        if (state.status == LocalAssistantStatus.modelNeeded ||
            state.status == LocalAssistantStatus.failed) ...[
          Text(
            state.message ?? 'Download the assistant once to use it offline.',
          ),
          const SizedBox(height: 8),
          const Text('About 1 GB. Works offline after setup.'),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _install,
              icon: const Icon(Icons.download),
              label: const Text('Download assistant'),
            ),
          ),
        ],
        if (state.status == LocalAssistantStatus.installing) ...[
          LinearProgressIndicator(
            value: state.progress == 0 ? null : state.progress / 100,
          ),
          Text('Setting up assistant: ${state.progress}%'),
        ],
        if (state.status == LocalAssistantStatus.ready ||
            state.status == LocalAssistantStatus.generating) ...[
          const SizedBox(height: 8),
          if (_confirmedParts.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final part in _confirmedParts)
                  Chip(label: Text(componentName(part))),
              ],
            ),
            TextButton(
              onPressed: () => setState(_resetConversation),
              child: const Text('Scan again'),
            ),
          ] else if (widget.frames == null)
            const Text('Component detection is not available on this device.')
          else if (_reviewParts == null) ...[
            const SizedBox(height: 8),
            Text(
              parts.isEmpty
                  ? 'Bring the components into view.'
                  : parts.map(componentName).join(' · '),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: parts.isEmpty ? null : _review,
                icon: const Icon(Icons.checklist_rounded, size: 20),
                label: const Text('Review parts'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text('List paused. Choose what needs attention.'),
            const SizedBox(height: 8),
            for (final part in _reviewParts!)
              CheckboxListTile(
                key: ValueKey(part),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _selectedParts.contains(part),
                title: Text(componentName(part)),
                onChanged: _busy
                    ? null
                    : (selected) => setState(() {
                        if (selected == true) {
                          _selectedParts.add(part);
                        } else {
                          _selectedParts.remove(part);
                        }
                      }),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => setState(_resetConversation),
                  child: const Text('Scan again'),
                ),
                FilledButton(
                  onPressed: _busy || _selectedParts.isEmpty
                      ? null
                      : _askAboutParts,
                  child: const Text('Continue'),
                ),
              ],
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
                  labelText: 'What’s wrong?',
                  hintText: 'For example, it shuts down unexpectedly',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendSymptoms(),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _busy ? null : _sendSymptoms,
                  child: const Text('Find next steps'),
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
                  child: const Text('Back'),
                ),
                FilledButton(
                  onPressed: () {
                    if (_stepIndex + 1 < _steps.length) {
                      _showStep(_stepIndex + 1);
                    } else {
                      setState(() {
                        _previousChecks = List.unmodifiable([
                          ..._previousChecks,
                          ..._steps,
                        ]);
                        _steps = [];
                        _question = 'What changed after those checks?';
                        _notice = null;
                        _awaitingSymptoms = true;
                      });
                      unawaited(widget.speech.speak(_question!));
                    }
                  },
                  child: Text(
                    _stepIndex + 1 < _steps.length ? 'Next' : 'Check result',
                  ),
                ),
              ],
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
        const SizedBox(height: 16),
        const Divider(),
        AnimatedBuilder(
          animation: widget.speech,
          builder: (context, _) => Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => widget.speech.setMuted(!widget.speech.muted),
                child: Text(widget.speech.muted ? 'Sound off' : 'Sound on'),
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
                  'Voice unavailable. Check the voices installed in Settings.',
                ),
            ],
          ),
        ),
      ],
    );
  }
}
