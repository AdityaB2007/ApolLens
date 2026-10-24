// Gavin - Step titles and instructions for ApolLens walkthroughs.
final class InspectionStep {
  const InspectionStep(this.title, this.detail);

  final String title;
  final String detail;
}

// Demo steps until we choose the laptop model and repair procedure.
const laptopInspection = <InspectionStep>[
  InspectionStep(
    'Identify laptop',
    'Match the laptop model to its service manual.',
  ),
  InspectionStep(
    'Inspect exterior',
    'Check the case, ports, and hinges for visible damage.',
  ),
  InspectionStep(
    'Review observations',
    'Review any visible issues and flag what needs a closer look.',
  ),
];
