# Gavin and Aditya: Write Python data preparation and dataset splitting for the training workflow.
# Inspect and validate the computer-vision image dataset.

import argparse
from collections import Counter
from pathlib import Path
from PIL import Image, UnidentifiedImageError

SUPPORTED_EXTENSIONS = {".avif", ".jpg", ".jpeg", ".png", ".webp", ".bmp"}

def discover_images(image_dir: Path) -> list[Path]:
    # Find supported image files, including nested directories.
    return sorted(
        path
        for path in image_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS
    )

def validate_images(image_files: list[Path]) -> list[Path]:
    # Return image files that cannot be decoded.
    invalid_images = []
    for path in image_files:
        try:
            with Image.open(path) as image:
                image.verify()
        except (OSError, ValueError, UnidentifiedImageError):
            invalid_images.append(path)

    return invalid_images

def main() -> int:
    # Validate the image directory and report dataset statistics.
    default_dir = Path(__file__).resolve().parents[1] / "data" / "images"
    parser = argparse.ArgumentParser(
        description="Inspect the computer-vision image dataset."
    )
    parser.add_argument(
        "--image-dir",
        type=Path,
        default=default_dir,
        help="Directory containing dataset images.",
    )
    args = parser.parse_args()

    if not args.image_dir.is_dir():
        print(f"Error: image directory not found: {args.image_dir}")
        return 1

    image_files = discover_images(args.image_dir)
    extension_counts = Counter(
        path.suffix.lower() for path in image_files
    )
    invalid_images = validate_images(image_files)

    print(f"Image directory: {args.image_dir.resolve()}")
    print(f"Supported images found: {len(image_files)}")

    if extension_counts:
        print("Image formats:")
        for extension, count in sorted(extension_counts.items()):
            print(f"  {extension}: {count}")
    else:
        print("No supported images found.")

    print(f"Unreadable images: {len(invalid_images)}")
    for path in invalid_images:
        print(f"  Invalid: {path}")

    return 1 if invalid_images else 0

if __name__ == "__main__":
    raise SystemExit(main())