"""Run the experimental visual-mark model on one or more local photos."""

import argparse
import json
import sys
from importlib.util import find_spec
from pathlib import Path

# Reuse the workspace copy when running with the original PowerShell setup.
if find_spec("ai_edge_litert") is None:
    local_runtime = Path(__file__).resolve().parents[1] / ".tooling" / "cropscan-lite"
    if local_runtime.is_dir():
        sys.path.append(str(local_runtime))

import numpy as np
from ai_edge_litert.interpreter import Interpreter
from PIL import Image, ImageOps


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("photos", nargs="+", type=Path)
    args = parser.parse_args()

    directory = Path(__file__).resolve().parent / "prototype"
    metadata = json.loads((directory / "report.json").read_text(encoding="utf-8"))
    interpreter = Interpreter(
        model_path=str(directory / "crop-visual-prototype.tflite"), num_threads=2
    )
    interpreter.allocate_tensors()
    model_input = interpreter.get_input_details()[0]
    model_output = interpreter.get_output_details()[0]
    _, height, width, _ = model_input["shape"]
    classes = {
        "sin_marcas_evidentes": "Sin marcas evidentes",
        "marcas_visibles": "Marcas visibles",
    }

    print("Prototipo experimental de marcas visibles.")
    for photo in args.photos:
        try:
            with Image.open(photo) as image:
                rgb = ImageOps.exif_transpose(image).convert("RGB")
                resized = rgb.resize((width, height), Image.Resampling.BILINEAR)
                pixels = np.asarray(resized, dtype=np.float32)[None, ...]
        except OSError as error:
            parser.exit(1, f"No pude abrir {photo}: {error}\n")
        interpreter.set_tensor(model_input["index"], pixels)
        interpreter.invoke()
        scores = interpreter.get_tensor(model_output["index"])[0]
        best = int(scores.argmax())
        print(f"{photo.name}\t{classes[metadata['class_order'][best]]}\t{scores[best]:.1%}")


if __name__ == "__main__":
    main()
