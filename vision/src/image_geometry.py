# Gavin - Share exact image padding geometry between training and local inference.
import numpy as np
from PIL import Image


def letterbox(image, size):
    scale = min(size / image.width, size / image.height)
    width = max(1, round(image.width * scale))
    height = max(1, round(image.height * scale))
    left, top = (size - width) // 2, (size - height) // 2
    resized = image.resize((width, height), Image.Resampling.BILINEAR)
    canvas = Image.new("RGB", (size, size), (114, 114, 114))
    canvas.paste(resized, (left, top))
    return canvas, (left, top, width, height)


def source_boxes(boxes, geometry, size):
    boxes = np.asarray(boxes, dtype=np.float32).copy()
    if boxes.ndim != 2 or boxes.shape[1] != 4:
        raise ValueError("Detector boxes must have shape Nx4.")
    left, top, width, height = geometry
    boxes *= size
    boxes -= np.array([left, top, left, top], dtype=np.float32)
    boxes /= np.array([width, height, width, height], dtype=np.float32)
    return boxes
