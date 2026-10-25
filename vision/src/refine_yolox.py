# Gavin - Refine local component weights using reviewed training images only.
import argparse
import hashlib
import json
import math
import random
from pathlib import Path

import torch
from torch.utils.data import DataLoader, WeightedRandomSampler
from train import ComponentDataset, sampling_weights
from validate_dataset import validate_dataset
from yolox_model import YOLOXDetector


def main():
    from yolox.utils import ModelEMA

    parser = argparse.ArgumentParser(description="Refine a local YOLOX checkpoint.")
    for name in ("checkpoint", "labels", "images", "provenance", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--checkpoint-every", type=int, default=5)
    parser.add_argument("--seed", type=int, default=19)
    parser.add_argument("--learning-rate", type=float, default=0.0001)
    parser.add_argument("--device", choices=("cpu", "mps"), default="cpu")
    args = parser.parse_args()
    if args.epochs < 1 or args.checkpoint_every < 1 or args.output.exists():
        parser.error("Use positive epochs/interval and a new output directory.")
    if not math.isfinite(args.learning_rate) or args.learning_rate <= 0:
        parser.error("Learning rate must be finite and positive.")
    if args.device == "mps" and not torch.backends.mps.is_available():
        parser.error("Metal is unavailable; use CPU.")
    validate_dataset(args.labels, args.images, args.provenance)
    initial = torch.load(args.checkpoint, map_location="cpu", weights_only=True)
    labels, provenance = (
        json.loads(args.labels.read_text()),
        json.loads(args.provenance.read_text()),
    )
    dataset = ComponentDataset(
        labels,
        args.images,
        provenance,
        "train",
        augment=True,
        focus_crops=True,
        image_size=640,
        letterboxed=True,
        balanced_crops=True,
    )
    if dataset.classes != initial["classes"] or len(dataset) < 4:
        parser.error(
            "At least four training images with matching classes are required."
        )
    ids = initial.get("detector_class_ids", [1, 2, 3, 4])
    dataset.items = [
        (
            record,
            [box for box, label in zip(boxes, targets) if label in ids],
            [label for label in targets if label in ids],
        )
        for record, boxes, targets in dataset.items
    ]
    random.seed(args.seed)
    torch.manual_seed(args.seed)
    torch.set_num_threads(4)
    sampler = WeightedRandomSampler(sampling_weights(dataset), len(dataset))
    loader = DataLoader(
        dataset,
        batch_size=4,
        sampler=sampler,
        drop_last=True,
        collate_fn=lambda batch: tuple(zip(*batch)),
    )
    model = YOLOXDetector(initial).core.to(args.device)
    ema = ModelEMA(model)
    backbone_ids = {id(parameter) for parameter in model.backbone.parameters()}
    optimizer = torch.optim.AdamW(
        [
            {
                "params": list(model.backbone.parameters()),
                "lr": args.learning_rate / 10,
            },
            {
                "params": [p for p in model.parameters() if id(p) not in backbone_ids],
                "lr": args.learning_rate,
            },
        ],
        weight_decay=0.0005,
    )
    args.output.mkdir(parents=True)
    history = []
    for epoch in range(args.epochs):
        factor = min(1.0, (epoch + 1) / 5) * (
            0.1 + 0.9 * (1 + math.cos(math.pi * epoch / args.epochs)) / 2
        )
        for group, scale in zip(optimizer.param_groups, (0.1, 1.0)):
            group["lr"] = args.learning_rate * scale * factor
        model.train()
        # Preserve learned batch statistics while the small dataset varies in composition.
        for layer in model.modules():
            if isinstance(layer, torch.nn.BatchNorm2d):
                layer.eval()
        losses = []
        for images, targets in loader:
            batch = torch.stack(images)[:, [2, 1, 0]].to(args.device) * 255
            count = max(1, max(len(target["labels"]) for target in targets))
            packed = torch.zeros((len(images), count, 5), device=args.device)
            for index, target in enumerate(targets):
                count = len(target["labels"])
                boxes = target["boxes"].to(args.device)
                packed[index, :count, 0] = target["labels"].to(args.device) - ids[0]
                packed[index, :count, 1:3] = (boxes[:, :2] + boxes[:, 2:]) / 2
                packed[index, :count, 3:5] = boxes[:, 2:] - boxes[:, :2]
            optimizer.zero_grad()
            loss = model(batch, packed)["total_loss"]
            if not bool(torch.isfinite(loss)):
                raise RuntimeError("Nonfinite loss; no checkpoint saved.")
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 10)
            optimizer.step()
            ema.update(model)
            losses.append(float(loss.detach()))
        row = {"epoch": epoch + 1, "loss": sum(losses) / len(losses)}
        history.append(row)
        print(json.dumps(row), flush=True)
        if (epoch + 1) % args.checkpoint_every == 0 or epoch + 1 == args.epochs:
            checkpoint = {
                **initial,
                "state_dict": {
                    key: value.cpu() for key, value in ema.ema.state_dict().items()
                },
                "epochs": epoch + 1,
                "seed": args.seed,
                "initial_checkpoint_sha256": hashlib.sha256(
                    args.checkpoint.read_bytes()
                ).hexdigest(),
                "learning_rate": args.learning_rate,
                "backbone_learning_rate": args.learning_rate / 10,
                "batchnorm": "frozen initial-checkpoint statistics",
                "initial_checkpoint": str(args.checkpoint),
            }
            torch.save(checkpoint, args.output / f"epoch-{epoch + 1:04d}.pt")
        (args.output / "training.json").write_text(json.dumps(history, indent=2) + "\n")


if __name__ == "__main__":
    main()
