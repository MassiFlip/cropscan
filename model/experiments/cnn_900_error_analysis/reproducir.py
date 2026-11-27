"""Evaluate the saved run once, using the original test split and its fixed argmax."""

import argparse
import base64
import csv
import html
import io
import json
import os
import sys
from collections import Counter
from pathlib import Path
from urllib.parse import quote

import numpy as np
from PIL import Image, ImageDraw, ImageOps

MODEL_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(MODEL_DIR))
from prepare_experimental_dataset import digest
from train import lite_scores
from train_experimental import load_split, verify_data


def descriptive_metrics(labels, scores):
    classes = ("sanas", "con_queresa")
    matrix = np.zeros((2, 2), dtype=int)
    np.add.at(matrix, (labels, scores.argmax(axis=1)), 1)
    diagonal = matrix.diagonal()
    recall = diagonal / matrix.sum(axis=1)
    precision = np.divide(diagonal, matrix.sum(axis=0), out=np.zeros(2),
                          where=matrix.sum(axis=0) > 0)
    f1 = 2 * diagonal / (matrix.sum(axis=1) + matrix.sum(axis=0))
    return {
        "orden_filas_y_columnas": classes,
        "matriz_real_filas_predicha_columnas": matrix.tolist(),
        "exactitud": float(diagonal.sum() / matrix.sum()),
        "exactitud_balanceada": float(recall.mean()),
        "macro_f1": float(f1.mean()),
        "tasa_falsos_positivos": float(matrix[0, 1] / matrix[0].sum()),
        "exactitud_regla_siempre_sana": float(matrix[0].sum() / matrix.sum()),
        "por_clase": {
            label: {"n": int(matrix[i].sum()), "precision": float(precision[i]),
                    "recall": float(recall[i]), "f1": float(f1[i])}
            for i, label in enumerate(classes)
        },
    }


def image_signals(pixels):
    array = pixels.astype(np.float32)
    gray = array @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    inside = gray[1:-1, 1:-1]
    laplacian = gray[:-2, 1:-1] + gray[2:, 1:-1] + gray[1:-1, :-2] + gray[1:-1, 2:] - 4 * inside
    maximum = array.max(axis=2)
    return {
        "luma_media": round(float(gray.mean()), 4),
        "contraste_luma": round(float(gray.std()), 4),
        "fraccion_clara": round(float((gray >= 243).mean()), 5),
        "fraccion_oscura": round(float((gray <= 12).mean()), 5),
        "saturacion_media": round(float((np.ptp(array, axis=2) / np.maximum(maximum, 1)).mean()), 5),
        "nitidez_textura_laplaciano": round(float(laplacian.var()), 4),
    }


def csv_file(path, rows):
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def write_gallery(path, dataset, false_positives, correct):
    def card(row):
        with Image.open(dataset / row["archivo"]) as image:
            preview = ImageOps.exif_transpose(image).convert("RGB")
            preview.thumbnail((420, 300))
            payload = io.BytesIO()
            preview.save(payload, "JPEG", quality=85)
        encoded = base64.b64encode(payload.getvalue()).decode("ascii")
        name = html.escape(Path(row["archivo"]).name)
        label = html.escape(row["etiqueta_fuente"])
        relative_image = Path(os.path.relpath(dataset / row["archivo"], path.parent)).as_posix()
        return f"""<article><a href="{quote(relative_image)}"><img loading="lazy"
src="data:image/jpeg;base64,{encoded}" alt="Abrir original de {name}"></a>
<div><h3>{name}</h3><p>Etiqueta del inventario · Sana ({label})<br>
Predicción · <strong>{row['predicha']}</strong></p><dl>
<dt>no_visible_signs</dt><dd>{row['keras_no_visible_signs']:.8f}</dd>
<dt>possible_scale</dt><dd>{row['keras_possible_scale']:.8f}</dd>
</dl><small>{row['ancho']} × {row['alto']} px</small></div></article>"""

    document = """<!doctype html><html lang="es"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CropScan · Galería de errores</title>
<style>
body{font:16px system-ui,sans-serif;color:#1a291f;background:#f0f4ed;margin:0}
main{max-width:1220px;margin:auto;padding:24px}h1{margin-top:0}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(246px,1fr));gap:16px;margin:16px 0 28px}
article{background:white;border:1px solid #cbd8ca;border-radius:14px;overflow:hidden}
article>div{padding:12px}img{width:100%;height:190px;object-fit:contain;background:#e7ece5;display:block}
h3{font-size:1rem;overflow-wrap:anywhere;margin:0}dt{float:left;clear:left}dd{text-align:right;margin:0;font-variant-numeric:tabular-nums}
strong{color:#8d340d}summary{cursor:pointer;font-weight:700}
</style><main><h1>Galería de errores · CropScan</h1>
<p>Corrida experimental 01. 56 sanas del inventario predichas como posibles queresas.
Ordenadas por puntuación positiva de Keras. Las probabilidades carecen de validación de campo.</p>
<h2>Falsos positivos</h2><div class="grid">"""
    document += "".join(card(row) for row in false_positives)
    document += '</div><details><summary>29 sanas acertadas para comparación</summary><div class="grid">'
    document += "".join(card(row) for row in correct)
    path.write_text(document + "</div></details></main></html>\n", encoding="utf-8")


def review_sheets(dataset, rows, directory):
    directory.mkdir(parents=True, exist_ok=True)
    healthy = [row for row in rows if row["real"] == "sanas"]
    for start in range(0, len(healthy), 30):
        page = healthy[start:start + 30]
        board = Image.new("RGB", (960, ((len(page) + 5) // 6) * 153), "#ecefec")
        draw = ImageDraw.Draw(board)
        for index, row in enumerate(page):
            x, y = index % 6 * 160, index // 6 * 153
            with Image.open(dataset / row["archivo"]) as image:
                photo = ImageOps.exif_transpose(image).convert("RGB")
                photo.thumbnail((152, 126))
            board.paste(photo, (x + (160 - photo.width) // 2, y))
            draw.text((x + 6, y + 128), f"{start + index + 1:02d}", fill="black")
        board.save(directory / f"revision_{start + 1:02d}.jpg", quality=90)
    csv_file(directory / "indice_revision.csv", [
        {"id_revision": i, "archivo": row["archivo"]} for i, row in enumerate(healthy, 1)
    ])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset", type=Path)
    parser.add_argument("run", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--review-sheets", type=Path)
    args = parser.parse_args()
    os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"
    import tensorflow as tf

    tf.config.set_visible_devices([], "GPU")
    tf.config.threading.set_inter_op_parallelism_threads(2)
    tf.config.threading.set_intra_op_parallelism_threads(4)
    status = json.loads((args.run / "status.json").read_text(encoding="utf-8"))
    rows, integrity = verify_data(args.dataset)
    if integrity["manifest_sha256"] != status["data"]["manifest_sha256"]:
        raise ValueError("El manifiesto no corresponde a la corrida 01.")
    tflite_path = args.run / "cropscan_experimental.tflite"
    if digest(tflite_path) != status["tflite"]["sha256"]:
        raise ValueError("El TFLite no corresponde a la corrida 01.")
    model_path = args.run / "cropscan_experimental.keras"
    model = tf.keras.models.load_model(model_path, compile=False)
    images, labels, test = load_split(args.dataset, rows, "test")
    keras = np.concatenate([model(batch, training=False).numpy()
                            for batch in np.array_split(images, 6)])
    lite = lite_scores(tflite_path.read_bytes(), images)
    metrics = descriptive_metrics(labels, keras)
    if metrics["matriz_real_filas_predicha_columnas"] != status["test_descriptive"]["matrix_true_rows_predicted_columns"]:
        raise ValueError("La matriz reproducida difiere del registro de la corrida.")
    metrics.update(
        uso="descriptivo_experimental_argmax_sin_ajuste",
        sha256_manifiesto=integrity["manifest_sha256"], sha256_keras=digest(model_path),
        sha256_tflite=digest(tflite_path),
        matriz_tflite=descriptive_metrics(labels, lite)["matriz_real_filas_predicha_columnas"],
        desacuerdos_argmax_keras_tflite=int((keras.argmax(axis=1) != lite.argmax(axis=1)).sum()),
        max_diferencia_abs_keras_tflite=float(np.abs(keras - lite).max()),
        grupos_prueba=dict(Counter(row["grupo_origen"] for row in test)),
    )
    predictions = []
    for row, pixels, scores, lite_scores_row in zip(test, images, keras, lite):
        filename = row["archivo"]
        with Image.open(args.dataset / filename) as image:
            width, height = ImageOps.exif_transpose(image).size
        predictions.append({
            "archivo": filename, "archivo_original": row["archivo_original"],
            "real": row["clase"], "predicha": ("sanas", "con_queresa")[int(scores.argmax())],
            "etiqueta_fuente": row["etiqueta_fuente"], "variedad": row["variedad"],
            "grupo": row["grupo_origen"], "original_o_aumento": row["tipo"],
            "keras_no_visible_signs": float(scores[0]), "keras_possible_scale": float(scores[1]),
            "tflite_no_visible_signs": float(lite_scores_row[0]),
            "tflite_possible_scale": float(lite_scores_row[1]),
            "ancho": width, "alto": height, **image_signals(pixels),
        })
    false_positives = sorted((row for row in predictions
                              if row["real"] == "sanas" and row["predicha"] == "con_queresa"),
                             key=lambda row: -row["keras_possible_scale"])
    correct = [row for row in predictions if row["real"] == row["predicha"] == "sanas"]
    args.output.mkdir(parents=True, exist_ok=True)
    csv_file(args.output / "predicciones_prueba.csv", predictions)
    csv_file(args.output / "falsos_positivos.csv", false_positives)
    (args.output / "metricas.json").write_text(
        json.dumps(metrics, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    write_gallery(args.output / "galeria_falsos_positivos.html", args.dataset, false_positives, correct)
    if args.review_sheets:
        review_sheets(args.dataset, predictions, args.review_sheets)
    print(json.dumps(metrics, indent=2, ensure_ascii=True))


if __name__ == "__main__":
    main()
