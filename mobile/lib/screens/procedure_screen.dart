// Gavin - Displays the current step in an ApolLens inspection.
import 'package:apollens/models/inspection_step.dart';
import 'package:flutter/material.dart';

class ProcedureScreen extends StatefulWidget {
  const ProcedureScreen({super.key});

  @override
  State<ProcedureScreen> createState() => _ProcedureScreenState();
}

class _ProcedureScreenState extends State<ProcedureScreen> {
  // Manual taps move the walkthrough; detections do not advance it.
  int _stepIndex = 0;

  @override
  Widget build(BuildContext context) {
    final count = laptopInspection.length;
    final complete = _stepIndex == count;
    final step = complete
        ? const InspectionStep(
            'Walkthrough complete',
            'Steps reviewed manually. Camera verification is not connected.',
          )
        : laptopInspection[_stepIndex];
    return Scaffold(
      appBar: AppBar(title: const Text('Laptop inspection')),
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
          const SizedBox(height: 24),
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
