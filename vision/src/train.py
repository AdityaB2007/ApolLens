# Gavin and Aditya - Train a small local component detector from reviewed COCO data.
import argparse
import json
import random
from pathlib import Path

import torch
from PIL import Image, ImageEnhance, ImageOps
from torch.utils.data import DataLoader, Dataset
from torchvision.models.detection import ssdlite320_mobilenet_v3_large
from torchvision.transforms.functional import pil_to_tensor
from validate_dataset import validate_dataset


def build_model(classes, pretrained=False):
    model = ssdlite320_mobilenet_v3_large(
        weights=None, weights_backbone=None, num_classes=len(classes)
    )
    if pretrained:
        reference = ssdlite320_mobilenet_v3_large(weights="DEFAULT").state_dict()
        current = model.state_dict()
        compatible = {k: v for k, v in reference.items() if v.shape == current[k].shape}
        model.load_state_dict(compatible, strict=False)
    return model


class ComponentDataset(Dataset):
    def __init__(self, labels, images, provenance, split, augment=False):
        self.root = Path(images)
        self.classes = ["__background__"] + [c["name"] for c in labels["categories"]]
        class_ids = {c["id"]: i + 1 for i, c in enumerate(labels["categories"])}
        self.items = []
        self.augment = augment
        for image in labels["images"]:
            if provenance[image["file_name"]]["split"] != split:
                continue
            rows = [a for a in labels["annotations"] if a["image_id"] == image["id"]]
            boxes, targets = [], []
            for row in rows:
                x, y, w, h = row["bbox"]
                boxes.append(
                    [
                        x / image["width"],
                        y / image["height"],
                        (x + w) / image["width"],
                        (y + h) / image["height"],
                    ]
                )
                targets.append(class_ids[row["category_id"]])
            self.items.append((image, boxes, targets))

    def __len__(self):
        return len(self.items)

    def __getitem__(self, index):
        record, coordinates, classes = self.items[index]
        with Image.open(self.root / record["file_name"]) as original:
            image = (
                ImageOps.exif_transpose(original)
                .convert("RGB")
                .resize((320, 320), Image.Resampling.BILINEAR)
            )
        boxes = torch.tensor(coordinates, dtype=torch.float32).reshape(-1, 4)
        if self.augment:
            image = ImageEnhance.Brightness(image).enhance(random.uniform(0.8, 1.2))
            if random.random() < 0.5:
                image = ImageOps.mirror(image)
                boxes[:, [0, 2]] = 1 - boxes[:, [2, 0]]
            if random.random() < 0.25:
                image = ImageOps.flip(image)
                boxes[:, [1, 3]] = 1 - boxes[:, [3, 1]]
        return pil_to_tensor(image).float() / 255, {
            "boxes": boxes * 320,
            "labels": torch.tensor(classes, dtype=torch.int64),
            "image_id": torch.tensor(record["id"]),
        }


def main():
    parser = argparse.ArgumentParser(
        description="Train reviewed local COCO annotations."
    )
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--images", type=Path, required=True)
    parser.add_argument("--provenance", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--epochs", type=int, default=80)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument(
        "--pretrained",
        action="store_true",
        help="Download official COCO initialization during training.",
    )
    parser.add_argument("--fine-tune", action="store_true")
    args = parser.parse_args()
    if args.epochs < 1 or args.output.exists():
        parser.error("Use positive epochs and a new output directory.")
    validate_dataset(args.labels, args.images, args.provenance)
    random.seed(args.seed)
    torch.manual_seed(args.seed)
    torch.set_num_threads(4)
    labels = json.loads(args.labels.read_text())
    provenance = json.loads(args.provenance.read_text())
    dataset = ComponentDataset(labels, args.images, provenance, "train", augment=True)
    if len(dataset) < 2:
        parser.error("At least two reviewed training images are required.")
    loader = DataLoader(
        dataset, batch_size=4, shuffle=True, collate_fn=lambda batch: tuple(zip(*batch))
    )
    model = build_model(dataset.classes, args.pretrained)
    # Freeze general visual features and batch statistics for this small seed set.
    for parameter in model.backbone.parameters():
        parameter.requires_grad_(False)
    optimizer = torch.optim.AdamW(
        (p for p in model.parameters() if p.requires_grad),
        lr=0.001,
        weight_decay=0.0005,
    )
    args.output.mkdir(parents=True)
    history = []
    for epoch in range(args.epochs):
        if args.fine_tune and epoch == args.epochs // 2:
            for parameter in model.backbone.parameters():
                parameter.requires_grad_(True)
            optimizer.add_param_group(
                {"params": model.backbone.parameters(), "lr": 0.0001}
            )
        model.train()
        model.backbone.eval()
        for module in model.modules():
            if isinstance(module, torch.nn.BatchNorm2d):
                module.eval()
        losses = []
        for images, targets in loader:
            optimizer.zero_grad()
            loss = sum(model(list(images), list(targets)).values())
            if not torch.isfinite(loss):
                raise RuntimeError("Nonfinite training loss; no model exported.")
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 10)
            optimizer.step()
            losses.append(loss.item())
        history.append({"epoch": epoch + 1, "loss": sum(losses) / len(losses)})
        print(json.dumps(history[-1]), flush=True)
    torch.save(
        {
            "state_dict": model.state_dict(),
            "classes": dataset.classes,
            "seed": args.seed,
            "epochs": args.epochs,
            "fine_tune": args.fine_tune,
        },
        args.output / "detector.pt",
    )
    (args.output / "training.json").write_text(json.dumps(history, indent=2) + "\n")


if __name__ == "__main__":
    main()
