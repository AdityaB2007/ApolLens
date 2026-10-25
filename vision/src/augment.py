# Gavin - Expose small modules at different scales without inventing image content.
import random

import torch
from PIL import Image


def focus_crop(image, boxes, labels, size=320):
    candidates = torch.where(labels >= 3)[0].tolist()
    if not candidates:
        return image, boxes, labels
    selected = boxes[random.choice(candidates)]
    margin = random.uniform(0.3, 1.0)
    width, height = (selected[2:] - selected[:2]).tolist()
    left = max(0, int((selected[0] - width * margin) * image.width))
    top = max(0, int((selected[1] - height * margin) * image.height))
    right = min(image.width, int((selected[2] + width * margin) * image.width) + 1)
    bottom = min(image.height, int((selected[3] + height * margin) * image.height) + 1)
    pixels = boxes * torch.tensor([image.width, image.height] * 2)
    clipped = pixels.clone()
    clipped[:, [0, 2]] = clipped[:, [0, 2]].clamp(left, right)
    clipped[:, [1, 3]] = clipped[:, [1, 3]].clamp(top, bottom)
    areas = (pixels[:, 2:] - pixels[:, :2]).prod(dim=1)
    visible = (clipped[:, 2:] - clipped[:, :2]).prod(dim=1) / areas.clamp(min=1e-6)
    keep = visible >= 0.6
    clipped -= torch.tensor([left, top, left, top])
    clipped /= torch.tensor([right - left, bottom - top, right - left, bottom - top])
    image = image.crop((left, top, right, bottom)).resize(
        (size, size), Image.Resampling.BILINEAR
    )
    return image, clipped[keep], labels[keep]
