"""Train an experimental visual-mark classifier from a small reviewed batch."""

import argparse
import csv
import json
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps
import tensorflow as tf


SIZE = 160
CLASSES = ("sin_marcas_evidentes", "marcas_visibles")


def fit_head(features, labels):
    features = np.column_stack((features, np.ones(len(features), dtype=np.float32)))
    weights = np.zeros((features.shape[1], 2), dtype=np.float32)
    targets = np.eye(2, dtype=np.float32)[labels]
    class_weights = (len(labels) / (2 * np.bincount(labels, minlength=2)))[labels]
    for _ in range(300):
        logits = features @ weights
        exp = np.exp(logits - logits.max(axis=1, keepdims=True))
        probabilities = exp / exp.sum(axis=1, keepdims=True)
        gradient = features.T @ ((probabilities - targets) * class_weights[:, None])
        gradient /= len(labels)
        gradient[:-1] += 0.025 * weights[:-1]
        weights -= 0.5 * gradient
    return weights[:-1], weights[-1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    with args.manifest.open(encoding="utf-8-sig", newline="") as file:
        rows = list(csv.DictReader(file))
    photos = []
    for row in rows:
        with Image.open(args.manifest.parent / row["photo"]) as image:
            rgb = ImageOps.exif_transpose(image).convert("RGB")
            photos.append(np.asarray(rgb.resize((SIZE, SIZE), Image.Resampling.BILINEAR)))
    images = np.stack(photos)
    labels = np.array([CLASSES.index(row["label"]) for row in rows])
    groups = np.array([row["group"] for row in rows])

    backbone = tf.keras.applications.MobileNetV2(
        input_shape=(SIZE, SIZE, 3), alpha=0.35, include_top=False,
        weights="imagenet", pooling="avg",
    )
    backbone.trainable = False
    image = tf.keras.Input((SIZE, SIZE, 3), dtype=tf.float32)
    scaled = tf.keras.layers.Rescaling(1 / 127.5, offset=-1)(image)
    features = tf.keras.layers.UnitNormalization()(backbone(scaled, training=False))
    embeddings = tf.keras.Model(image, features).predict(images, verbose=0)

    held_out = []
    for group in np.unique(groups):
        test = groups == group
        if len(np.unique(labels[~test])) != 2:
            continue
        kernel, bias = fit_head(embeddings[~test], labels[~test])
        predictions = (embeddings[test] @ kernel + bias).argmax(axis=1)
        for index, prediction in zip(np.flatnonzero(test), predictions):
            held_out.append({
                "photo": rows[index]["photo"],
                "group": group,
                "visual_label": CLASSES[labels[index]],
                "prediction": CLASSES[prediction],
            })

    head = tf.keras.layers.Dense(2, activation="softmax")
    model = tf.keras.Model(image, head(features))
    head.set_weights(fit_head(embeddings, labels))
    with tempfile.TemporaryDirectory() as saved_model:
        model.export(saved_model, input_signature=[tf.TensorSpec((1, SIZE, SIZE, 3), tf.float32)])
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        exported = converter.convert()

    interpreter = tf.lite.Interpreter(model_content=exported, num_threads=2)
    interpreter.allocate_tensors()
    input_index = interpreter.get_input_details()[0]["index"]
    output_index = interpreter.get_output_details()[0]["index"]
    reference = model.predict(images, verbose=0)
    deployed = []
    for sample in images:
        interpreter.set_tensor(input_index, sample[None].astype(np.float32))
        interpreter.invoke()
        deployed.append(interpreter.get_tensor(output_index)[0])
    if not np.allclose(reference, deployed, atol=0.03):
        raise ValueError("La exportación TFLite difiere del modelo entrenado")

    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / "crop-visual-prototype.tflite").write_bytes(exported)
    report = {
        "target": "Marcas visibles en hoja o fruto; etiquetas visuales provisionales",
        "input": {"shape": [1, SIZE, SIZE, 3], "type": "float32", "rgb_range": [0, 255]},
        "class_order": list(CLASSES),
        "model": "MobileNetV2 0.35 ImageNet con capa final ajustada al lote",
        "training_count": {label: int((labels == i).sum()) for i, label in enumerate(CLASSES)},
        "evaluation": "Exploratoria, por grupos visuales; sin parcelas identificadas",
        "held_out_correct": sum(row["visual_label"] == row["prediction"] for row in held_out),
        "held_out_total": len(held_out),
        "held_out": held_out,
        "export_max_abs_difference": float(np.abs(reference - deployed).max()),
    }
    (args.output / "report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
