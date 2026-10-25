# Gavin - Export a fixed RGB tensor contract shared by Python and phone clients.
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
import torch
from train import model_from_checkpoint


class ExportDetector(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
        self.image_size = model.transform.fixed_size[0]

    def forward(self, images):
        result = self.model([images[0]])[0]
        return result["boxes"] / self.image_size, result["scores"], result["labels"]


def main():
    parser = argparse.ArgumentParser(
        description="Export and verify local ONNX weights."
    )
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Choose a new output model path.")
    torch.set_num_threads(4)
    checkpoint = torch.load(args.checkpoint, map_location="cpu", weights_only=True)
    model = model_from_checkpoint(checkpoint)
    model.eval()
    wrapper = ExportDetector(model)
    torch.manual_seed(123)
    size = checkpoint.get("image_size", 320)
    sample = torch.rand(1, 3, size, size)
    with torch.inference_mode():
        expected = [value.numpy() for value in wrapper(sample)]
        torch.onnx.export(
            wrapper,
            sample,
            str(args.output),
            dynamo=False,
            input_names=["images"],
            output_names=["boxes", "scores", "labels"],
            opset_version=17,
        )
    onnx.checker.check_model(onnx.load(str(args.output)))
    session = ort.InferenceSession(str(args.output), providers=["CPUExecutionProvider"])
    actual = session.run(None, {"images": sample.numpy()})
    # NMS ties can reorder equal detections; verify class/score/box association together.
    for wanted, received in zip(expected, actual):
        np.testing.assert_allclose(received, wanted, rtol=1e-3, atol=1e-4)
    manifest = {
        "schema_version": 1,
        "architecture": "ssdlite320_mobilenet_v3_large",
        "sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(),
        "classes": checkpoint["classes"],
        "input": {
            "name": "images",
            "dtype": "float32",
            "shape": [1, 3, size, size],
            "color": "RGB",
            "range": [0, 1],
            "resize": "bilinear stretch upright image",
        },
        "outputs": {
            "boxes": "upright_normalized_xyxy",
            "scores": "float32",
            "labels": "int64 indices into classes",
        },
        "threshold": 0.5,
        "max_results": 20,
        "parity": "ONNX checker and CPU outputs matched PyTorch on seeded input",
        "scope": "Local prototype; not validated on physical Android/iOS devices.",
    }
    args.output.with_suffix(".json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
