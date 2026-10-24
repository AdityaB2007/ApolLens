// Gavin - Displays repair steps supplied after item recognition.
import 'package:apollens/models/inspection_step.dart';
import 'package:apollens/screens/camera_screen.dart';
import 'package:apollens/screens/home_screen.dart';
import 'package:flutter/material.dart';
import '../services/speech_controller.dart';
import '../widgets/instruction_audio.dart';

class ProcedureScreen extends StatefulWidget {
  const ProcedureScreen({super.key, required this.steps, this.speech});

  final List<InspectionStep> steps;
  final SpeechController? speech;

  @override
  State<ProcedureScreen> createState() => _ProcedureScreenState();
}

class _ProcedureScreenState extends State<ProcedureScreen> {
  // Manual taps move the walkthrough; detections do not advance it.
  int _stepIndex = 0;

  @override
  void didUpdateWidget(ProcedureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps != widget.steps) _stepIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return HomeScreen(speech: widget.speech);
    final count = widget.steps.length;
    final complete = _stepIndex == count;
    final step = complete
        ? const InspectionStep(
            'Walkthrough complete',
            'Steps reviewed manually. Camera verification is not connected.',
          )
        : widget.steps[_stepIndex];
    return Scaffold(
      appBar: AppBar(title: const Text('Repair guidance')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Manual walkthrough'),
          Text(
            complete
                ? 'All $count steps reviewed'
                : 'Step ${_stepIndex + 1} of $count',
          ),
          const SizedBox(height: 12),
          // Progress counts reviewed steps, not the step currently open.
          LinearProgressIndicator(value: _stepIndex / count),
          const SizedBox(height: 16),
          InstructionAudio(
            speech: widget.speech,
            text: complete ? null : '${step.title}\n\n${step.detail}',
          ),
          const SizedBox(height: 24),
          if (!complete) ...[
            // Leave room for the full preview above the written instruction.
            const Card(
              child: SizedBox(
                height: 240,
                child: Center(child: CameraScreen()),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(step.detail),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _stepIndex == 0 || complete
                    ? null
                    : () => setState(() {
                          _stepIndex = (_stepIndex - 1).clamp(0, count);
                        }),
                child: const Text('Previous'),
              ),
              FilledButton(
                onPressed: () => setState(() {
                  _stepIndex = _stepIndex == count ? 0 : _stepIndex + 1;
                }),
                child: Text(
                  complete
                      ? 'Start again'
                      : (_stepIndex == count - 1 ? 'Finish' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
