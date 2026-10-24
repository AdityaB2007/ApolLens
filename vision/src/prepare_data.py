# Gavin and Aditya: Write Python data preparation and dataset splitting for the training workflow.

# Entry point for computer-vision dataset preparation.

import argparse
from pathlib import Path

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

    print(f"Image directory found: {args.image_dir.resolve()}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())