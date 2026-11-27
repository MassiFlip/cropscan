"""Run a technical CNN experiment with the verified 900-file dataset."""

import argparse
import csv
import json
import os
import platform
import tempfile
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

from prepare_experimental_dataset import digest, read_rows, verify
from train import LABELS, SIZE, build_model


LABEL_MAP = {"sanas": LABELS["no_visible_signs"], "con_queresa": LABELS["possible_scale"]}
CONFIG = Path(__file__).parent / "experiments" / "config_cnn_900.json"


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def verify_data(directory):
    manifest = directory / "manifest.csv"
    rows = read_rows(manifest)
    integrity = verify(directory, rows)
    inventory_path = directory.parent / "manifest.csv"
    inventory = {row["archivo"]: row for row in read_rows(inventory_path)}
    for row in rows:
        source = inventory[row["archivo_original"]]
        for key in ("clase", "etiqueta_fuente"):
            if source[key] != row[key] or not source[key]:
                raise ValueError(f"Etiqueta sin respaldo en el inventario: {row['archivo']}")
        if source["sha256"] != row["sha256_original"]:
            raise ValueError(f"Linaje con SHA-256 inválido: {row['archivo']}")
    origins = Counter(row["archivo_original"] for row in rows
                      if row["clase"] == "con_queresa" and row["tipo"] == "aumentada")
    if sum(origins.values()) != 444:
        raise ValueError("Se esperaban 444 aumentos positivos.")
    inventory_sanas = {path for path, row in inventory.items() if row["clase"] == "sanas"}
    included_sanas = {row["archivo_original"] for row in rows
                      if row["clase"] == "sanas" and row["tipo"] == "original"}
    build_notes = json.loads((directory / "verificacion.json").read_text(encoding="utf-8"))
    excluded = build_notes["exclusiones_etiquetadas"]
    if set(excluded) != inventory_sanas - included_sanas:
        raise ValueError("Las exclusiones sanas difieren del inventario.")
    integrity.update(
        manifest_sha256=digest(manifest), inventory_sha256=digest(inventory_path),
        healthy_original_exclusions=excluded, positive_augmentations_by_origin=dict(origins),
        pending_rows_used=0,
    )
    return rows, integrity


def load_split(directory, rows, split):
    chosen = [row for row in rows if row["particion"] == split]
    pixels = []
    for row in chosen:
        with Image.open(directory / row["archivo"]) as image:
            rgb = ImageOps.exif_transpose(image).convert("RGB")
            pixels.append(np.asarray(rgb.resize((SIZE, SIZE), Image.Resampling.BILINEAR)))
    return np.stack(pixels), np.array([LABEL_MAP[row["clase"]] for row in chosen]), chosen


def batches(tf, images, labels, config, *, weights=None):
    elements = (images, labels) if weights is None else (images, labels, weights[labels])
    data = tf.data.Dataset.from_tensor_slices(elements)
    if weights is not None:
        data = data.shuffle(len(labels), seed=config["seed"], reshuffle_each_iteration=True)
    options = tf.data.Options()
    options.threading.private_threadpool_size = 2
    return data.batch(config["batch_size"]).with_options(options).prefetch(1)


def save_history(output, history, plt):
    keys = ("loss", "val_loss", "accuracy", "val_accuracy")
    epochs = list(range(1, len(history["loss"]) + 1))
    with (output / "history.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(("epoch", *keys))
        writer.writerows(zip(epochs, *(history[key] for key in keys)))
    figure, axes = plt.subplots(1, 2, figsize=(10, 4), layout="constrained")
    for axis, metric, title in zip(axes, ("loss", "accuracy"), ("Pérdida", "Exactitud")):
        axis.plot(epochs, history[metric], marker="o", label="Entrenamiento")
        axis.plot(epochs, history[f"val_{metric}"], marker="o", label="Validación")
        axis.set(title=title, xlabel="Época", xticks=epochs)
        axis.grid(alpha=0.25)
        axis.legend()
    figure.suptitle("CropScan experimental · Validación con 8 originales y 1 positivo")
    figure.savefig(output / "curvas.png", dpi=180)
    plt.close(figure)


def export_and_smoke_test(tf, model, output, images, labels, rows, tolerance):
    signature = [tf.TensorSpec((1, SIZE, SIZE, 3), tf.float32, name="image")]
    with tempfile.TemporaryDirectory() as temporary:
        model.export(temporary, input_signature=signature)
        converter = tf.lite.TFLiteConverter.from_saved_model(temporary)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        candidate = output / "cropscan_experimental.tflite.tmp"
        candidate.write_bytes(converter.convert())
    interpreter = tf.lite.Interpreter(model_path=str(candidate), num_threads=2)
    interpreter.allocate_tensors()
    inputs, = interpreter.get_input_details()
    outputs, = interpreter.get_output_details()
    if (tuple(inputs["shape"]) != (1, SIZE, SIZE, 3) or tuple(outputs["shape"]) != (1, 2)
            or inputs["dtype"] != np.float32 or outputs["dtype"] != np.float32):
        raise ValueError("El contrato de tensores TFLite no coincide con el de Android.")
    probes = []
    for label in LABELS.values():
        index = int(np.flatnonzero(labels == label)[0])
        image = images[index:index + 1].astype(np.float32)
        reference = model(image, training=False).numpy()[0]
        interpreter.set_tensor(inputs["index"], image)
        interpreter.invoke()
        actual = interpreter.get_tensor(outputs["index"])[0]
        error = float(np.max(np.abs(reference - actual)))
        if (not np.isfinite(actual).all() or not np.isclose(actual.sum(), 1, atol=0.001)
                or error > tolerance):
            raise ValueError(f"La inferencia TFLite no conserva las probabilidades: {error}")
        probes.append({"image": rows[index]["archivo"], "source_class": rows[index]["clase"],
                       "keras": reference.tolist(), "tflite": actual.tolist(),
                       "max_abs_error": error})
    del interpreter
    target = output / "cropscan_experimental.tflite"
    candidate.replace(target)
    return {
        "format": "TFLite FP16 weights, float32 input and output",
        "input_shape": [1, SIZE, SIZE, 3], "input_range": [0, 255],
        "output_shape": [1, 2], "class_order": list(LABELS), "threshold": None,
        "bytes": target.stat().st_size, "sha256": digest(target), "probes": probes,
    }


def run(dataset, output, config):
    status = {"mode": "experimental", "scientific_validation": False, "config": config}
    output.mkdir(parents=True)
    status_path = output / "status.json"
    try:
        status["step"] = "dependencies"
        os.environ.setdefault("TF_ENABLE_ONEDNN_OPTS", "0")
        import matplotlib
        import tensorflow as tf

        matplotlib.use("Agg")
        from matplotlib import pyplot as plt

        tf.config.set_visible_devices([], "GPU")
        tf.config.threading.set_inter_op_parallelism_threads(config["inter_op_threads"])
        tf.config.threading.set_intra_op_parallelism_threads(config["intra_op_threads"])
        tf.keras.utils.set_random_seed(config["seed"])
        tf.config.experimental.enable_op_determinism()
        status["environment"] = {
            "python": platform.python_version(), "tensorflow": tf.__version__,
            "keras": tf.keras.__version__, "numpy": np.__version__,
            "matplotlib": matplotlib.__version__, "device": "CPU",
            "oneDNN": os.environ["TF_ENABLE_ONEDNN_OPTS"],
            "script_sha256": digest(Path(__file__)),
            "field_pipeline_sha256": digest(Path(__file__).with_name("train.py")),
        }
        status["step"] = "data_verification"
        rows, status["data"] = verify_data(dataset)
        print("Verificación de las 900 imágenes y de los grupos completada.", flush=True)

        status["step"] = "training"
        train_x, train_y, _ = load_split(dataset, rows, "train")
        val_x, val_y, _ = load_split(dataset, rows, "validation")
        weights = (len(train_y) / (len(LABELS) * np.bincount(train_y))).astype(np.float32)
        status["training"] = {
            "optimizer": "Adam", "loss": "sparse_categorical_crossentropy",
            "class_weights": dict(zip(LABELS, map(float, weights))),
            "epochs_requested": config["epochs"],
        }
        write_json(status_path, status)
        model = build_model(config["width"])
        model.compile(optimizer=tf.keras.optimizers.Adam(config["learning_rate"]),
                      loss="sparse_categorical_crossentropy", metrics=["accuracy"])
        history = model.fit(batches(tf, train_x, train_y, config, weights=weights),
                            validation_data=batches(tf, val_x, val_y, config),
                            epochs=config["epochs"], verbose=2).history
        status["training"].update(parameters=model.count_params(),
                                  epochs_completed=len(history["loss"]), final_epoch={
                                      key: float(values[-1]) for key, values in history.items()})
        status["step"] = "history_and_keras_model"
        save_history(output, history, plt)
        model.save(output / "cropscan_experimental.keras")

        status["step"] = "descriptive_test"
        test_x, test_y, test_rows = load_split(dataset, rows, "test")
        test = batches(tf, test_x, test_y, config)
        descriptive = model.evaluate(test, verbose=0, return_dict=True)
        scores = model.predict(test.map(lambda images, labels: images), verbose=0)
        matrix = np.zeros((len(LABELS), len(LABELS)), dtype=int)
        np.add.at(matrix, (test_y, scores.argmax(axis=1)), 1)
        status["test_descriptive"] = {
            "loss": float(descriptive["loss"]), "accuracy": float(descriptive["accuracy"]),
            "matrix_labels": list(LABELS), "matrix_true_rows_predicted_columns": matrix.tolist(),
        }

        status["step"] = "tflite_export_and_inference"
        status["tflite"] = export_and_smoke_test(tf, model, output, test_x, test_y, test_rows,
                                                config["tflite_max_abs_error"])
    except Exception as error:
        status["error"] = {"type": type(error).__name__, "message": str(error)}
        raise
    else:
        status["step"] = "complete"
    finally:
        write_json(status_path, status)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset", type=Path)
    parser.add_argument("output", type=Path, help="Nuevo directorio de resultados del experimento")
    parser.add_argument("--config", type=Path, default=CONFIG)
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding="utf-8-sig"))
    if config.get("purpose") != "experimental_pipeline_smoke_test":
        parser.error("Se requiere una configuración experimental.")
    run(args.dataset.resolve(), args.output.resolve(), config)


if __name__ == "__main__":
    main()
