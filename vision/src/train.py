# Gavin and Aditya - Train a small local component detector from reviewed COCO data.
import argparse
import json
import math
import random
from pathlib import Path

import torch
from augment import focus_crop
from image_geometry import letterbox
from PIL import Image, ImageEnhance, ImageOps
from torch.utils.data import DataLoader, Dataset
from torchvision.models.detection import ssdlite320_mobilenet_v3_large
from torchvision.models.detection.anchor_utils import DefaultBoxGenerator
from torchvision.transforms.functional import pil_to_tensor
from validate_dataset import validate_dataset


def build_model(classes, pretrained=False, image_size=320, small_anchors=False):
    if image_size not in (320, 640) or type(small_anchors) is not bool:
        raise ValueError("Unsupported image size or anchor configuration.")
    model = ssdlite320_mobilenet_v3_large(
        weights=None, weights_backbone=None, num_classes=len(classes)
    )
    if pretrained:
        reference = ssdlite320_mobilenet_v3_large(weights="DEFAULT").state_dict()
        current = model.state_dict()
        compatible = {k: v for k, v in reference.items() if v.shape == current[k].shape}
        model.load_state_dict(compatible, strict=False)
    model.transform.fixed_size = (image_size, image_size)
    if small_anchors:
        model.anchor_generator = DefaultBoxGenerator(
            [[2, 4]] * 6, scales=[0.06, 0.15, 0.3, 0.5, 0.7, 0.85, 1.0]
        )
    return model


def model_from_checkpoint(checkpoint):
    model = build_model(
        checkpoint["classes"],
        image_size=checkpoint.get("image_size", 320),
        small_anchors=checkpoint.get("small_anchors", False),
    )
    model.load_state_dict(checkpoint["state_dict"])
    return model


def load_initial_weights(model, classes, path):
    checkpoint = torch.load(path, map_location="cpu", weights_only=True)
    if checkpoint.get("classes") != classes:
        raise ValueError("Initial checkpoint classes do not match the dataset.")
    model.load_state_dict(checkpoint["state_dict"])


class ComponentDataset(Dataset):
    def __init__(
        self,
        labels,
        images,
        provenance,
        split,
        augment=False,
        focus_crops=False,
        image_size=320,
        letterboxed=False,
    ):
        self.root = Path(images)
        self.classes = ["__background__"] + [c["name"] for c in labels["categories"]]
        class_ids = {c["id"]: i + 1 for i, c in enumerate(labels["categories"])}
        self.items = []
        self.augment = augment
        self.focus_crops = focus_crops
        self.image_size = image_size
        self.letterboxed = letterboxed
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
            image = ImageOps.exif_transpose(original).convert("RGB")
        boxes = torch.tensor(coordinates, dtype=torch.float32).reshape(-1, 4)
        classes = torch.tensor(classes, dtype=torch.int64)
        if self.augment and self.focus_crops and random.random() < 0.65:
            image, boxes, classes = focus_crop(
                image,
                boxes,
                classes,
                size=None if self.letterboxed else self.image_size,
            )
        if not self.letterboxed:
            image = image.resize(
                (self.image_size, self.image_size), Image.Resampling.BILINEAR
            )
        if self.augment:
            image = ImageEnhance.Brightness(image).enhance(random.uniform(0.8, 1.2))
            if random.random() < 0.5:
                image = ImageOps.mirror(image)
                boxes[:, [0, 2]] = 1 - boxes[:, [2, 0]]
            if random.random() < 0.25:
                image = ImageOps.flip(image)
                boxes[:, [1, 3]] = 1 - boxes[:, [3, 1]]
        target_boxes = boxes * self.image_size
        if self.letterboxed:
            image, (left, top, width, height) = letterbox(image, self.image_size)
            target_boxes = boxes * torch.tensor([width, height] * 2)
            target_boxes += torch.tensor([left, top] * 2)
        return pil_to_tensor(image).float() / 255, {
            "boxes": target_boxes,
            "labels": classes,
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
    parser.add_argument("--initial-checkpoint", type=Path)
    parser.add_argument("--learning-rate", type=float, default=0.001)
    parser.add_argument("--fine-tune", action="store_true")
    parser.add_argument("--focus-crops", action="store_true")
    parser.add_argument("--image-size", type=int, choices=(320, 640), default=320)
    parser.add_argument("--small-anchors", action="store_true")
    parser.add_argument("--letterbox", action="store_true")
    parser.add_argument("--device", choices=("cpu", "mps"), default="cpu")
    args = parser.parse_args()
    if args.device == "mps" and not torch.backends.mps.is_available():
        parser.error("Metal training is unavailable on this host.")
    if args.epochs < 1 or args.output.exists():
        parser.error("Use positive epochs and a new output directory.")
    if not math.isfinite(args.learning_rate) or args.learning_rate <= 0:
        parser.error("Learning rate must be finite and positive.")
    if args.initial_checkpoint and args.pretrained:
        parser.error("Choose an initial checkpoint or COCO initialization.")
    validate_dataset(args.labels, args.images, args.provenance)
    random.seed(args.seed)
    torch.manual_seed(args.seed)
    torch.set_num_threads(4)
    labels = json.loads(args.labels.read_text())
    provenance = json.loads(args.provenance.read_text())
    dataset = ComponentDataset(
        labels,
        args.images,
        provenance,
        "train",
        augment=True,
        focus_crops=args.focus_crops,
        image_size=args.image_size,
        letterboxed=args.letterbox,
    )
    if len(dataset) < 2:
        parser.error("At least two reviewed training images are required.")
    loader = DataLoader(
        dataset, batch_size=4, shuffle=True, collate_fn=lambda batch: tuple(zip(*batch))
    )
    model = build_model(
        dataset.classes, args.pretrained, args.image_size, args.small_anchors
    )
    if args.initial_checkpoint:
        load_initial_weights(model, dataset.classes, args.initial_checkpoint)
    model.to(args.device)
    # Freeze general visual features and batch statistics for this small seed set.
    for parameter in model.backbone.parameters():
        parameter.requires_grad_(False)
    optimizer = torch.optim.AdamW(
        (p for p in model.parameters() if p.requires_grad),
        lr=args.learning_rate,
        weight_decay=0.0005,
    )
    args.output.mkdir(parents=True)
    history = []
    for epoch in range(args.epochs):
        if args.fine_tune and epoch == args.epochs // 2:
            for parameter in model.backbone.parameters():
                parameter.requires_grad_(True)
            optimizer.add_param_group(
                {
                    "params": model.backbone.parameters(),
                    "lr": min(0.0001, args.learning_rate / 10),
                }
            )
        model.train()
        model.backbone.eval()
        for module in model.modules():
            if isinstance(module, torch.nn.BatchNorm2d):
                module.eval()
        losses = []
        for images, targets in loader:
            optimizer.zero_grad()
            images = [image.to(args.device) for image in images]
            targets = [
                {key: value.to(args.device) for key, value in target.items()}
                for target in targets
            ]
            loss = sum(model(images, targets).values())
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
            "state_dict": {
                key: value.cpu() for key, value in model.state_dict().items()
            },
            "classes": dataset.classes,
            "seed": args.seed,
            "epochs": args.epochs,
            "fine_tune": args.fine_tune,
            "focus_crops": args.focus_crops,
            "learning_rate": args.learning_rate,
            "image_size": args.image_size,
            "letterbox": args.letterbox,
            "small_anchors": args.small_anchors,
            "device": args.device,
            "initial_checkpoint": str(args.initial_checkpoint)
            if args.initial_checkpoint
            else None,
        },
        args.output / "detector.pt",
    )
    (args.output / "training.json").write_text(json.dumps(history, indent=2) + "\n")


if __name__ == "__main__":
    main()
