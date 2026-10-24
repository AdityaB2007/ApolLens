export type ObservationReviewStatus = "pending" | "confirmed" | "flagged";

export type Observation = {
  id: string;
  label: string;
  confidence: number | null;
  capturedAt: string;
  frameId: number;
  reviewStatus: ObservationReviewStatus;
};

type InspectionFeedProps = {
  observations: Observation[];
  onReview: (
    observationId: string,
    status: Exclude<ObservationReviewStatus, "pending">,
  ) => void;
  disabled?: boolean;
};

function formatLabel(label: string): string {
  return label
    .split("_")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

function InspectionFeed({
  observations,
  onReview,
  disabled = false,
}: InspectionFeedProps) {
  return (
    <section className="panel" aria-labelledby="inspection-feed-heading">
      <div className="panel-header">
        <h2 id="inspection-feed-heading">Observation review</h2>
        <span>{observations.length} observations</span>
      </div>

      {observations.length === 0 ? (
        <p>No observations have been received yet.</p>
      ) : (
        <ul className="inspection-list">
          {observations.map((observation) => (
            <li className="inspection-item" key={observation.id}>
              <div className="inspection-item-header">
                <strong>{formatLabel(observation.label)}</strong>
                <span
                  className={`status status-${observation.reviewStatus}`}
                >
                  {observation.reviewStatus}
                </span>
              </div>

              <p>
                Frame {observation.frameId}
                {observation.confidence !== null &&
                  ` · ${(observation.confidence * 100).toFixed(1)}% confidence`}
              </p>

              <time dateTime={observation.capturedAt}>
                {Number.isNaN(Date.parse(observation.capturedAt))
                  ? "Time unavailable"
                  : new Date(observation.capturedAt).toLocaleString()}
              </time>

              {observation.reviewStatus === "pending" && (
                <div className="inspection-actions">
                  <button
                    type="button"
                    disabled={disabled}
                    onClick={() =>
                      onReview(observation.id, "confirmed")
                    }
                  >
                    Confirm observation
                  </button>

                  <button
                    type="button"
                    disabled={disabled}
                    onClick={() => onReview(observation.id, "flagged")}
                  >
                    Flag observation
                  </button>
                </div>
              )}
            </li>
          ))}
        </ul>
      )}

      <p className="muted">
        Reviewing an observation does not mark a repair step complete.
      </p>
    </section>
  );
}

export default InspectionFeed;