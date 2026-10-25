// Aditya: Live repair sessions, inspection results, and progress in the React dashboard.
import InspectionFeed from "../components/InspectionFeed";
import type { Inspection, Procedure } from "../services/api";


type DashboardProps = {
  procedure: Procedure;
  procedures: Procedure[];
  activeProcedureId: string;
  onSelectProcedure: (id: string) => void;
  completedStepIds: string[];
  onToggleStep: (id: string) => void;
  inspections: Inspection[];
  onReviewInspection: (
    id: string,
    status: "confirmed" | "flagged",
  ) => void;
};


function Dashboard({
  procedure,
  procedures,
  activeProcedureId,
  onSelectProcedure,
  completedStepIds,
  onToggleStep,
  inspections,
  onReviewInspection,
}: DashboardProps) {
  const steps = procedure.steps;
  const completedCount = steps.filter((step) =>
    completedStepIds.includes(step.id),
  ).length;
  const progress =
    steps.length === 0 ? 0 : Math.round((completedCount / steps.length) * 100);


  const currentStep = steps.find(
    (step) => !completedStepIds.includes(step.id),
  );


  const pendingCount = inspections.filter(
    (inspection) => inspection.reviewStatus === "pending",
  ).length;


  return (
    <div className="page-content">
      <section className="welcome-row">
        <div>
          <p className="eyebrow">MAINTENANCE WORKSPACE</p>
          <h3>Keep every step in view.</h3>
          <p className="muted">
            Follow the procedure, review camera observations, and confirm each
            completed action.
          </p>
        </div>


        <label className="procedure-selector">
          <span>Active procedure</span>
          <select
            value={activeProcedureId}
            onChange={(event) => onSelectProcedure(event.target.value)}
          >
            {procedures.map((item) => (
              <option value={item.id} key={item.id}>
                {item.name}
              </option>
            ))}
          </select>
        </label>
      </section>


      <section className="stat-grid">
        <article className="stat-card">
          <span className="stat-label">Step progress</span>
          <strong>{progress}%</strong>
          <span className="stat-detail">
            {completedCount} of {steps.length} steps confirmed
          </span>
        </article>


        <article className="stat-card">
          <span className="stat-label">Observations</span>
          <strong>{inspections.length}</strong>
          <span className="stat-detail">Sample camera events</span>
        </article>


        <article className="stat-card">
          <span className="stat-label">Awaiting review</span>
          <strong>{pendingCount}</strong>
          <span className="stat-detail">Observations to review</span>
        </article>
      </section>


      <div className="dashboard-grid">
        <section className="panel procedure-panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">ACTIVE PROCEDURE</p>
              <h3>{procedure.name}</h3>
              <p className="muted">{procedure.equipment}</p>
            </div>
            <span className="step-count">
              {completedCount}/{steps.length}
            </span>
          </div>


          <div className="progress-track">
            <div className="progress-fill" style={{ width: `${progress}%` }} />
          </div>


          {currentStep ? (
            <div className="current-step">
              <span className="current-step-label">NEXT STEP</span>
              <h4>{currentStep.title}</h4>
              <p>{currentStep.instructions}</p>
              <span className="duration">
                Estimated time: {currentStep.estimatedMinutes} min
              </span>
            </div>
          ) : (
            <div className="completion-message">
              <span className="completion-icon">✓</span>
              <div>
                <h4>All steps confirmed</h4>
                <p>Every step in this procedure has been marked complete.</p>
              </div>
            </div>
          )}


          <div className="step-list">
            {steps.map((step, index) => {
              const isComplete = completedStepIds.includes(step.id);
              const isCurrent = currentStep?.id === step.id;


              return (
                <article
                  className={`step-row ${isCurrent ? "step-row-current" : ""}`}
                  key={step.id}
                >
                  <span
                    className={`step-number ${isComplete ? "step-number-complete" : ""}`}
                  >
                    {isComplete ? "✓" : index + 1}
                  </span>


                  <div className="step-info">
                    <strong>{step.title}</strong>
                    <span>
                      {isComplete
                        ? "Human-confirmed complete"
                        : isCurrent
                          ? "Up next"
                          : "Not yet confirmed"}
                    </span>
                  </div>


                  <button
                    className={`button button-small ${isComplete ? "button-secondary" : ""}`}
                    onClick={() => onToggleStep(step.id)}
                  >
                    {isComplete ? "Undo" : "Confirm"}
                  </button>
                </article>
              );
            })}
          </div>


          <p className="note">
            Step completion is controlled by the user. Detector observations
            do not automatically complete steps.
          </p>
        </section>


        <div className="right-column">
          <section className="panel camera-panel">
            <div className="panel-heading">
              <div>
                <p className="eyebrow">VISION SYSTEM</p>
                <h3>Camera preview</h3>
              </div>
              <span className="status status-pending">Not connected</span>
            </div>


            <div className="camera-placeholder">
              <div className="camera-symbol">◎</div>
              <strong>Camera feed will appear here</strong>
              <p>
                The Flutter app and vision service are not connected to this
                demo dashboard yet.
              </p>
            </div>


            <div className="camera-legend">
              <span><i className="legend-dot" /> Sample detections below</span>
            </div>
          </section>


          <section className="panel">
            <div className="panel-heading">
              <div>
                <p className="eyebrow">LATEST EVENTS</p>
                <h3>Inspection feed</h3>
              </div>
              <span className="step-count">{inspections.length}</span>
            </div>


            <InspectionFeed
              inspections={inspections}
              onReview={onReviewInspection}
            />
          </section>
        </div>
      </div>
    </div>
  );
}


export default Dashboard;
