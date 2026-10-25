# Gavin - Keep training-only YOLOX code out of the offline ONNX runtime.
# Use the official Apache-2.0 source at the pinned revision on PYTHONPATH.
import torch
from torchvision.ops import batched_nms

SOURCE_REVISION = "6ddff4824372906469a7fae2dc3206c7aa4bbaee"


class YOLOXDetector(torch.nn.Module):
    def __init__(self, checkpoint):
        super().__init__()
        from yolox.models import YOLOPAFPN, YOLOX, YOLOXHead

        if checkpoint.get("source_commit") != SOURCE_REVISION:
            raise ValueError("Unsupported YOLOX source revision.")
        architecture = checkpoint["architecture"]
        if architecture not in ("yolox_nano", "yolox_tiny"):
            raise ValueError("Unsupported YOLOX architecture.")
        ids = checkpoint.get("detector_class_ids", [1, 2, 3, 4])
        if ids not in ([1, 2, 3, 4], [3, 4]):
            raise ValueError("Expected full component classes or RAM/storage subset.")
        if checkpoint.get("image_size") != 640 or not checkpoint.get("letterbox"):
            raise ValueError("Expected the 640-pixel letterbox training contract.")
        if checkpoint["classes"] != [
            "__background__",
            "main_battery",
            "cooling_fan",
            "ram_module",
            "storage_drive",
        ]:
            raise ValueError(
                "YOLOX class ordering differs from the component contract."
            )
        nano = architecture == "yolox_nano"
        width = 0.25 if nano else 0.375
        self.core = YOLOX(
            YOLOPAFPN(0.33, width, depthwise=nano),
            YOLOXHead(len(ids), width, depthwise=nano),
        )
        for layer in self.core.modules():
            if isinstance(layer, torch.nn.BatchNorm2d):
                layer.eps, layer.momentum = 0.001, 0.03
        self.core.load_state_dict(checkpoint["state_dict"], strict=True)
        self.offset = ids[0]
        self.image_size = 640
        self.eval()

    def forward(self, images):
        if self.training:
            raise RuntimeError("This adapter is for checkpoint evaluation and export.")
        # Official initialization expects raw BGR; callers supply RGB float [0, 1].
        raw = self.core(torch.stack(images)[:, [2, 1, 0]] * 255)
        return [decode_yolox(row, self.offset) for row in raw]


def decode_yolox(raw, class_offset=1):
    scores, labels = (raw[:, 4:5] * raw[:, 5:]).max(dim=1)
    boxes = torch.cat(
        (raw[:, :2] - raw[:, 2:4] / 2, raw[:, :2] + raw[:, 2:4] / 2), dim=1
    ).clamp(0, 640)
    keep = (
        (scores >= 0.001)
        & torch.isfinite(scores)
        & (scores <= 1)
        & torch.isfinite(boxes).all(dim=1)
        & (boxes[:, 2:] > boxes[:, :2]).all(dim=1)
    )
    boxes, scores, labels = boxes[keep], scores[keep], labels[keep]
    order = scores.argsort(descending=True)[:2000]
    boxes, scores, labels = boxes[order], scores[order], labels[order]
    selected = batched_nms(boxes, scores, labels, 0.5)[:200]
    return {
        "boxes": boxes[selected],
        "scores": scores[selected],
        "labels": labels[selected] + class_offset,
    }
