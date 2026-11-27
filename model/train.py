"""Train and evaluate CropScan with a labeled, partitioned field manifest."""

import argparse
import csv
import hashlib
import json
import tempfile
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps


SIZE = 160
LABELS = {"no_visible_signs": 0, "possible_scale": 1}
SPLITS = ("train", "validation", "test")
THRESHOLDS = (0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95)
MINIMUM_PER_CLASS = 300


def load_dataset(manifest, *, load_pixels=True):
    required_columns = {"photo", "label", "unit", "split", "quality_ok"}
    seen_hashes = set()
    unit_splits = {}
    samples = defaultdict(list)
    labelled = Counter()
    approved = {split: Counter() for split in SPLITS}
    with manifest.open(encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        if not required_columns.issubset(reader.fieldnames or ()):
            raise ValueError(f"Columnas requeridas: {', '.join(sorted(required_columns))}")
        for row in reader:
            photo, label, unit, split, quality = (
                (row[key] or "").strip()
                for key in ("photo", "label", "unit", "split", "quality_ok")
            )
            if not photo or label not in LABELS or not unit or split not in SPLITS:
                raise ValueError(f"Foto, etiqueta, unidad o partición inválida (fila {reader.line_num})")
            if quality not in ("0", "1"):
                raise ValueError(f"quality_ok debe ser 0 o 1 (fila {reader.line_num})")
            if unit_splits.setdefault(unit, split) != split:
                raise ValueError(f"La unidad productiva {unit!r} aparece en varias particiones")
            path = manifest.parent / photo
            with path.open("rb") as photo_file:
                digest = hashlib.file_digest(photo_file, "sha256").digest()
            if digest in seen_hashes:
                raise ValueError(f"Se encontró una imagen duplicada (fila {reader.line_num})")
            seen_hashes.add(digest)
            labelled[label] += 1
            if quality == "1":
                with Image.open(path) as image:
                    image.load()
                    if load_pixels:
                        rgb = ImageOps.exif_transpose(image).convert("RGB")
                        resized = rgb.resize((SIZE, SIZE), Image.Resampling.BILINEAR)
                        samples[split].append((np.asarray(resized), LABELS[label]))
                approved[split][label] += 1
    total = sum(labelled.values())
    accepted = sum(sum(counts.values()) for counts in approved.values())
    for label in LABELS:
        if labelled[label] < MINIMUM_PER_CLASS:
            raise ValueError(
                f"Se requieren {MINIMUM_PER_CLASS} imágenes etiquetadas por clase; "
                + ", ".join(f"{name}={labelled[name]}" for name in LABELS)
            )
    if accepted / total < 0.90:
        raise ValueError("Se requiere al menos 90 % de imágenes con calidad aprobada")

    data = {}
    for split in SPLITS:
        if set(approved[split]) != set(LABELS):
            raise ValueError(f"La partición {split!r} debe contener ambas clases con calidad aprobada")
        if load_pixels:
            photos, labels = zip(*samples[split])
            data[split] = np.stack(photos), np.array(labels)
    return data, {
        "labelled": total,
        "accepted": accepted,
        "quality_rate": accepted / total,
        "labelled_by_class": dict(labelled),
        "approved_by_split": {split: dict(counts) for split, counts in approved.items()},
        "units_by_split": dict(Counter(unit_splits.values())),
    }


def build_model(width):
    import tensorflow as tf

    layers = tf.keras.layers
    inputs = layers.Input(shape=(SIZE, SIZE, 3), dtype="float32")
    x = layers.Rescaling(1 / 255)(inputs)
    x = layers.Conv2D(width, 3, strides=2, activation="relu")(x)
    for filters in (width * 2, width * 4, width * 8):
        x = layers.SeparableConv2D(filters, 3, padding="same", activation="relu")(x)
        x = layers.MaxPooling2D()(x)
    x = layers.GlobalAveragePooling2D()(x)
    outputs = layers.Dense(2, activation="softmax")(x)
    return tf.keras.Model(inputs, outputs)


def train_model(width, train, validation, epochs):
    import tensorflow as tf

    model = build_model(width)
    model.compile(optimizer="adam", loss="sparse_categorical_crossentropy")
    counts = np.bincount(train[1])
    model.fit(
        *train,
        validation_data=validation,
        epochs=epochs,
        batch_size=16,
        verbose=2,
        class_weight={int(label): float(len(train[1]) / (2 * count))
                      for label, count in enumerate(counts)},
        callbacks=[tf.keras.callbacks.EarlyStopping(
            monitor="val_loss", patience=4, restore_best_weights=True
        )],
    )
    return model


def metrics(labels, scores, threshold):
    scores = scores.astype(np.float64)
    # Android chooses index zero in a tie. Index two represents abstention.
    predictions = scores.argmax(axis=1)
    predictions[scores.max(axis=1) < threshold] = 2
    matrix = np.zeros((2, 3), dtype=int)
    np.add.at(matrix, (labels, predictions), 1)
    correct = matrix.diagonal()
    predicted = matrix.sum(axis=0)[:2]
    actual = matrix.sum(axis=1)
    precision = correct / np.maximum(predicted, 1)
    recall = correct / actual
    f1 = 2 * correct / (predicted + actual)
    return {
        "threshold": threshold,
        "macro_f1": float(f1.mean()),
        "scale_recall": float(recall[1]),
        "precision_by_class": precision.tolist(),
        "recall_by_class": recall.tolist(),
        "f1_by_class": f1.tolist(),
        "coverage": float((predictions != 2).mean()),
        "matrix": matrix.tolist(),
    }


def select_threshold(labels, scores):
    return max(
        (metrics(labels, scores, threshold) for threshold in THRESHOLDS),
        key=lambda result: (result["macro_f1"], result["scale_recall"], result["coverage"]),
    )


def lite_scores(model_bytes, images):
    import tensorflow as tf

    interpreter = tf.lite.Interpreter(model_content=model_bytes, num_threads=2)
    interpreter.allocate_tensors()
    input_index = interpreter.get_input_details()[0]["index"]
    output_index = interpreter.get_output_details()[0]["index"]
    outputs = []
    for image in images:
        interpreter.set_tensor(input_index, image[None, ...].astype(np.float32))
        interpreter.invoke()
        outputs.append(interpreter.get_tensor(output_index)[0])
    return np.stack(outputs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("output", type=Path, nargs="?",
                        help="Nuevo directorio para resultados y exportación")
    parser.add_argument("--epochs", type=int, default=24)
    parser.add_argument("--check-only", action="store_true",
                        help="Verifica el manifiesto y las particiones sin entrenar ni exportar")
    args = parser.parse_args()
    if args.epochs < 1:
        parser.error("--epochs debe ser positivo")
    if args.output is None and not args.check_only:
        parser.error("Se requiere un directorio de salida para entrenar")

    try:
        data, dataset = load_dataset(args.manifest, load_pixels=not args.check_only)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    if args.check_only:
        print(json.dumps(dataset, indent=2))
        return

    import tensorflow as tf

    args.output.mkdir(parents=True, exist_ok=False)
    tf.keras.utils.set_random_seed(42)
    train_x, train_y = data["train"]
    train = (
        np.concatenate((train_x, np.flip(train_x, axis=2))),
        np.tile(train_y, 2),
    )
    validation_x, validation_y = data["validation"]
    test_x, test_y = data["test"]
    candidates = []
    for width in (16, 32):
        model = train_model(width, train, data["validation"], args.epochs)
        validation = select_threshold(validation_y, model.predict(validation_x, verbose=0))
        candidates.append((width, model, validation))
    width, model, base_validation = max(
        candidates, key=lambda candidate: candidate[2]["macro_f1"]
    )
    with tempfile.TemporaryDirectory() as saved_model:
        input_signature = [tf.TensorSpec((1, SIZE, SIZE, 3), tf.float32)]
        model.export(saved_model, input_signature=input_signature)
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        model_bytes = converter.convert()
    lite_validation = select_threshold(validation_y, lite_scores(model_bytes, validation_x))

    base_test = metrics(test_y, model.predict(test_x, verbose=0), base_validation["threshold"])
    lite_test = metrics(test_y, lite_scores(model_bytes, test_x), lite_validation["threshold"])
    meets_metrics = all(
        result["scale_recall"] >= 0.85 and result["macro_f1"] >= 0.85
        for result in (base_test, lite_test)
    )
    report = {
        "manifest_sha256": hashlib.sha256(args.manifest.read_bytes()).hexdigest(),
        "dataset": dataset,
        "partition_sizes": {split: len(data[split][1]) for split in SPLITS},
        "matrix_rows": list(LABELS),
        "matrix_columns": [*LABELS, "inconclusive"],
        "candidate_validation": {f"width_{w}": scores for w, _, scores in candidates},
        "selected_width": width,
        "base_test": base_test,
        "litert_validation": lite_validation,
        "litert_test": lite_test,
        "meets_metrics": meets_metrics,
    }
    (args.output / "evaluation.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    if not meets_metrics:
        raise SystemExit("El modelo base o el optimizado no alcanzó las métricas en prueba independiente.")
    (args.output / "cropscan.tflite").write_bytes(model_bytes)
    (args.output / "cropscan-model.json").write_text(
        json.dumps({"threshold": lite_validation["threshold"]}) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
