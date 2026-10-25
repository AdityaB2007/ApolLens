// Gavin - Confirm observations, then guide an offline troubleshooting conversation.
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/repair_progress.dart';
import '../models/repair_decision.dart';
import 'repair_plan_panel.dart';
import '../models/camera_frame.dart';
import '../models/detection.dart';
import '../models/recognition_state.dart';
import '../models/repair_procedure.dart';
import '../services/frame_controller.dart';
import '../services/laptop_repair_guide.dart';
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
    this.onTargetChanged,
  });

  final LocalRepairAssistant assistant;
  final OfflineSpeechService speech;
  final String? itemId;
  final FrameController? frames;
  final ProcedureService? procedures;
  final ValueChanged<String?>? onTargetChanged;

  @override
  State<LocalAssistantPanel> createState() => _LocalAssistantPanelState();
}

class _LocalAssistantPanelState extends State<LocalAssistantPanel>
    with WidgetsBindingObserver {
  final _symptoms = TextEditingController();
  final _observed = <String, ({int hits, DateTime lastSeen})>{};
  CameraFrame? _lastFrame;
  Timer? _observationExpiry;
  RepairProgress? _progress;
  List<String> _confirmedParts = const [];
  int _conversation = 0;
  String? _question, _questionAction;
  String? _notice;
  final _observations = <String>[];
  String? _guideKey;
  bool _awaitingSymptoms = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final labels = _observed.entries
        .where((entry) => entry.value.hits >= 2)
        .map((entry) => entry.key)
        .toList();
    labels.sort((a, b) => componentName(a).compareTo(componentName(b)));
    return labels;
  }

  bool get _looksLikeLaptop {
    final parts = _confirmedParts.isEmpty ? _parts : _confirmedParts;
    return parts.contains('main_battery') &&
        parts.contains('cooling_fan') &&
        (parts.contains('ram_module') || parts.contains('storage_drive'));
  }

  void _onFrame() {
    if (!mounted || _confirmedParts.isNotEmpty) return;
    final current = widget.frames?.resultFrame;
    final result = widget.frames?.result;
    if (widget.frames?.value.status == RecognitionStatus.unavailable ||
        result?.blocked == true ||
        (current != null &&
            _lastFrame != null &&
            (current.sessionId != _lastFrame!.sessionId ||
                current.orientation != _lastFrame!.orientation))) {
      _observationExpiry?.cancel();
      _observed.clear();
      _lastFrame = null;
    }
    if (current != null &&
        result?.blocked != true &&
        current.sequence != _lastFrame?.sequence) {
      _observationExpiry?.cancel();
      _observationExpiry = Timer(const Duration(seconds: 5), () {
        if (!mounted || _confirmedParts.isNotEmpty) return;
        setState(() {
          _observed.clear();
          _lastFrame = null;
        });
      });
      // Two sightings admit a part; brief dropouts do not reshuffle the list.
      for (final label in result!.detections.map((box) => box.label).toSet()) {
        final seen = _observed[label];
        _observed[label] = (
          hits: (seen?.hits ?? 0) + 1,
          lastSeen: current.capturedAt,
        );
      }
      _observed.removeWhere(
        (_, seen) =>
            current.capturedAt.difference(seen.lastSeen) >
            const Duration(seconds: 5),
      );
      _lastFrame = current;
    }
    setState(() {});
  }

  void _publishFocus() {
    final label = switch (_progress?.decision.target) {
      RepairTarget.storage => 'storage_drive',
      RepairTarget.ram => 'ram_module',
      RepairTarget.fan => 'cooling_fan',
      RepairTarget.battery => 'main_battery',
      _ => null,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTargetChanged?.call(label);
    });
  }

  void _resetConversation() {
    _observationExpiry?.cancel();
    _conversation++;
    _observed.clear();
    _lastFrame = null;
    _busy = false;
    _confirmedParts = const [];
    _progress = null;
    _questionAction = null;
    _question = null;
    _notice = null;
    _observations.clear();
    _publishFocus();
    _awaitingSymptoms = false;
    _symptoms.clear();
    unawaited(widget.assistant.cancel());
    unawaited(widget.speech.stop());
  }

  void _confirmParts() {
    final parts = _parts;
    if (_busy || parts.isEmpty) return;
    _observationExpiry?.cancel();
    _conversation++;
    setState(() {
      _confirmedParts = List.unmodifiable(parts);
      _notice = null;
      _progress = null;
      _question = 'What is wrong?';
      _awaitingSymptoms = true;
    });
    unawaited(widget.speech.speak(_question!));
  }

  void _cancelReply() {
    _conversation++;
    unawaited(widget.assistant.cancel());
    unawaited(widget.speech.stop());
    setState(() {
      _busy = false;
      _notice = null;
      _question ??= 'What is wrong?';
      _awaitingSymptoms = _confirmedParts.isNotEmpty;
    });
  }

  Future<void> _sendSymptoms() async {
    if (_busy || !_awaitingSymptoms) return;
    final conversation = _conversation;
    final response = _symptoms.text.trim();
    if (response.isEmpty) return;
    final history = [..._observations, response];
    while (history.join('\n').length > 6000 && history.length > 2) {
      history.removeAt(1);
    }
    final combined = history.join('\n');
    final previous = _progress;
    unawaited(widget.speech.stop());
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final decision = await widget.assistant.reason(
        _confirmedParts.map(componentName).toList(),
        combined,
        completedActions: previous?.completedActions ?? const [],
        latestUpdate: response,
        confirmedFacts: previous?.facts ?? const {},
        currentDecision: previous?.decision,
        currentAction: _questionAction,
      );
      if (!mounted || conversation != _conversation) return;
      if (previous != null && decision.target == RepairTarget.unknown) {
        setState(() {
          _notice =
              'I’m not sure which part that update refers to. '
              'Your previous guidance is still available.';
        });
        unawaited(widget.speech.speak(_notice!));
        return;
      }
      setState(() {
        _observations
          ..clear()
          ..addAll(history);
        if (previous == null || previous.decision.target != decision.target) {
          _progress = RepairProgress(decision);
        } else {
          previous.decision = decision;
        }
        _question = null;
        _awaitingSymptoms = false;
        _symptoms.clear();
      });
      _publishFocus();
    } catch (error) {
      if (mounted && conversation == _conversation) {
        setState(
          () => _notice = error is FormatException
              ? 'I couldn’t choose a clear next step. Add an exact error or a new observation.'
              : error is TimeoutException
              ? 'The local model took too long. Your description is still here; try again.'
              : 'The local model could not respond. Please retry.',
        );
      }
    } finally {
      if (mounted && conversation == _conversation) {
        setState(() => _busy = false);
      }
    }
  }

  void _tellMore() {
    _questionAction = _progress == null
        ? null
        : nextLaptopRepairCard(_progress!).id;
    setState(() {
      _question = 'What changed, or where are you stuck?';
      _awaitingSymptoms = true;
    });
    unawaited(widget.speech.speak(_question!));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _progress?.requireReadinessReview();
    if (_busy) _cancelReply();
  }

  Future<void> _install() async {
    await widget.assistant.installModel();
  }

  @override
  void dispose() {
    _observationExpiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
        if (_confirmedParts.isEmpty) ...[
          Text(
            _looksLikeLaptop
                ? 'This appears to be a laptop computer'
                : 'Detected parts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
        ],

        if (state.status == LocalAssistantStatus.checking)
          const LinearProgressIndicator(),
        if (state.status == LocalAssistantStatus.modelNeeded ||
            state.status == LocalAssistantStatus.failed) ...[
          Text(
            state.message ?? 'Download the assistant once to use it offline.',
          ),
          const SizedBox(height: 8),
          if (state.status == LocalAssistantStatus.failed)
            TextButton.icon(
              onPressed: widget.assistant.retrySetup,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry setup'),
            ),
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
          if (_confirmedParts.isNotEmpty)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _confirmedParts.map(componentName).join(' · '),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                TextButton(
                  onPressed: () => setState(_resetConversation),
                  child: const Text('Scan again'),
                ),
              ],
            )
          else if (parts.isNotEmpty) ...[
            const Text('These are the parts I detected'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final part in parts)
                  Chip(label: Text(componentName(part))),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _confirmParts,
              child: const Text('That looks right'),
            ),
          ] else
            Text(
              widget.frames?.result?.blocked == true
                  ? 'Clear the camera’s view.'
                  : widget.frames == null
                  ? 'Component detection is unavailable.'
                  : 'Bring the components into view.',
            ),
          if (_question != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(_question!)),
            if (_awaitingSymptoms) ...[
              TextField(
                controller: _symptoms,
                readOnly: _busy,
                minLines: 1,
                maxLines: 4,
                maxLength: 1200,
                decoration: const InputDecoration(
                  labelText: 'Describe the problem',
                  counterText: '',
                  hintText: 'For example, it shuts down unexpectedly',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendSymptoms(),
              ),
              if (!_busy)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: _sendSymptoms,
                    child: const Text('Find next steps'),
                  ),
                ),
            ],
          ],
          if (_progress != null && _awaitingSymptoms && !_busy)
            TextButton(
              onPressed: () {
                unawaited(widget.speech.stop());
                setState(() {
                  _question = null;
                  _notice = null;
                  _awaitingSymptoms = false;
                });
              },
              child: const Text('Return to previous guidance'),
            ),
          if (_progress != null && !_awaitingSymptoms && !_busy)
            RepairPlanPanel(
              progress: _progress!,
              frames: widget.frames,
              speech: widget.speech,
              onTellMore: _tellMore,
            ),

          if (_busy || state.status == LocalAssistantStatus.generating)
            Semantics(
              liveRegion: true,
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Generating a response',
                        ),
                      ),
                      SizedBox(width: 12),
                      Flexible(child: Text('Thinking…')),
                    ],
                  ),
                  TextButton(
                    onPressed: _cancelReply,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
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
              if (widget.speech.status == OfflineSpeechStatus.speaking ||
                  widget.speech.status == OfflineSpeechStatus.paused)
                TextButton.icon(
                  onPressed: widget.speech.status == OfflineSpeechStatus.paused
                      ? widget.speech.resume
                      : widget.speech.pause,
                  icon: Icon(
                    widget.speech.status == OfflineSpeechStatus.paused
                        ? Icons.play_arrow
                        : Icons.pause,
                  ),
                  label: Text(
                    widget.speech.status == OfflineSpeechStatus.paused
                        ? 'Resume voice'
                        : 'Pause voice',
                  ),
                ),
              if (widget.speech.status == OfflineSpeechStatus.speaking ||
                  widget.speech.status == OfflineSpeechStatus.paused)
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
