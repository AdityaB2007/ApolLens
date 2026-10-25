YOLOX checkpoint tools use the official Apache-2.0 source:
https://github.com/Megvii-BaseDetection/YOLOX

Clone it outside this repository and check out revision
`6ddff4824372906469a7fae2dc3206c7aa4bbaee`. Put that checkout on
`PYTHONPATH` for evaluation and export. Install its documented dependencies.
For Metal training, run `git apply --unidiff-zero /path/to/vision/yolox-mps.patch`
in that checkout. The patch
replaces device-name string casts with tensor device/dtype transfers.

`export_model.py`, `evaluate.py` and `calibrate.py` accept our Nano/Tiny
checkpoints. Input remains RGB float32 [0, 1], letterboxed to 640 with padding
114. Outputs map back to upright source coordinates through `OnnxDetector`.
Phone inference needs only the ONNX artifact and manifest, not YOLOX or PyTorch.
These tools do not establish physical-device accuracy or repair safety.

Run `refine_yolox.py --help` for local fine-tuning inputs, seed, epochs, and CPU/Metal selection.
