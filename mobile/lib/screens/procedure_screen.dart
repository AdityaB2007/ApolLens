// Gavin - Displays the current step in an ApolLens inspection.
import 'package:apollens/models/inspection_step.dart';
import 'package:flutter/material.dart';

class ProcedureScreen extends StatelessWidget {
  const ProcedureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final step = purifierInspection.first;
    return Scaffold(
      appBar: AppBar(title: const Text('HEPA inspection')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Manual walkthrough'),
          Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(step.detail),
        ],
      ),
    );
  }
}
