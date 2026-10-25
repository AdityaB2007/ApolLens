# Gavin - Show actual local detections without implying repair instructions.
import argparse
import json
from pathlib import Path

from onnx_detector import OnnxDetector
from PIL import Image, ImageDraw, ImageFont, ImageOps


def render(image_path, result, output):
    with Image.open(image_path) as original:
        image = ImageOps.exif_transpose(original).convert("RGB")
    draw = ImageDraw.Draw(image)
    width, height = image.size
    font = ImageFont.load_default(size=max(14, width // 65))
    colors = {
        "main_battery": "#FFB347",
        "cooling_fan": "#63FF85",
        "ram_module": "#63CCFF",
        "storage_drive": "#FF75CF",
    }
    for detection in result["detections"]:
        left, top, right, bottom = detection["box"]
        box = (left * width, top * height, right * width, bottom * height)
        color = colors.get(detection["label"], "#FFFFFF")
        draw.rectangle(box, outline=color, width=max(3, width // 300))
        label = f"{detection['label']} {detection['confidence']:.2f}"
        bounds = draw.textbbox((0, 0), label, font=font)
        y = max(0, box[1] - (bounds[3] - bounds[1]) - 10)
        x = max(0, min(box[0], width - bounds[2] - 8))
        draw.rectangle((x, y, x + bounds[2] + 8, y + bounds[3] + 8), fill=color)
        draw.text((x + 4, y + 2), label, fill="#111111", font=font)
    image.thumbnail((1400, 1400))
    image.save(output)


def main():
    parser = argparse.ArgumentParser(description="Preview real local component boxes.")
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--threshold", type=float, default=0.5)
    args = parser.parse_args()
    if args.output.resolve() == args.image.resolve():
        parser.error("Output must not overwrite the source image.")
    with OnnxDetector(args.model, args.threshold) as detector:
        result = detector.detect(args.image)
    render(args.image, result, args.output)
    args.output.with_suffix(".json").write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
