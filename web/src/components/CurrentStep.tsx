export type RepairStep = {
  id: string;
  instruction: string;
  revision: number;
  relevantComponentLabels: string[];
  referenceImageUrl?: string;
};

type CurrentStepProps = {
  step: RepairStep | null;
  stepNumber: number;
  totalSteps: number;
  isConfirmed: boolean;
  onPrevious: () => void;
  onNext: () => void;
  onConfirm: () => void;
  disabled?: boolean;
};

function CurrentStep({
  step,
  stepNumber,
  totalSteps,
  isConfirmed,
  onPrevious,
  onNext,
  onConfirm,
  disabled = false,
}: CurrentStepProps) {
  if (!step) {
    return (
      <section className="panel">
        <h2>Current repair step</h2>
        <p>Select a procedure with available steps to begin.</p>
      </section>
    );
  }

  return (
    <section className="panel" aria-labelledby="current-step-heading">
      <div className="panel-header">
        <h2 id="current-step-heading">Current repair step</h2>
        <span>
          Step {stepNumber} of {totalSteps}
        </span>
      </div>

      <p>{step.instruction}</p>

      {step.relevantComponentLabels.length > 0 && (
        <div>
          <h3>Relevant components</h3>
          <ul>
            {step.relevantComponentLabels.map((label) => (
              <li key={label}>{label.replaceAll("_", " ")}</li>
            ))}
          </ul>
        </div>
      )}

      {step.referenceImageUrl && (
        <figure>
          <img
            src={step.referenceImageUrl}
            alt="Reference for the current repair step"
            onError={(event) => {
              event.currentTarget.hidden = true;
            }}
          />
          <figcaption>Procedure reference image</figcaption>
        </figure>
      )}

      <p role="status">
        {isConfirmed
          ? "You confirmed this step."
          : "This step has not been confirmed."}
      </p>

      <div className="step-navigation">
        <button
          type="button"
          onClick={onPrevious}
          disabled={disabled || stepNumber <= 1}
        >
          Previous
        </button>

        <button
          type="button"
          onClick={onConfirm}
          disabled={disabled || isConfirmed}
        >
          Confirm step complete
        </button>

        <button
          type="button"
          onClick={onNext}
          disabled={disabled || stepNumber >= totalSteps}
        >
          Next
        </button>
      </div>
    </section>
  );
}

export default CurrentStep;