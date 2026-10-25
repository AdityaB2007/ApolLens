import { useState } from "react";
import Dashboard from "./pages/Dashboard";
import Procedures from "./pages/Procedures";
import {
  emptyWorkspace,
  parseWorkspace,
  storageKey,
  toggleStep,
  updateProcedure,
} from "./services/workspace";
import type { Workspace } from "./services/workspace";

function restore() {
  try {
    const raw = localStorage.getItem(storageKey);
    return { data: raw ? parseWorkspace(raw) : emptyWorkspace(), error: "" };
  } catch {
    return {
      data: emptyWorkspace(),
      error:
        "Saved workspace could not be read. New edits will start a fresh local workspace.",
    };
  }
}

export default function App() {
  const [loaded] = useState(restore);
  const [workspace, setWorkspace] = useState(loaded.data);
  const [error, setError] = useState(loaded.error);
  const [page, setPage] = useState<"session" | "procedures">("session");
  const active = workspace.procedures.find(
    (item) => item.id === workspace.activeProcedureId,
  );

  function commit(next: Workspace) {
    try {
      next = parseWorkspace(JSON.stringify(next));
    } catch {
      setError(
        "This workspace has reached its size limit. Shorten the draft before continuing.",
      );
      return;
    }
    setWorkspace(next);
    try {
      localStorage.setItem(storageKey, JSON.stringify(next));
      setError("");
    } catch {
      setError(
        "Browser storage is unavailable. Changes remain in this tab until you close it.",
      );
    }
  }
  function select(id: string) {
    if (workspace.procedures.some((item) => item.id === id)) {
      commit({ ...workspace, activeProcedureId: id });
    }
  }
  function addProcedure() {
    const procedure = {
      id: crypto.randomUUID(),
      name: "Untitled procedure",
      equipment: "",
      description: "",
      steps: [],
    };
    commit({
      ...workspace,
      activeProcedureId: procedure.id,
      procedures: [...workspace.procedures, procedure],
    });
    setPage("procedures");
  }

  return (
    <div className="app-shell">
      <header className="app-header">
        <a className="brand" href="#main">
          ApolLens<span>FIELD WORKSPACE</span>
        </a>
        <nav aria-label="Workspace">
          <button
            aria-current={page === "session" ? "page" : undefined}
            onClick={() => setPage("session")}
          >
            Session
          </button>
          <button
            aria-current={page === "procedures" ? "page" : undefined}
            onClick={() => setPage("procedures")}
          >
            Procedures
          </button>
        </nav>
        <span className="local-status">On this device</span>
      </header>
      <main id="main">
        {error && (
          <p className="storage-error" role="alert">
            {error}
          </p>
        )}
        {page === "procedures" ? (
          <Procedures
            procedures={workspace.procedures}
            activeProcedureId={workspace.activeProcedureId ?? ""}
            onSelectProcedure={select}
            onAddProcedure={addProcedure}
            onUpdateProcedure={(next) =>
              commit(updateProcedure(workspace, next))
            }
          />
        ) : active ? (
          <Dashboard
            procedure={active}
            procedures={workspace.procedures}
            activeProcedureId={active.id}
            onSelectProcedure={select}
            completedStepIds={workspace.completed[active.id] ?? []}
            onToggleStep={(id) => commit(toggleStep(workspace, id))}
            inspections={[]}
            onReviewInspection={() => {}}
          />
        ) : (
          <section className="welcome-empty">
            <p className="eyebrow">APOLLENS / LOCAL WORKSPACE</p>
            <h1>
              Keep your work
              <br />
              within reach.
            </h1>
            <p>
              Draft procedures and track your progress here.
              <br />
              Use the phone app for live vision and spoken guidance.
            </p>
            <button className="button" onClick={addProcedure}>
              Create a procedure
            </button>
            <span className="muted">
              Stored in this browser. No account required.
            </span>
          </section>
        )}
      </main>
      <footer>Local drafts · Phone sessions are not synchronized</footer>
    </div>
  );
}
