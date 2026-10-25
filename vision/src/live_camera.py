# Gavin - Inspect real camera frames with local inference and no image uploads.
import argparse
import json
import threading
import time
from pathlib import Path

import cv2
from onnx_detector import OnnxDetector
from PIL import Image

FONT = cv2.FONT_HERSHEY_SIMPLEX


class LatestCamera:
    """Keep only one pending frame; boxes always accompany the analyzed image."""

    def __init__(self, device):
        self.capture = cv2.VideoCapture(device)
        if not self.capture.isOpened():
            self.capture.release()
            raise RuntimeError(
                "Camera unavailable. Check camera access and device index."
            )
        self.capture.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        self.capture.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        self.pending = None
        self.error = None
        self.condition = threading.Condition()
        self.stopped = threading.Event()
        self.worker = threading.Thread(target=self._capture, daemon=True)
        self.worker.start()

    def _capture(self):
        try:
            while not self.stopped.is_set():
                ok, frame = self.capture.read()
                if not ok or frame is None or not frame.size:
                    raise RuntimeError(
                        "Camera disconnected or returned an empty frame."
                    )
                with self.condition:
                    self.pending = (time.monotonic(), frame.copy())
                    self.condition.notify()
        except (RuntimeError, cv2.error) as error:
            with self.condition:
                self.error = error
                self.condition.notify()
        finally:
            self.capture.release()

    def read(self):
        with self.condition:
            ready = self.condition.wait_for(
                lambda: self.pending is not None or self.error is not None, timeout=2
            )
            if self.error is not None:
                raise RuntimeError("Camera capture failed.") from self.error
            if not ready:
                raise RuntimeError("Camera stopped delivering frames.")
            frame, self.pending = self.pending, None
            return frame

    def close(self):
        self.stopped.set()
        self.worker.join(timeout=2)
        if self.worker.is_alive():
            raise RuntimeError("Camera driver did not stop within two seconds.")


def draw_boxes(frame, result):
    height, width = frame.shape[:2]
    colors = [(71, 179, 255), (133, 255, 99), (255, 204, 99), (207, 117, 255)]
    for item in result["detections"]:
        left, top, right, bottom = item["box"]
        start = (int(left * (width - 1)), int(top * (height - 1)))
        end = (int(right * (width - 1)), int(bottom * (height - 1)))
        color = colors[(item["class_id"] - 1) % len(colors)]
        cv2.rectangle(frame, start, end, color, 2)
        label = f"{item['label']} {item['confidence']:.0%}"
        origin = (start[0], max(22, start[1] - 8))
        cv2.putText(frame, label, origin, FONT, 0.6, color, 2)
    return frame


def main():
    parser = argparse.ArgumentParser(
        description="Offline live camera detector; Q/Esc exits."
    )
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--camera", type=int, default=0)
    parser.add_argument("--threshold", type=float, default=0.5)
    args = parser.parse_args()
    if args.camera < 0:
        parser.error("Use a nonnegative camera index.")
    camera = None
    count, total = 0, 0.0
    window = "ApolLens - offline camera - Q to exit"
    try:
        with OnnxDetector(args.model, args.threshold) as detector:
            camera = LatestCamera(args.camera)
            cv2.namedWindow(window, cv2.WINDOW_NORMAL)
            while True:
                captured, frame = camera.read()
                if time.monotonic() - captured > 0.5:
                    continue
                started = time.monotonic()
                result = detector.detect_image(
                    Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                )
                elapsed = time.monotonic() - started
                count, total = count + 1, total + elapsed
                draw_boxes(frame, result)
                status = f"LOCAL | {elapsed * 1000:.0f} ms | Experimental | Q/Esc exits"
                frame[-34:] = 0
                origin = (12, frame.shape[0] - 12)
                cv2.putText(frame, status, origin, FONT, 0.6, (255, 255, 255), 2)
                cv2.imshow(window, frame)
                if cv2.waitKey(1) & 0xFF in (27, ord("q")):
                    break
                if cv2.getWindowProperty(window, cv2.WND_PROP_VISIBLE) < 1:
                    break
    except (OSError, ValueError, RuntimeError, cv2.error) as error:
        parser.exit(1, f"Live detection unavailable: {error}\n")
    finally:
        try:
            if camera is not None:
                camera.close()
        finally:
            cv2.destroyAllWindows()
    print(
        json.dumps({"frames": count, "mean_inference_ms": total * 1000 / max(1, count)})
    )


if __name__ == "__main__":
    main()
