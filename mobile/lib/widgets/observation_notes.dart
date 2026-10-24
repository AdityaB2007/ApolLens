// Gavin - Review notes stay separate from ApolLens step confirmations.
import 'package:flutter/material.dart';

class ObservationNotes extends StatefulWidget {
  const ObservationNotes(
      {super.key,
      required this.observations,
      required this.onAdd,
      required this.onDismiss});
  final Map<String, String> observations;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onDismiss;

  @override
  State<ObservationNotes> createState() => _ObservationNotesState();
}

class _ObservationNotesState extends State<ObservationNotes> {
  final _draft = TextEditingController();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _add() {
    final text = _draft.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    setState(_draft.clear);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Unresolved observations (${widget.observations.length})',
          style: Theme.of(context).textTheme.titleMedium),
      const Text('Notes do not confirm steps or verify a repair.'),
      if (widget.observations.isEmpty)
        const Text('No unresolved observations recorded.'),
      for (final entry in widget.observations.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText(entry.value),
            TextButton(
                onPressed: () => widget.onDismiss(entry.key),
                child: const Text('Dismiss note')),
          ]),
        ),
      TextField(
        controller: _draft,
        minLines: 1,
        maxLines: 3,
        maxLength: 1000,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
            labelText: 'Add an observation',
            hintText: 'Write what you noticed'),
      ),
      TextButton(
          onPressed: _draft.text.trim().isEmpty ? null : _add,
          child: const Text('Add note')),
    ]);
  }
}
