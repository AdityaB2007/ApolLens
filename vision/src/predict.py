# Gavin and Aditya - Local inference for a supplied mobile-compatible detector.
import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageOps


def normalize_detections(result, width: int, height: int) -> list[dict]:
    """Convert model boxes to upright normalized XYXY; do not infer repair actions."""
    if width <= 0 or height <= 0:
        raise ValueError("Image dimensions must be positive.")
    detections = []
    for detection in result.detections:
        categories = [
            c
            for c in detection.categories
            if c.category_name
            and c.category_name.strip()
            and math.isfinite(c.score)
            and 0 <= c.score <= 1
        ]
        if not categories:
            continue
        category = max(categories, key=lambda c: c.score)
        box = detection.bounding_box
        coordinates = (box.origin_x, box.origin_y, box.width, box.height)
        if not all(math.isfinite(value) for value in coordinates):
            continue
        if box.width <= 0 or box.height <= 0:
            continue
        left = max(0, min(1, box.origin_x / width))
        top = max(0, min(1, box.origin_y / height))
        right = max(0, min(1, (box.origin_x + box.width) / width))
        bottom = max(0, min(1, (box.origin_y + box.height) / height))
        if right > left and bottom > top:
            detections.append(
                {
                    "label": category.category_name.strip(),
                    "class_id": category.index,
                    "confidence": float(category.score),
                    "box": [left, top, right, bottom],
                }
            )
    return detections


class LocalDetector:
    """Reuse one CPU detector; the model must already exist on disk."""

    def __init__(self, model: Path, threshold: float = 0.5, max_results: int = 20):
        model = Path(model).expanduser().resolve(strict=True)
        if not model.is_file() or model.suffix.lower() != ".tflite":
            raise ValueError(
                "Supply a local .tflite object-detection model with metadata."
            )
        if not math.isfinite(threshold) or not 0 <= threshold <= 1:
            raise ValueError("Confidence threshold must be between 0 and 1.")
        if not 1 <= max_results <= 100:
            raise ValueError("Maximum results must be between 1 and 100.")
        import mediapipe as mp
        from mediapipe.tasks import python
        from mediapipe.tasks.python import vision

        self._mp = mp
        self._detector = vision.ObjectDetector.create_from_options(
            vision.ObjectDetectorOptions(
                base_options=python.BaseOptions(
                    model_asset_path=str(model),
                    delegate=python.BaseOptions.Delegate.CPU,
                ),
                running_mode=vision.RunningMode.IMAGE,
                score_threshold=threshold,
                max_results=max_results,
            )
        )

    def detect(self, image_path: Path) -> dict:
        if self._detector is None:
            raise RuntimeError("Detector is closed.")
        import numpy as np

        with Image.open(image_path) as original:
            # Normalize EXIF orientation before inference and coordinate reporting.
            upright = ImageOps.exif_transpose(original).convert("RGB")
            width, height = upright.size
            image = self._mp.Image(
                image_format=self._mp.ImageFormat.SRGB, data=np.asarray(upright)
            )
        result = self._detector.detect(image)
        return {
            "schema_version": 1,
            "image_width": width,
            "image_height": height,
            "coordinates": "upright_normalized_xyxy",
            "detections": normalize_detections(result, width, height),
        }

    def close(self):
        detector, self._detector = self._detector, None
        if detector is not None:
            detector.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a local detector offline.")
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--threshold", type=float, default=0.5)
    parser.add_argument("--max-results", type=int, default=20)
    args = parser.parse_args()
    try:
        detector_type = LocalDetector
        if args.model.suffix.lower() == ".onnx":
            from onnx_detector import OnnxDetector

            detector_type = OnnxDetector
        with detector_type(args.model, args.threshold, args.max_results) as detector:
            print(json.dumps(detector.detect(args.image), allow_nan=False))
    except ImportError:
        parser.exit(1, "Install vision/requirements.txt before inference.\n")
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, f"Inference unavailable: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
