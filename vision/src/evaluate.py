# Gavin and Aditya - Measure localization and CPU latency on held-out images.
import argparse
import json
import time
from pathlib import Path

import torch
from torchvision.ops import box_iou
from train import ComponentDataset, build_model
from validate_dataset import validate_dataset


def average_precision(recall, precision):
    points = [(0.0, 0.0)] + list(zip(recall, precision)) + [(1.0, 0.0)]
    for i in range(len(points) - 2, -1, -1):
        points[i] = (points[i][0], max(points[i][1], points[i + 1][1]))
    return sum(
        (points[i][0] - points[i - 1][0]) * points[i][1] for i in range(1, len(points))
    )


def score_predictions(predictions, targets, classes, threshold=0.5):
    report = {}
    for class_id, name in enumerate(classes[1:], 1):
        truth = {
            i: target["boxes"][target["labels"] == class_id]
            for i, target in enumerate(targets)
        }
        total = sum(len(boxes) for boxes in truth.values())
        ranked = []
        for image_id, prediction in enumerate(predictions):
            for box, score, label in zip(
                prediction["boxes"], prediction["scores"], prediction["labels"]
            ):
                if int(label) == class_id:
                    ranked.append((float(score), image_id, box))
        matched, recall, precision = set(), [], []
        tp = fp = selected_tp = selected_fp = 0
        for score, image_id, box in sorted(ranked, key=lambda row: -row[0]):
            candidates = truth[image_id]
            overlaps = box_iou(box[None], candidates)[0] if len(candidates) else []
            available = [
                (float(iou), index)
                for index, iou in enumerate(overlaps)
                if (image_id, index) not in matched
            ]
            best = max(available, default=(0, -1))
            hit = best[0] >= 0.5
            if hit:
                matched.add((image_id, best[1]))
            tp += int(hit)
            fp += int(not hit)
            recall.append(tp / total if total else 0)
            precision.append(tp / (tp + fp))
            if score >= threshold:
                selected_tp += int(hit)
                selected_fp += int(not hit)
        report[name] = {
            "ground_truth": total,
            "ap50": average_precision(recall, precision) if total else None,
            "true_positive": selected_tp,
            "false_positive": selected_fp,
            "false_negative": total - selected_tp,
            "precision": selected_tp / max(1, selected_tp + selected_fp),
            "recall": selected_tp / total if total else None,
        }
    aps = [row["ap50"] for row in report.values() if row["ap50"] is not None]
    return {
        "map50": sum(aps) / len(aps) if aps else None,
        "threshold": threshold,
        "iou": 0.5,
        "classes": report,
    }


def main():
    parser = argparse.ArgumentParser(description="Evaluate local held-out COCO boxes.")
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--images", type=Path, required=True)
    parser.add_argument("--provenance", type=Path, required=True)
    parser.add_argument(
        "--split", choices=("train", "validation", "test"), default="test"
    )
    parser.add_argument("--threshold", type=float, default=0.5)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 0 <= args.threshold <= 1:
        parser.error("Threshold must be between zero and one.")
    validate_dataset(args.labels, args.images, args.provenance)
    dataset = ComponentDataset(
        json.loads(args.labels.read_text()),
        args.images,
        json.loads(args.provenance.read_text()),
        args.split,
    )
    if not len(dataset):
        parser.error("The selected split is empty.")
    checkpoint = torch.load(args.checkpoint, map_location="cpu", weights_only=True)
    if checkpoint["classes"] != dataset.classes:
        parser.error("Checkpoint classes do not match the annotations.")
    torch.set_num_threads(4)
    model = build_model(dataset.classes)
    model.load_state_dict(checkpoint["state_dict"])
    model.eval()
    predictions, targets, elapsed = [], [], []
    with torch.inference_mode():
        model([dataset[0][0]])
        for image, target in dataset:
            start = time.perf_counter()
            predictions.append(model([image])[0])
            elapsed.append((time.perf_counter() - start) * 1000)
            targets.append(target)
    report = score_predictions(predictions, targets, dataset.classes, args.threshold)
    report.update(
        split=args.split,
        images=len(dataset),
        mean_cpu_inference_ms=sum(elapsed) / len(elapsed),
        note="Small source-group split; not real-phone or repair-safety validation.",
    )
    args.output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
