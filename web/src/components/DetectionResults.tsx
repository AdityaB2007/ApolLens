export type Detection = {
  label: string;
  confidence: number;
  box: [number, number, number, number];
};

export type DetectionResponse = {
  session_id: string;
  frame_id: number;
  captured_at_ms: number;
  detections: Detection[];
};

type DetectionResultsProps = {
  response: DetectionResponse | null;
  status: "idle" | "loading" | "ready" | "error";
  errorMessage?: string;
};

function formatLabel(label: string): string {
  return label
    .split("_")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

function DetectionResults({
  response,
  status,
  errorMessage,
}: DetectionResultsProps) {
  if (status === "loading") {
    return (
      <section className="panel" aria-live="polite">
        <h2>Camera observations</h2>
        <p>Processing the latest camera frame…</p>
      </section>
    );
  }

  if (status === "error") {
    return (
      <section className="panel" role="alert">
        <h2>Camera observations</h2>
        <p>
          {errorMessage ||
            "Detection results are currently unavailable."}
        </p>
      </section>
    );
  }

  if (status === "idle" || response === null) {
    return (
      <section className="panel" aria-live="polite">
        <h2>Camera observations</h2>
        <p>Waiting for detection results.</p>
      </section>
    );
  }

  return (
    <section className="panel" aria-live="polite">
      <h2>Camera observations</h2>

      <p>
        Frame {response.frame_id} ·{" "}
        {new Date(response.captured_at_ms).toLocaleTimeString()}
      </p>

      {response.detections.length === 0 ? (
        <p>
          No components were detected in this frame. This does not
          necessarily mean a component is absent; the view may be
          blocked or the detector may have missed it.
        </p>
      ) : (
        <ul className="detection-list">
          {response.detections.map((detection, index) => (
            <li key={`${response.frame_id}-${detection.label}-${index}`}>
              <strong>{formatLabel(detection.label)}</strong>
              <span>
                {" "}
                · {(detection.confidence * 100).toFixed(1)}% confidence
              </span>
            </li>
          ))}
        </ul>
      )}

      <p className="muted">
        Detection confidence describes the model's prediction, not
        whether a repair step is complete.
      </p>
    </section>
  );
}

export default DetectionResults;