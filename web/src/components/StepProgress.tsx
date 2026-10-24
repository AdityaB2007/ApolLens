
export type ProgressStep = {
  id: string;
  title: string;
};

type StepProgressProps = {
  steps: ProgressStep[];
  currentStepId: string | null;
  completedStepIds: ReadonlySet<string>;
  onSelectStep: (stepId: string) => void;
  disabled?: boolean;
};

function StepProgress({
  steps,
  currentStepId,
  completedStepIds,
  onSelectStep,
  disabled = false,
}: StepProgressProps) {
  const completedCount = steps.filter((step) =>
    completedStepIds.has(step.id),
  ).length;

  const progress =
    steps.length === 0 ? 0 : (completedCount / steps.length) * 100;

  return (
    <section className="panel" aria-labelledby="step-progress-heading">
      <div className="panel-header">
        <h2 id="step-progress-heading">Repair progress</h2>
        <span>
          {completedCount} of {steps.length} confirmed
        </span>
      </div>

      <progress
        value={completedCount}
        max={Math.max(steps.length, 1)}
        aria-label={`${Math.round(progress)}% of repair steps confirmed`}
      />

      {steps.length === 0 ? (
        <p>No steps are available for this procedure.</p>
      ) : (
        <ol className="step-progress-list">
          {steps.map((step, index) => {
            const completed = completedStepIds.has(step.id);
            const current = step.id === currentStepId;

            return (
              <li key={step.id}>
                <button
                  type="button"
                  className={current ? "step-button step-current" : "step-button"}
                  aria-current={current ? "step" : undefined}
                  disabled={disabled}
                  onClick={() => onSelectStep(step.id)}
                >
                  <span aria-hidden="true">
                    {completed ? "✓" : index + 1}
                  </span>
                  <span>{step.title}</span>
                  <span>
                    {completed ? "Confirmed" : current ? "Current" : "Not confirmed"}
                  </span>
                </button>
              </li>
            );
          })}
        </ol>
      )}
    </section>
  );
}

export default StepProgress;