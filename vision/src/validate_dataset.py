"""Validate COCO boxes and a local provenance JSON keyed by image file_name.

Each provenance entry needs source, license, attribution, group_id, split and
reviewed=true. Use one group for a physical laptop and all derived/nearby frames;
use a conservative source-wide group when public device identity is unknown.
Split is train, validation or test. Boxes are upright pixel XYWH; review negatives."""

# Gavin - Keep unreviewed labels and shared-device footage out of evaluation.
import argparse
import hashlib
import json
import math
from collections import Counter
from pathlib import Path

from PIL import Image


def require(condition, message):
    if not condition:
        raise ValueError(message)


def index_records(records, name):
    require(isinstance(records, list) and records, f"Missing {name}")
    indexed = {}
    for record in records:
        require(isinstance(record, dict), f"Invalid {name} record")
        identifier = record.get("id")
        require(type(identifier) is int and identifier >= 0, f"Invalid {name} id")
        require(identifier not in indexed, f"Duplicate {name} id: {identifier}")
        indexed[identifier] = record
    return indexed


def validate_dataset(labels_path: Path, image_dir: Path, provenance_path: Path):
    labels = json.loads(labels_path.read_text())
    provenance = json.loads(provenance_path.read_text())
    require(isinstance(labels, dict), "COCO labels must be an object")
    require(isinstance(provenance, dict), "Provenance must be an object")
    categories = index_records(labels.get("categories"), "category")
    images = index_records(labels.get("images"), "image")
    names = [category.get("name") for category in categories.values()]
    require(
        all(isinstance(name, str) and name.strip() == name and name for name in names),
        "Category names must be nonempty and trimmed",
    )
    require(len(names) == len(set(names)), "Duplicate category names")
    annotations = labels.get("annotations")
    require(isinstance(annotations, list), "Missing annotations list")
    groups, fingerprints, files, counts = {}, {}, set(), Counter()
    root = image_dir.resolve(strict=True)
    for image in images.values():
        filename = image.get("file_name")
        require(isinstance(filename, str) and filename, "Missing image file_name")
        relative = Path(filename)
        require(
            not relative.is_absolute() and ".." not in relative.parts, "Unsafe path"
        )
        path = (root / relative).resolve(strict=True)
        require(path.is_relative_to(root), f"Image outside root: {filename}")
        require(path not in files, f"Repeated image path: {filename}")
        files.add(path)
        entry = provenance.get(filename)
        require(isinstance(entry, dict), f"Missing provenance: {filename}")
        for field in ("source", "license", "attribution", "group_id"):
            value = entry.get(field)
            require(
                isinstance(value, str) and value.strip() == value and value,
                f"Missing or untrimmed {field}: {filename}",
            )
        require(entry.get("reviewed") is True, f"Unreviewed labels: {filename}")
        split, group = entry.get("split"), entry["group_id"]
        require(split in ("train", "validation", "test"), f"Invalid split: {filename}")
        require(groups.setdefault(group, split) == split, f"Group leaks: {group}")
        with Image.open(path) as decoded:
            require(decoded.getexif().get(274, 1) == 1, "Save images upright first")
            width, height = decoded.size
            require(
                type(image.get("width")) is int and type(image.get("height")) is int,
                f"Missing integer dimensions: {filename}",
            )
            require((image["width"], image["height"]) == decoded.size, "Size mismatch")
            digest = hashlib.sha256()
            digest.update(f"{width}x{height}:".encode())
            digest.update(decoded.convert("RGB").tobytes())
        fingerprint = digest.hexdigest()
        require(fingerprint not in fingerprints, f"Duplicate image pixels: {filename}")
        fingerprints[fingerprint] = filename
        counts[split] += 1
    require(
        set(provenance) == {image["file_name"] for image in images.values()},
        "Provenance files must exactly match COCO images",
    )
    annotation_ids = set()
    for annotation in annotations:
        require(isinstance(annotation, dict), "Invalid annotation")
        identifier = annotation.get("id")
        require(type(identifier) is int and identifier >= 0, "Invalid annotation id")
        require(identifier not in annotation_ids, "Duplicate annotation id")
        annotation_ids.add(identifier)
        image_id = annotation.get("image_id")
        category_id = annotation.get("category_id")
        require(type(image_id) is int and image_id in images, "Unknown image id")
        require(
            type(category_id) is int and category_id in categories, "Unknown category"
        )
        require(
            annotation.get("iscrowd", 0) == 0, "Crowd boxes require separate handling"
        )
        box = annotation.get("bbox")
        require(isinstance(box, list) and len(box) == 4, "Expected pixel XYWH bbox")
        require(
            all(type(v) is int or type(v) is float and math.isfinite(v) for v in box),
            "Nonfinite or nonnumeric bbox",
        )
        x, y, width, height = box
        image = images[image_id]
        require(
            x >= 0 and y >= 0 and width > 0 and height > 0, "Empty or negative bbox"
        )
        require(
            x + width <= image["width"] and y + height <= image["height"],
            "Box outside image",
        )
    return {
        "images": len(images),
        "annotations": len(annotations),
        "categories": names,
        "groups": len(groups),
        "splits": dict(counts),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--images", type=Path, required=True)
    parser.add_argument("--provenance", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = validate_dataset(args.labels, args.images, args.provenance)
    except (ValueError, OSError, Image.DecompressionBombError) as error:
        parser.exit(1, f"Dataset rejected: {error}\n")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
