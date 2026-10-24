// Gavin - Step titles and instructions for ApolLens walkthroughs.
final class InspectionStep {
  const InspectionStep(this.title, this.detail);

  final String title;
  final String detail;
}

// Demo steps until we have the purifier's model-specific procedure.
const purifierInspection = <InspectionStep>[
  InspectionStep(
    'Identify equipment',
    'Check the model label and match it to the purifier manual.',
  ),
  InspectionStep(
    'Inspect exterior',
    'Look over the housing for visible damage or blocked vents.',
  ),
  InspectionStep(
    'Review observations',
    'Review any visible issues and flag what needs a closer look.',
  ),
];
