// Gavin - Spoken guidance controls for the instruction shown in ApolLens.
import 'dart:async';

import 'package:flutter/material.dart';
import '../services/speech_controller.dart';

class InstructionAudio extends StatefulWidget {
  const InstructionAudio({super.key, required this.text, this.speech});

  final String? text;
  final SpeechController? speech;

  @override
  State<InstructionAudio> createState() => _InstructionAudioState();
}

class _InstructionAudioState extends State<InstructionAudio>
    with AutomaticKeepAliveClientMixin {
  // Scrolling past the controls must not stop the current instruction.
  @override
  bool get wantKeepAlive => true;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _readInstruction();
  }

  @override
  void didUpdateWidget(InstructionAudio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text && oldWidget.speech == widget.speech) {
      return;
    }
    unawaited(oldWidget.speech?.stop(clear: true));
    _readInstruction();
  }

  void _readInstruction() {
    final revision = ++_revision;
    // Wait for the text to appear; discard callbacks from earlier steps.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _revision || widget.text == null) return;
      unawaited(widget.speech?.speak(widget.text!));
    });
  }

  @override
  void dispose() {
    unawaited(widget.speech?.stop(clear: true));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.text == null) return const SizedBox.shrink();
    final speech = widget.speech;
    if (speech == null) {
      return const Text('Audio guidance is not connected yet.');
    }
    return ValueListenableBuilder<SpeechStatus>(
      valueListenable: speech,
      builder: (context, status, _) {
        final message = switch (status) {
          SpeechStatus.idle => 'Audio ready',
          SpeechStatus.loading => 'Preparing audio…',
          SpeechStatus.playing => 'Reading instruction',
          SpeechStatus.paused => 'Audio paused',
          SpeechStatus.muted => 'Audio off. Instructions remain on screen.',
          SpeechStatus.failed => 'Audio unavailable. You can retry.',
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(liveRegion: true, child: Text(message)),
            // Wrap keeps every control reachable with larger text.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => speech.setMuted(!speech.muted),
                  child: Text(
                    speech.muted ? 'Turn audio on' : 'Turn audio off',
                  ),
                ),
                if (!speech.muted) ...[
                  if (status == SpeechStatus.loading)
                    TextButton(
                      onPressed: speech.stop,
                      child: const Text('Cancel'),
                    )
                  else
                    TextButton(
                      onPressed: speech.replay,
                      child: Text(
                        status == SpeechStatus.failed
                            ? 'Retry audio'
                            : 'Replay',
                      ),
                    ),
                  if (status == SpeechStatus.playing ||
                      status == SpeechStatus.paused)
                    TextButton(
                      onPressed: () =>
                          speech.setPaused(status == SpeechStatus.playing),
                      child: Text(
                        status == SpeechStatus.paused ? 'Resume' : 'Pause',
                      ),
                    ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
