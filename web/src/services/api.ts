// Aditya: Shared procedure draft types for the React workspace.

export type ProcedureStep = {
  id: string;
  title: string;
  instructions: string;
  referenceImageUrl: string;
  estimatedMinutes: number;
};

export type Procedure = {
  id: string;
  name: string;
  equipment: string;
  description: string;
  steps: ProcedureStep[];
};
