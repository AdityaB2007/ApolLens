import type { Procedure } from "./api.ts";

export type Workspace = {
  version: 1;
  procedures: Procedure[];
  activeProcedureId: string | null;
  completed: Record<string, string[]>;
};
export const storageKey = "apollens.workspace.v1";
export function emptyWorkspace(): Workspace {
  return { version: 1, procedures: [], activeProcedureId: null, completed: {} };
}
const record = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const text = (value: unknown): value is string =>
  typeof value === "string" && value.length <= 10000;
const id = (value: unknown): value is string =>
  text(value) &&
  value.length > 0 &&
  value.length < 200 &&
  !["__proto__", "constructor", "prototype"].includes(value);

export function parseWorkspace(raw: string): Workspace {
  if (raw.length > 1000000) throw new Error("Workspace is too large.");
  const data: unknown = JSON.parse(raw);
  if (
    !record(data) ||
    data.version !== 1 ||
    !Array.isArray(data.procedures) ||
    data.procedures.length > 100 ||
    !record(data.completed)
  ) {
    throw new Error("Saved workspace has an unsupported format.");
  }
  const procedures: Procedure[] = [];
  const ids = new Set<string>();
  for (const item of data.procedures) {
    if (
      !record(item) ||
      !id(item.id) ||
      ids.has(item.id) ||
      !text(item.name) ||
      !text(item.equipment) ||
      !text(item.description) ||
      !Array.isArray(item.steps) ||
      item.steps.length > 200
    ) {
      throw new Error("Saved procedure is invalid.");
    }
    ids.add(item.id);
    const stepIds = new Set<string>();
    const steps = item.steps.map((step: unknown) => {
      if (
        !record(step) ||
        !id(step.id) ||
        stepIds.has(step.id) ||
        !text(step.title) ||
        !text(step.instructions) ||
        !text(step.referenceImageUrl) ||
        typeof step.estimatedMinutes !== "number" ||
        !Number.isFinite(step.estimatedMinutes) ||
        step.estimatedMinutes < 1
      ) {
        throw new Error("Saved step is invalid.");
      }
      stepIds.add(step.id);
      return {
        id: step.id,
        title: step.title,
        instructions: step.instructions,
        referenceImageUrl: step.referenceImageUrl,
        estimatedMinutes: step.estimatedMinutes,
      };
    });
    procedures.push({
      id: item.id,
      name: item.name,
      equipment: item.equipment,
      description: item.description,
      steps,
    });
  }
  const completed: Record<string, string[]> = {};
  for (const procedure of procedures) {
    const saved = data.completed[procedure.id];
    const validIds = new Set(procedure.steps.map((step) => step.id));
    completed[procedure.id] = Array.isArray(saved)
      ? [
          ...new Set(
            saved.filter(
              (value): value is string =>
                typeof value === "string" && validIds.has(value),
            ),
          ),
        ]
      : [];
  }
  const activeProcedureId =
    typeof data.activeProcedureId === "string" &&
    ids.has(data.activeProcedureId)
      ? data.activeProcedureId
      : (procedures[0]?.id ?? null);
  return { version: 1, procedures, activeProcedureId, completed };
}

export function updateProcedure(state: Workspace, next: Procedure): Workspace {
  const previous = state.procedures.find((item) => item.id === next.id);
  if (!previous) return state;
  const unchanged = new Set(
    next.steps
      .filter((step) =>
        previous.steps.some(
          (old) =>
            old.id === step.id && JSON.stringify(old) === JSON.stringify(step),
        ),
      )
      .map((step) => step.id),
  );
  return {
    ...state,
    procedures: state.procedures.map((item) =>
      item.id === next.id ? next : item,
    ),
    completed: {
      ...state.completed,
      [next.id]: (state.completed[next.id] ?? []).filter((key) =>
        unchanged.has(key),
      ),
    },
  };
}

export function toggleStep(state: Workspace, stepId: string): Workspace {
  const procedure = state.procedures.find(
    (item) => item.id === state.activeProcedureId,
  );
  if (!procedure?.steps.some((step) => step.id === stepId)) return state;
  const completed = new Set(state.completed[procedure.id] ?? []);
  if (completed.has(stepId)) completed.delete(stepId);
  else completed.add(stepId);
  return {
    ...state,
    completed: { ...state.completed, [procedure.id]: [...completed] },
  };
}
