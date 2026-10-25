# Gavin - Add reviewed training photos without moving calibration or test images.
import argparse
import csv
import hashlib
import json
import tempfile
from io import StringIO
from pathlib import Path

from validate_dataset import validate_dataset


def append_training(labels, provenance, sources, boxes, images):
    records = list(csv.DictReader(StringIO(sources.read_text())))
    if not records:
        raise ValueError("Supply at least one reviewed training image.")
    known = {image["file_name"] for image in labels["images"]}
    added = {}
    next_image = max(image["id"] for image in labels["images"]) + 1
    next_box = max((box["id"] for box in labels["annotations"]), default=0) + 1
    for row in records:
        name = row["file_name"]
        if name in known or name in added or Path(name).name != name:
            raise ValueError("New images must have unique plain file names.")
        if row["split"] != "train" or not row["reviewer"].strip():
            raise ValueError("Only explicitly reviewed training additions are allowed.")
        path = images / name
        if path.is_symlink() or path.resolve().parent != images.resolve():
            raise ValueError("Image must be inside the supplied image directory.")
        if hashlib.sha256(path.read_bytes()).hexdigest() != row["image_sha256"]:
            raise ValueError(f"Prepared image checksum mismatch: {name}")
        added[name] = next_image
        dimensions = {key: int(row[key]) for key in ("width", "height")}
        labels["images"].append({"id": next_image, "file_name": name, **dimensions})
        provenance[name] = {**row, "reviewed": True}
        next_image += 1
    for row in csv.DictReader(StringIO(boxes.read_text())):
        if row["file_name"] not in added:
            raise ValueError("Boxes must reference an image from this addition.")
        if row["coordinates"] != "upright normalized XYXY":
            raise ValueError("Unsupported annotation coordinates.")
        image = next(r for r in records if r["file_name"] == row["file_name"])
        width, height = int(image["width"]), int(image["height"])
        left, top, right, bottom = [float(row[key]) for key in ("x1", "y1", "x2", "y2")]
        bbox = [
            left * width,
            top * height,
            (right - left) * width,
            (bottom - top) * height,
        ]
        labels["annotations"].append(
            {
                "id": next_box,
                "image_id": added[row["file_name"]],
                "category_id": int(row["category_id"]),
                "bbox": bbox,
                "area": bbox[2] * bbox[3],
                "iscrowd": 0,
            }
        )
        next_box += 1
    return labels, provenance


def main():
    parser = argparse.ArgumentParser(description="Append reviewed training photos.")
    for name in ("labels", "provenance", "sources", "boxes", "images", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    destinations = [
        args.output.with_suffix(".labels.json"),
        args.output.with_suffix(".provenance.json"),
    ]
    if any(path.exists() for path in destinations):
        parser.error("Choose a new output prefix; existing datasets are preserved.")
    labels, provenance = append_training(
        json.loads(args.labels.read_text()),
        json.loads(args.provenance.read_text()),
        args.sources,
        args.boxes,
        args.images,
    )
    contents = [
        json.dumps(value, indent=2, allow_nan=False) + "\n"
        for value in (labels, provenance)
    ]
    with tempfile.TemporaryDirectory() as directory:
        paths = [Path(directory) / "labels.json", Path(directory) / "provenance.json"]
        for path, content in zip(paths, contents):
            path.write_text(content)
        report = validate_dataset(paths[0], args.images, paths[1])
    for path, content in zip(destinations, contents):
        path.write_text(content)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
