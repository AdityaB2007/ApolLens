// Aditya: Connect the React dashboard to Indi's APIs and shared session updates.

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

export type Inspection = {
  id: string;
  timestamp: string;
  label: string;
  message: string;
  confidence: number | null;
  reviewStatus: "pending" | "confirmed" | "flagged";
};

export const initialProcedures: Procedure[] = [
  {
    id: "hepa-filter-maintenance",
    name: "HEPA Filter Maintenance",
    equipment: "HEPA air purifier",
    description:
      "Demonstration procedure for inspecting and servicing the purifier filter.",
    steps: [
      {
        id: "step-1",
        title: "Prepare the purifier",
        instructions:
          "Follow the manufacturer's manual. Make sure the purifier is switched off and safely prepared before opening it.",
        referenceImageUrl: "",
        estimatedMinutes: 2,
      },
      {
        id: "step-2",
        title: "Locate the cover",
        instructions:
          "Identify the purifier cover and locate the points used to open it.",
        referenceImageUrl: "",
        estimatedMinutes: 1,
      },
      {
        id: "step-3",
        title: "Open the cover",
        instructions:
          "Open the cover according to the manufacturer's instructions. Avoid forcing any clips or fasteners.",
        referenceImageUrl: "",
        estimatedMinutes: 2,
      },
      {
        id: "step-4",
        title: "Inspect the filter",
        instructions:
          "Locate the filter and inspect its visible condition. Follow the manual for removal or replacement requirements.",
        referenceImageUrl: "",
        estimatedMinutes: 3,
      },
      {
        id: "step-5",
        title: "Reassemble the purifier",
        instructions:
          "Reinstall the filter and close the cover according to the manufacturer's instructions.",
        referenceImageUrl: "",
        estimatedMinutes: 3,
      },
    ],
  },
];

export const initialInspections: Inspection[] = [
  {
    id: "observation-1",
    timestamp: "10:42:08",
    label: "cover",
    message: "Cover detected in the camera frame.",
    confidence: 0.96,
    reviewStatus: "pending",
  },
  {
    id: "observation-2",
    timestamp: "10:42:12",
    label: "filter",
    message: "Filter detected in the camera frame.",
    confidence: 0.91,
    reviewStatus: "pending",
  },
  {
    id: "observation-3",
    timestamp: "10:42:16",
    label: "filter_slot",
    message: "Filter slot detected in the camera frame.",
    confidence: 0.88,
    reviewStatus: "confirmed",
  },
];
