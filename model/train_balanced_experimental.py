"""Train a second experimental run with the same configuration and holdouts as v1."""

import argparse
import json
from collections import Counter
from functools import partial
from pathlib import Path

from balance_training_dataset import verify
from prepare_experimental_dataset import CLASSES, SPLITS, digest, read_rows
from train_experimental import CONFIG, run, verify_data


def verify_balanced(dataset, baseline, baseline_status):
    original, baseline_checks = verify_data(baseline)
    if baseline_checks["manifest_sha256"] != baseline_status["data"]["manifest_sha256"]:
        raise ValueError("El manifiesto de referencia difiere del usado en v1.")
    if baseline_checks["inventory_sha256"] != baseline_status["data"]["inventory_sha256"]:
        raise ValueError("El inventario de referencia difiere del usado en v1.")
    manifest = dataset / "manifest_balanceado.csv"
    balanced = read_rows(manifest)
    counts = verify(dataset, original, balanced)
    expected = {
        ("train", "sanas", "original"): 252, ("train", "sanas", "augmentada"): 106,
        ("train", "con_queresa", "original"): 4, ("train", "con_queresa", "augmentada"): 354,
        ("validation", "sanas", "original"): 7, ("validation", "con_queresa", "original"): 1,
        ("test", "sanas", "original"): 85, ("test", "con_queresa", "original"): 1,
    }
    if counts != expected:
        raise ValueError(f"El contenido no coincide con el dataset balanceado de 810 archivos: {counts}")
    metadata = ("clase", "particion", "grupo_origen", "sha256", "etiqueta_fuente", "variedad", "fuente")
    baseline_holdouts = {
        row["archivo"]: (row["archivo_original"], *(row[key] for key in metadata))
        for row in original if row["particion"] != "train"
    }
    balanced_holdouts = {
        row["archivo_experimental_previo"]: (row["archivo_fuente"], *(row[key] for key in metadata))
        for row in balanced if row["particion"] != "train"
    }
    if baseline_holdouts != balanced_holdouts:
        raise ValueError("Validación o prueba no son idénticas a v1.")
    normalized = [dict(row, archivo=row["nombre_archivo"]) for row in balanced]
    origin_counts = Counter(row["archivo_fuente"] for row in balanced
                            if row["clase"] == "con_queresa" and row["tipo_origen"] == "augmentada")
    return normalized, {
        "archivos": len(normalized), "manifest_sha256": digest(manifest),
        "baseline_manifest_sha256": baseline_checks["manifest_sha256"],
        "inventory_sha256": baseline_checks["inventory_sha256"],
        "adapter_sha256": digest(Path(__file__)),
        "por_particion": {
            split: {
                label: {kind: counts[split, label, kind] for kind in ("original", "augmentada", "duplicada")}
                for label in CLASSES
            }
            for split in SPLITS
        },
        "grupos_originales": len({row["grupo_origen"] for row in balanced}),
        "positive_augmentations_by_origin": dict(origin_counts),
        "holdouts_identical_to_v1": len(baseline_holdouts),
        "pending_rows_used": 0,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    baseline = args.dataset.resolve().with_name("dataset_900_experimental")
    baseline_path = CONFIG.parent / "cnn_900_run_01" / "status.json"
    baseline_status = json.loads(baseline_path.read_text(encoding="utf-8"))
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    if config != baseline_status["config"]:
        parser.error("La configuración actual difiere de la registrada en v1.")
    verifier = partial(verify_balanced, baseline=baseline, baseline_status=baseline_status)
    run(args.dataset.resolve(), args.output.resolve(), config, verify_dataset=verifier)


if __name__ == "__main__":
    main()
