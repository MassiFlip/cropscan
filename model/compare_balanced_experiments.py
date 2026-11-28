"""Compare the saved experimental models on their unchanged evaluation photos."""

import argparse
import csv
import json
from collections import Counter
from pathlib import Path

import numpy as np

from prepare_experimental_dataset import digest, read_rows
from train import lite_scores
from train_experimental import LABELS, load_split, write_json


def metrics(labels, scores):
    predicted = scores.argmax(axis=1)
    matrix = np.zeros((2, 2), dtype=int)
    np.add.at(matrix, (labels, predicted), 1)
    tn, fp, fn, tp = map(int, matrix.ravel())
    f1 = [2 * correct / (2 * correct + fp + fn) for correct in (tn, tp)]
    return {
        "matrix_true_rows_predicted_columns": matrix.tolist(),
        "accuracy": (tn + tp) / len(labels),
        "macro_f1": sum(f1) / 2,
        "healthy_false_positives": fp,
        "healthy_false_positive_rate": fp / (tn + fp),
        "positive_false_negatives": fn,
    }


def plot_histories(v1, v2):
    import matplotlib

    matplotlib.use("Agg")
    from matplotlib import pyplot as plt

    histories = [read_rows(run / "history.csv") for run in (v1, v2)]
    figure, axes = plt.subplots(1, 2, figsize=(11, 4.3), layout="constrained")
    for axis, metric, title in zip(axes, ("loss", "accuracy"), ("Pérdida", "Exactitud")):
        for rows, name, color in zip(histories, ("v1", "v2"), ("#315894", "#9b431e")):
            epochs = [int(row["epoch"]) for row in rows]
            axis.plot(epochs, [float(row[metric]) for row in rows], "o-",
                      color=color, label=f"{name} entrenamiento")
            axis.plot(epochs, [float(row["val_" + metric]) for row in rows], "s--",
                      color=color, label=f"{name} validación")
        axis.set(title=title, xlabel="Época", xticks=epochs)
        axis.grid(alpha=0.25)
        axis.legend()
    figure.suptitle("CropScan experimental · Validación con 8 originales, 1 con queresa")
    figure.savefig(v2 / "curvas_comparadas.png", dpi=180)
    plt.close(figure)
    return {
        name: {
            "minimum_validation_loss_epoch": int(min(rows, key=lambda r: float(r["val_loss"]))["epoch"]),
            "minimum_validation_loss": min(float(row["val_loss"]) for row in rows),
            "last_epoch_training_accuracy": float(rows[-1]["accuracy"]),
            "last_epoch_validation_accuracy": float(rows[-1]["val_accuracy"]),
            "last_epoch_training_loss": float(rows[-1]["loss"]),
            "last_epoch_validation_loss": float(rows[-1]["val_loss"]),
        }
        for name, rows in zip(("v1", "v2"), histories)
    }


def compare(dataset, v1, v2):
    import tensorflow as tf

    previous_dataset = dataset.with_name("dataset_900_experimental")
    paths = previous_dataset / "manifest.csv", dataset / "manifest_balanceado.csv"
    statuses = [json.loads((run / "status.json").read_text(encoding="utf-8")) for run in (v1, v2)]
    if any(status["step"] != "complete" or digest(path) != status["data"]["manifest_sha256"]
           for status, path in zip(statuses, paths)) or statuses[0]["config"] != statuses[1]["config"]:
        raise ValueError("Las corridas o manifiestos no coinciden con los registros de entrenamiento.")
    config = statuses[0]["config"]
    tf.config.set_visible_devices([], "GPU")
    tf.config.threading.set_inter_op_parallelism_threads(config["inter_op_threads"])
    tf.config.threading.set_intra_op_parallelism_threads(config["intra_op_threads"])
    old_rows, new_rows = map(read_rows, paths)
    new_holdouts = {row["archivo_experimental_previo"]: row for row in new_rows
                    if row["particion"] in ("validation", "test")}
    old_holdouts = [row for row in old_rows if row["particion"] in ("validation", "test")]
    if len(new_holdouts) != len(old_holdouts) or set(new_holdouts) != {row["archivo"] for row in old_holdouts}:
        raise ValueError("Las listas de fotos de evaluación difieren.")
    ordered = [
        dict(new_holdouts[row["archivo"]], archivo=new_holdouts[row["archivo"]]["nombre_archivo"])
        for row in old_holdouts
    ]
    models = [tf.keras.models.load_model(run / "cropscan_experimental.keras", compile=False)
              for run in (v1, v2)]
    lite = v2 / "cropscan_experimental.tflite"
    if digest(lite) != statuses[1]["tflite"]["sha256"]:
        raise ValueError("El modelo TFLite difiere del registrado por el entrenamiento.")
    result = {"class_order": list(LABELS), "split_results": {}}
    for split in ("validation", "test"):
        old_x, old_y, old_split = load_split(previous_dataset, old_holdouts, split)
        new_x, new_y, new_split = load_split(dataset, ordered, split)
        if not np.array_equal(old_y, new_y) or not np.array_equal(old_x, new_x):
            raise ValueError(f"Las etiquetas o imágenes preprocesadas difieren en {split}.")
        scores1 = models[0](old_x, training=False).numpy()
        scores2 = models[1](new_x, training=False).numpy()
        lite_scores2 = lite_scores(lite.read_bytes(), new_x)
        for scores in (scores1, scores2, lite_scores2):
            if not np.isfinite(scores).all() or not np.allclose(scores.sum(axis=1), 1, atol=0.001):
                raise ValueError(f"Probabilidades inválidas en {split}.")
        parity = {
            "images": len(new_y),
            "max_absolute_probability_error": float(np.max(np.abs(scores2 - lite_scores2))),
            "different_argmax": int(np.count_nonzero(scores2.argmax(axis=1) != lite_scores2.argmax(axis=1))),
        }
        parity["within_configured_tolerance"] = (
            parity["max_absolute_probability_error"] <= config["tflite_max_abs_error"]
        )
        result["split_results"][split] = {"v1": metrics(old_y, scores1), "v2": metrics(new_y, scores2),
                                          "v2_keras_tflite": parity}
        if split == "test":
            for name, status in zip(("v1", "v2"), statuses):
                matrix = result["split_results"]["test"][name]["matrix_true_rows_predicted_columns"]
                if matrix != status["test_descriptive"]["matrix_true_rows_predicted_columns"]:
                    raise ValueError(f"La matriz de {name} no coincide con su registro.")
            result["healthy_paired_outcomes"] = save_predictions(
                v2, old_split, new_split, new_y, scores1, scores2, lite_scores2
            )
    result["training_curves"] = plot_histories(v1, v2)
    write_json(v2 / "comparacion.json", result)
    print(json.dumps(result, ensure_ascii=False, indent=2))


def save_predictions(output, old_rows, new_rows, labels, scores1, scores2, lite_scores2):
    outcomes = Counter()
    class_names = ("sanas", "con_queresa")
    fields = ("archivo_v1", "archivo_v2", "archivo_fuente", "grupo_origen", "clase_real",
              "v1_p_sana", "v1_p_queresa", "v1_predicha", "v2_p_sana", "v2_p_queresa",
              "v2_predicha", "v2_tflite_p_sana", "v2_tflite_p_queresa", "resultado_pareado_sana")
    transitions = {(0, 0): "correcto_en_ambos", (1, 0): "fp_corregido",
                   (0, 1): "fp_nuevo", (1, 1): "fp_en_ambos"}
    with (output / "predicciones_prueba_comparadas.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(fields)
        for old, new, label, p1, p2, p_lite in zip(old_rows, new_rows, labels, scores1, scores2, lite_scores2):
            c1, c2 = int(p1.argmax()), int(p2.argmax())
            outcome = transitions[c1, c2] if label == 0 else ""
            if outcome:
                outcomes[outcome] += 1
            writer.writerow([old["archivo"], new["archivo"], new["archivo_fuente"], new["grupo_origen"],
                             class_names[label], *map(float, p1), class_names[c1],
                             *map(float, p2), class_names[c2], *map(float, p_lite), outcome])
    return {outcome: outcomes[outcome] for outcome in transitions.values()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset", type=Path)
    parser.add_argument("v1_run", type=Path)
    parser.add_argument("v2_run", type=Path)
    args = parser.parse_args()
    compare(args.dataset, args.v1_run, args.v2_run)
