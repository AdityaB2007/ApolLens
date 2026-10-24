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
    final step = purifierInspection[_stepIndex];
    return Scaffold(
      appBar: AppBar(title: const Text('HEPA inspection')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Manual walkthrough'),
          Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(step.detail),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _stepIndex == 0
                    ? null
                    : () => setState(() => _stepIndex--),
                child: const Text('Previous'),
              ),
              FilledButton(
                onPressed: _stepIndex == purifierInspection.length - 1
                    ? null
                    : () => setState(() => _stepIndex++),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
