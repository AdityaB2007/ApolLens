# Gavin and Aditya: Write Python data preparation and dataset splitting for the training workflow.

# Entry point for computer-vision dataset preparation.

import argparse
from pathlib import Path
from collections import Counter

SUPPORTED_EXTENSIONS = {".jpg", ".webp"}

def main() -> int:
    default_dir = Path(__file__).resolve().parents[1] / "data" / "images"
    parser = argparse.ArgumentParser(
        description="Prepare the computer-vision image dataset."
    )
    parser.add_argument(
        "--image-dir",
        type=Path,
        default=default_dir,
        help="Directory with dataset images.",
    )
    args = parser.parse_args()

    if not args.image_dir.is_dir():
        print(f"Error: image directory not found: {args.image_dir}")
        return 1

    image_files = [
        path for path in args.image_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS
    ]

    extension_counts = Counter(
        path.suffix.lower() for path in image_files
    )

    print(f"Image directory: {args.image_dir.resolve()}")
    print(f"Supported images found: {len(image_files)}")

    if extension_counts:
        print("Image formats:")
        for extension, count in sorted(extension_counts.items()):
            print(f"    {extension}: {count}")
    else:
        print("No supported images found.")

    return 0

if __name__ == "__main__":
    raise SystemExit(main())