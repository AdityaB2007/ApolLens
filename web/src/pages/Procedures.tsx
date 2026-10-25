// Aditya: Procedure editing and reference image management in React.
import type { Procedure, ProcedureStep } from "../services/api";

type ProceduresProps = {
  procedures: Procedure[];
  activeProcedureId: string;
  onSelectProcedure: (id: string) => void;
  onUpdateProcedure: (procedure: Procedure) => void;
  onAddProcedure: () => void;
};

function Procedures({
  procedures,
  activeProcedureId,
  onSelectProcedure,
  onUpdateProcedure,
  onAddProcedure,
}: ProceduresProps) {
  const selected = procedures.find((item) => item.id === activeProcedureId);

  if (!selected) {
    return (
      <div className="page-content">
        <section className="panel">
          <h3>No procedure selected</h3>
          <button className="button" onClick={onAddProcedure}>
            Create procedure
          </button>
        </section>
      </div>
    );
  }

  const procedure = selected;

  function updateDetails(
    changes: Partial<Pick<Procedure, "name" | "equipment" | "description">>,
  ) {
    onUpdateProcedure({ ...procedure, ...changes });
  }

  function updateStep(stepId: string, changes: Partial<ProcedureStep>) {
    onUpdateProcedure({
      ...procedure,
      steps: procedure.steps.map((step) =>
        step.id === stepId ? { ...step, ...changes } : step,
      ),
    });
  }

  function addStep() {
    const newStep: ProcedureStep = {
      id: crypto.randomUUID(),
      title: "New maintenance step",
      instructions: "Add the instructions for this step.",
      referenceImageUrl: "",
      estimatedMinutes: 1,
    };

    onUpdateProcedure({
      ...procedure,
      steps: [...procedure.steps, newStep],
    });
  }

  function removeStep(stepId: string) {
    onUpdateProcedure({
      ...procedure,
      steps: procedure.steps.filter((step) => step.id !== stepId),
    });
  }

  function moveStep(index: number, direction: -1 | 1) {
    const destination = index + direction;

    if (destination < 0 || destination >= procedure.steps.length) return;

    const updatedSteps = [...procedure.steps];
    [updatedSteps[index], updatedSteps[destination]] = [
      updatedSteps[destination],
      updatedSteps[index],
    ];

    onUpdateProcedure({ ...procedure, steps: updatedSteps });
  }

  return (
    <div className="page-content">
      <section className="welcome-row">
        <div>
          <p className="eyebrow">PROCEDURE MANAGEMENT</p>
          <h3>Your procedure drafts</h3>
          <p className="muted">
            Edit the instructions and reference images used to guide a session.
          </p>
        </div>

        <button className="button" onClick={onAddProcedure}>
          + New procedure
        </button>
      </section>

      <div className="editor-layout">
        <aside className="panel procedure-library">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">LIBRARY</p>
              <h3>Procedures</h3>
            </div>
            <span className="step-count">{procedures.length}</span>
          </div>

          {procedures.map((item) => (
            <button
              className={`library-item ${item.id === activeProcedureId ? "library-item-active" : ""}`}
              key={item.id}
              onClick={() => onSelectProcedure(item.id)}
            >
              <strong>{item.name}</strong>
              <span>{item.equipment}</span>
              <small>
                {item.steps.length} {item.steps.length === 1 ? "step" : "steps"}
              </small>
            </button>
          ))}
        </aside>

        <section className="panel editor-panel">
          <div className="panel-heading editor-heading">
            <div>
              <p className="eyebrow">EDIT PROCEDURE</p>
              <h3>Procedure details</h3>
            </div>
            <span className="status status-pending">Local draft</span>
          </div>

          <div className="form-field">
            <label htmlFor="procedure-name">Procedure name</label>
            <input
              id="procedure-name"
              value={procedure.name}
              onChange={(event) => updateDetails({ name: event.target.value })}
              placeholder="Procedure name"
            />
          </div>

          <div className="form-field">
            <label htmlFor="procedure-equipment">Equipment</label>
            <input
              id="procedure-equipment"
              value={procedure.equipment}
              onChange={(event) =>
                updateDetails({ equipment: event.target.value })
              }
              placeholder="Equipment name"
            />
          </div>

          <div className="form-field">
            <label htmlFor="procedure-description">Description</label>
            <textarea
              id="procedure-description"
              value={procedure.description}
              onChange={(event) =>
                updateDetails({ description: event.target.value })
              }
              rows={3}
              placeholder="What does this procedure cover?"
            />
          </div>

          <div className="steps-heading">
            <div>
              <p className="eyebrow">WORKFLOW</p>
              <h3>Procedure steps ({procedure.steps.length})</h3>
            </div>
            <button className="button button-secondary" onClick={addStep}>
              + Add step
            </button>
          </div>

          {procedure.steps.map((step, index) => (
            <article className="editor-step" key={step.id}>
              <div className="editor-step-heading">
                <span className="step-number">{index + 1}</span>
                <strong>Step {index + 1}</strong>
                <div className="step-reorder">
                  <button
                    aria-label={`Move step ${index + 1} up`}
                    title="Move up"
                    disabled={index === 0}
                    onClick={() => moveStep(index, -1)}
                  >
                    ↑
                  </button>
                  <button
                    aria-label={`Move step ${index + 1} down`}
                    title="Move down"
                    disabled={index === procedure.steps.length - 1}
                    onClick={() => moveStep(index, 1)}
                  >
                    ↓
                  </button>
                </div>
                <button
                  className="text-button danger-text"
                  onClick={() => removeStep(step.id)}
                >
                  Remove
                </button>
              </div>

              <div className="form-field">
                <label htmlFor={`${step.id}-title`}>Step title</label>
                <input
                  id={`${step.id}-title`}
                  value={step.title}
                  onChange={(event) =>
                    updateStep(step.id, { title: event.target.value })
                  }
                />
              </div>

              <div className="form-field">
                <label htmlFor={`${step.id}-instructions`}>Instructions</label>
                <textarea
                  id={`${step.id}-instructions`}
                  value={step.instructions}
                  onChange={(event) =>
                    updateStep(step.id, { instructions: event.target.value })
                  }
                  rows={3}
                />
              </div>

              <div className="form-field">
                <label htmlFor={`${step.id}-image`}>
                  Reference image URL (optional)
                </label>
                <input
                  id={`${step.id}-image`}
                  type="url"
                  value={step.referenceImageUrl}
                  onChange={(event) =>
                    updateStep(step.id, {
                      referenceImageUrl: event.target.value,
                    })
                  }
                  placeholder="https://example.com/reference-image.jpg"
                />
                {step.referenceImageUrl && (
                  <div className="reference-preview">
                    <img
                      src={step.referenceImageUrl}
                      alt={`Reference for ${step.title}`}
                    />
                  </div>
                )}
              </div>

              <div className="form-field compact-field">
                <label htmlFor={`${step.id}-duration`}>
                  Estimated time (minutes)
                </label>
                <input
                  id={`${step.id}-duration`}
                  type="number"
                  min={1}
                  value={step.estimatedMinutes}
                  onChange={(event) =>
                    updateStep(step.id, {
                      estimatedMinutes: Math.max(
                        1,
                        Number(event.target.value) || 1,
                      ),
                    })
                  }
                />
              </div>
            </article>
          ))}

          {procedure.steps.length === 0 && (
            <p className="empty-state">
              This procedure has no steps yet. Add one to get started.
            </p>
          )}

          <p className="note">
            Drafts are saved in this browser. They are not synchronized with the
            phone or a server.
          </p>
        </section>
      </div>
    </div>
  );
}

export default Procedures;
