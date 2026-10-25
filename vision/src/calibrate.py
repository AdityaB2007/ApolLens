# Gavin - Choose confidence on calibration images without consulting the test split.
import argparse
import json
import math
from pathlib import Path

import torch
from evaluate import score_predictions
from train import ComponentDataset, model_from_checkpoint
from validate_dataset import validate_dataset


def operating_points(predictions, targets, classes, minimum_precision=0.9):
    if not math.isfinite(minimum_precision) or not 0 < minimum_precision <= 1:
        raise ValueError("Minimum precision must be in (0, 1].")
    reports = [
        score_predictions(predictions, targets, classes, value / 100)
        for value in range(5, 100, 5)
    ]
    points = {}
    for name in classes[1:]:
        rows = [
            {"threshold": report["threshold"], **report["classes"][name]}
            for report in reports
        ]
        eligible = [
            row
            for row in rows
            if row["true_positive"] and row["precision"] >= minimum_precision
        ]
        selected = max(
            eligible,
            key=lambda row: (row["recall"], row["precision"], -row["threshold"]),
            default=None,
        )
        best_f1 = max(
            rows,
            key=lambda row: (
                2
                * row["true_positive"]
                / max(
                    1,
                    2 * row["true_positive"]
                    + row["false_positive"]
                    + row["false_negative"],
                )
            ),
        )
        points[name] = {
            "threshold": selected["threshold"] if selected else None,
            "calibration": selected,
            "best_f1_diagnostic": best_f1,
            "precision_target_met": selected is not None,
            "recall_target_met": selected is not None and selected["recall"] >= 0.9,
        }
    return points


def main():
    parser = argparse.ArgumentParser(description="Calibrate on validation images only.")
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--images", type=Path, required=True)
    parser.add_argument("--provenance", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Choose a new calibration report path.")
    validate_dataset(args.labels, args.images, args.provenance)
    checkpoint = torch.load(args.checkpoint, map_location="cpu", weights_only=True)
    dataset = ComponentDataset(
        json.loads(args.labels.read_text()),
        args.images,
        json.loads(args.provenance.read_text()),
        "validation",
        image_size=checkpoint.get("image_size", 320),
        letterboxed=checkpoint.get("letterbox", False),
    )
    if not len(dataset) or dataset.classes != checkpoint["classes"]:
        parser.error("Calibration images and matching classes are required.")
    torch.set_num_threads(4)
    model = model_from_checkpoint(checkpoint).eval()
    predictions, targets = [], []
    with torch.inference_mode():
        for image, target in dataset:
            predictions.append(model([image])[0])
            targets.append(target)
    report = score_predictions(predictions, targets, dataset.classes)
    report.update(
        checkpoint=str(args.checkpoint),
        epoch=checkpoint["epochs"],
        split="validation",
        images=len(dataset),
        operating_points=operating_points(predictions, targets, dataset.classes),
        note="Calibration results are not independent test or phone-camera accuracy.",
    )
    args.output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
