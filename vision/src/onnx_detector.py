# Gavin - Run the exported component detector entirely from local files.
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps


def decode_outputs(boxes, scores, labels, classes, threshold=0.5, max_results=20):
    if not math.isfinite(threshold) or not 0 <= threshold <= 1:
        raise ValueError("Invalid confidence threshold.")
    if type(max_results) is not int or not 1 <= max_results <= 100:
        raise ValueError("Invalid detection limit.")
    boxes, scores, labels = np.asarray(boxes), np.asarray(scores), np.asarray(labels)
    if boxes.ndim != 2 or boxes.shape[1] != 4 or scores.ndim != 1 or labels.ndim != 1:
        raise ValueError("Detector output shapes must be Nx4, N and N.")
    if len(boxes) != len(scores) or len(boxes) != len(labels):
        raise ValueError("Detector output lengths differ.")
    if not np.issubdtype(labels.dtype, np.integer):
        raise ValueError("Detector class indices must be integers.")
    detections = []
    for index in np.argsort(-scores, kind="stable"):
        score, category = float(scores[index]), int(labels[index])
        box = np.asarray(boxes[index], dtype=float)
        if not math.isfinite(score) or not threshold <= score <= 1:
            continue
        if not 0 < category < len(classes) or not np.isfinite(box).all():
            continue
        left, top, right, bottom = np.clip(box, 0, 1).tolist()
        if right <= left or bottom <= top:
            continue
        detections.append(
            {
                "label": classes[category],
                "class_id": category,
                "confidence": score,
                "box": [left, top, right, bottom],
            }
        )
        if len(detections) == max_results:
            break
    return detections


class OnnxDetector:
    def __init__(self, model: Path, threshold=0.5, max_results=20):
        model = Path(model).expanduser().resolve(strict=True)
        if model.suffix.lower() != ".onnx" or not model.is_file():
            raise ValueError("Supply a local .onnx model and its JSON manifest.")
        if not math.isfinite(threshold) or not 0 <= threshold <= 1:
            raise ValueError("Confidence threshold must be between zero and one.")
        if type(max_results) is not int or not 1 <= max_results <= 100:
            raise ValueError("Maximum results must be between 1 and 100.")
        manifest = json.loads(model.with_suffix(".json").read_text())
        if not isinstance(manifest, dict) or manifest.get("schema_version") != 1:
            raise ValueError("Unsupported model manifest version.")
        if hashlib.sha256(model.read_bytes()).hexdigest() != manifest.get("sha256"):
            raise ValueError("Model checksum does not match its manifest.")
        classes = manifest.get("classes")
        if (
            not isinstance(classes, list)
            or len(classes) < 2
            or not all(
                isinstance(name, str) and name.strip() == name and name
                for name in classes
            )
        ):
            raise ValueError("Manifest must contain nonempty class names.")
        if len(set(classes)) != len(classes) or classes[0] != "__background__":
            raise ValueError("Manifest classes must be unique with background first.")
        options = ort.SessionOptions()
        options.intra_op_num_threads = 2
        self._session = ort.InferenceSession(
            str(model), sess_options=options, providers=["CPUExecutionProvider"]
        )
        inputs = self._session.get_inputs()
        if (
            len(inputs) != 1
            or inputs[0].name != "images"
            or inputs[0].type != "tensor(float)"
        ):
            raise ValueError("Expected one float32 images input.")
        if inputs[0].shape != [1, 3, 320, 320]:
            raise ValueError("Expected fixed NCHW 320x320 input.")
        if {output.name for output in self._session.get_outputs()} != {
            "boxes",
            "scores",
            "labels",
        }:
            raise ValueError("Model outputs do not match the exported contract.")
        self.classes, self.threshold, self.max_results = classes, threshold, max_results

    def detect(self, image_path: Path):
        if self._session is None:
            raise RuntimeError("Detector is closed.")
        with Image.open(image_path) as original:
            image = ImageOps.exif_transpose(original).convert("RGB")
            width, height = image.size
            resized = image.resize((320, 320), Image.Resampling.BILINEAR)
            tensor = (
                np.asarray(resized, dtype=np.float32).transpose(2, 0, 1)[None] / 255
            )
        boxes, scores, labels = self._session.run(
            ["boxes", "scores", "labels"], {"images": tensor}
        )
        return {
            "schema_version": 1,
            "image_width": width,
            "image_height": height,
            "coordinates": "upright_normalized_xyxy",
            "detections": decode_outputs(
                boxes, scores, labels, self.classes, self.threshold, self.max_results
            ),
        }

    def close(self):
        self._session = None

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
