/// <reference types="node" />
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  emptyWorkspace,
  parseWorkspace,
  toggleStep,
  updateProcedure,
} from "./workspace.ts";
import type { Workspace } from "./workspace.ts";

function fixture(): Workspace {
  const step = {
    id: "s1",
    title: "Inspect",
    instructions: "Check the label.",
    referenceImageUrl: "",
    estimatedMinutes: 1,
  };
  return {
    version: 1,
    activeProcedureId: "p1",
    completed: {},
    procedures: [
      {
        id: "p1",
        name: "First",
        equipment: "Unit",
        description: "",
        steps: [step],
      },
      {
        id: "p2",
        name: "Second",
        equipment: "Unit",
        description: "",
        steps: [step],
      },
    ],
  };
}
test("empty workspace has no fabricated procedures or confirmations", () => {
  assert.deepEqual(
    parseWorkspace(JSON.stringify(emptyWorkspace())),
    emptyWorkspace(),
  );
});
test("progress is isolated by procedure, including shared step IDs", () => {
  const state = toggleStep(fixture(), "s1");
  const other = { ...state, activeProcedureId: "p2" };
  assert.deepEqual(other.completed.p1, ["s1"]);
  assert.equal(other.completed.p2, undefined);
  assert.deepEqual(toggleStep(state, "s1").completed.p1, []);
  assert.equal(toggleStep(state, "missing"), state);
});
test("editing an instruction invalidates its prior confirmation", () => {
  const state = toggleStep(fixture(), "s1");
  const procedure = state.procedures[0];
  const next = updateProcedure(state, {
    ...procedure,
    steps: [{ ...procedure.steps[0], instructions: "Changed action." }],
  });
  assert.deepEqual(next.completed.p1, []);
  assert.deepEqual(
    updateProcedure(state, { ...procedure, name: "Renamed" }).completed.p1,
    ["s1"],
  );
});
test("reload restores only valid unique confirmations and selected procedure", () => {
  const state = fixture();
  state.completed.p1 = ["s1", "s1", "deleted"];
  state.activeProcedureId = "missing";
  const restored = parseWorkspace(JSON.stringify(state));
  assert.deepEqual(restored.completed.p1, ["s1"]);
  assert.equal(restored.activeProcedureId, "p1");
});
test("rejects malformed, duplicate, excessive and prototype-bearing records", () => {
  assert.throws(() => parseWorkspace("{"));
  assert.throws(() => parseWorkspace(JSON.stringify({ version: 2 })));
  const state = fixture();
  state.procedures[1].id = "p1";
  assert.throws(() => parseWorkspace(JSON.stringify(state)));
  state.procedures[1].id = "__proto__";
  assert.throws(() => parseWorkspace(JSON.stringify(state)));
  assert.throws(() => parseWorkspace(" ".repeat(1000001)));
});
