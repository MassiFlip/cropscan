"""Build CropScan's reproducible experimental dataset without training a model."""

import argparse
import csv
import hashlib
import json
import random
import shutil
from collections import Counter, defaultdict
from pathlib import Path
from uuid import uuid4

from PIL import Image, ImageEnhance, ImageOps


CLASSES = ("sanas", "con_queresa")
SPLITS = ("train", "validation", "test")
TARGET = 450
SEED = 42
FIELDS = (
    "archivo", "clase", "particion", "tipo", "archivo_original", "grupo_origen",
    "transformacion", "sha256_original", "sha256", "etiqueta_fuente", "variedad", "fuente",
)
EXCLUDED = {
    "sanas/agro227_Copia_de_IMG-20250812-WA0149.jpg":
        "Probable recodificación de la toma WA0137, conservada como representante.",
    "sanas/agro227_Copia_de_IMG-20250812-WA0181.jpg":
        "Coincidencia visual con WA0193, cuya etiqueta está en conflicto.",
}
POSITIVE_PLAN = {
    "biovision_1760.jpeg": ("biovision_guia", "validation"),
    "queensland_figura9_1968.png": ("queensland_archivo", "train"),
    "unprg_foto22.jpg": ("unprg_motupe", "test"),
    "uns_anexo1_A.jpg": ("uns_casma_fundo_mi_leslie", "train"),
    "uns_anexo1_B.jpg": ("uns_casma_fundo_mi_leslie", "train"),
    "uns_anexo1_C.jpg": ("uns_casma_fundo_mi_leslie", "train"),
}
HEALTHY_PLAN = {
    "chapingo": ("chapingo_lote_estudio", "train"),
    "harvard": ("harvard_lote_good", "validation"),
    "agro227": ("agro227_lote_frutos", "test"),
}


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read_rows(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def write_rows(path, rows, fields):
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def select_originals(root):
    selected = []
    for entry in read_rows(root / "manifest.csv"):
        name = entry["archivo"]
        label = entry["clase"]
        if label not in CLASSES or name in EXCLUDED:
            continue
        source = (root / name).resolve()
        if not source.is_relative_to(root) or not entry["etiqueta_fuente"]:
            raise ValueError(f"Original sin etiqueta de fuente o fuera del inventario: {name}")
        if digest(source) != entry["sha256"]:
            raise ValueError(f"El SHA-256 del original no coincide: {name}")
        if label == "sanas":
            group, split = HEALTHY_PLAN[source.name.split("_", 1)[0]]
        else:
            group, split = POSITIVE_PLAN[source.name]
        selected.append({
            "archivo": (Path(label) / split / source.name).as_posix(),
            "clase": label,
            "particion": split,
            "tipo": "original",
            "archivo_original": name,
            "grupo_origen": group,
            "transformacion": "",
            "sha256_original": entry["sha256"],
            "sha256": entry["sha256"],
            "etiqueta_fuente": entry["etiqueta_fuente"],
            "variedad": entry["variedad"],
            "fuente": entry["fuente"],
        })
    return selected


def augment(source, target, rng, positive):
    degrees = rng.choice((0, 90, 180, 270))
    flip = rng.choice((False, True))
    brightness = round(rng.uniform(0.92, 1.08), 4)
    contrast = round(rng.uniform(0.94, 1.06), 4)
    zoom = round(rng.uniform(1.0, 1.02 if positive else 1.05), 4)
    with Image.open(source) as original:
        image = ImageOps.exif_transpose(original).convert("RGB")
    width, height = image.size
    crop_width, crop_height = round(width / zoom), round(height / zoom)
    left, top = (width - crop_width) // 2, (height - crop_height) // 2
    crop = (left, top, left + crop_width, top + crop_height)
    if (crop_width, crop_height) != (width, height):
        image = image.resize((width, height), Image.Resampling.BICUBIC, box=crop)
    if degrees:
        image = image.transpose({
            90: Image.Transpose.ROTATE_90,
            180: Image.Transpose.ROTATE_180,
            270: Image.Transpose.ROTATE_270,
        }[degrees])
    if flip:
        image = ImageOps.mirror(image)
    image = ImageEnhance.Brightness(image).enhance(brightness)
    image = ImageEnhance.Contrast(image).enhance(contrast)
    image.save(target, format="JPEG", quality=96, subsampling=0)
    return json.dumps({
        "rotacion_antihoraria": degrees, "volteo_horizontal": flip, "brillo": brightness,
        "contraste": contrast, "zoom_centrado": zoom, "recorte_xyxy": crop,
    }, separators=(",", ":"))


def fill(root, stage, originals):
    rng = random.Random(SEED)
    rows = list(originals)
    hashes = {row["sha256"] for row in rows}
    for row in originals:
        shutil.copyfile(root / row["archivo_original"], stage / row["archivo"])
    for label in CLASSES:
        entries = [row for row in originals if row["clase"] == label]
        # Keep the historical scan as one reference original and avoid amplifying its artifacts.
        bases = [row for row in entries if row["particion"] == "train"
                 and row["grupo_origen"] != "queensland_archivo"]
        if not bases or len(entries) > TARGET:
            raise ValueError(f"No se puede construir la clase {label} con {len(entries)} originales.")
        rng.shuffle(bases)
        for index in range(TARGET - len(entries)):
            source = bases[index % len(bases)]
            name = Path(source["archivo_original"]).stem
            relative = f"{label}/train/aug_{index + 1:03d}_{name}.jpg"
            target = stage / relative
            for _ in range(20):
                transformation = augment(root / source["archivo_original"], target, rng,
                                         positive=label == "con_queresa")
                file_hash = digest(target)
                if file_hash not in hashes:
                    break
            else:
                raise ValueError(f"No se obtuvo una variante distinta para {relative}")
            hashes.add(file_hash)
            rows.append(dict(source, archivo=relative, tipo="aumentada",
                             transformacion=transformation, sha256=file_hash))
    return sorted(rows, key=lambda row: row["archivo"])


def verify(stage, rows):
    expected = {row["archivo"] for row in rows}
    actual = {file.relative_to(stage).as_posix() for label in CLASSES
              for file in (stage / label).rglob("*") if file.is_file()}
    counts = Counter(row["clase"] for row in rows)
    if len(expected) != len(rows) or expected != actual or counts != dict.fromkeys(CLASSES, TARGET):
        raise ValueError("Los archivos o cantidades no coinciden con el manifiesto de 900 imágenes.")
    originals = {row["archivo_original"]: row for row in rows if row["tipo"] == "original"}
    if len(originals) != sum(row["tipo"] == "original" for row in rows):
        raise ValueError("Hay un original repetido en el inventario de trabajo.")
    partitions = defaultdict(set)
    files_hashes = set()
    for row in rows:
        name = row["archivo"]
        base = originals[row["archivo_original"]]
        split, label = row["particion"], row["clase"]
        if Path(name).parts[:2] != (label, split):
            raise ValueError(f"Ruta incompatible con la clase o partición: {name}")
        partitions[row["grupo_origen"]].add(split)
        for key in ("clase", "particion", "grupo_origen", "sha256_original"):
            if row[key] != base[key]:
                raise ValueError(f"La procedencia no coincide con su original: {name}")
        file_hash = digest(stage / name)
        if file_hash != row["sha256"] or file_hash in files_hashes:
            raise ValueError(f"Archivo alterado o repetido por bytes: {name}")
        files_hashes.add(file_hash)
        with Image.open(stage / name) as image:
            image.load()
        if row["tipo"] == "original":
            if row["transformacion"] or file_hash != row["sha256_original"]:
                raise ValueError(f"Se transformó un original: {name}")
        elif row["tipo"] != "aumentada" or split != "train" or not row["transformacion"]:
            raise ValueError(f"Variante fuera del entrenamiento o sin receta: {name}")
    if any(len(group_splits) != 1 for group_splits in partitions.values()):
        raise ValueError("Se detectó una fuga de grupo entre particiones.")
    for label in CLASSES:
        if {row["particion"] for row in originals.values() if row["clase"] == label} != set(SPLITS):
            raise ValueError(f"Falta un original de la clase {label} en alguna partición.")
    breakdown = {
        label: {
            split: {kind: sum(row["clase"] == label and row["particion"] == split
                              and row["tipo"] == kind for row in rows)
                    for kind in ("original", "duplicada", "aumentada")}
            for split in SPLITS
        }
        for label in CLASSES
    }
    return {"archivos": len(rows), "por_clase": dict(counts), "por_particion": breakdown,
            "grupos_originales": len(partitions), "sha256_unicos": len(files_hashes),
            "semilla": SEED}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset", type=Path)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    root = args.dataset.resolve()
    destination = root / "dataset_900_experimental"
    if args.verify_only:
        summary = verify(destination, read_rows(destination / "manifest.csv"))
    else:
        if destination.exists():
            parser.error(f"Ya existe {destination}. Usa --verify-only para revisarlo.")
        originals = select_originals(root)
        stage = root / f".{destination.name}-{uuid4().hex}"
        stage.mkdir()
        try:
            for label in CLASSES:
                for split in SPLITS:
                    (stage / label / split).mkdir(parents=True)
            rows = fill(root, stage, originals)
            write_rows(stage / "manifest.csv", rows, FIELDS)
            summary = verify(stage, read_rows(stage / "manifest.csv"))
            summary["sha256_inventario_original"] = digest(root / "manifest.csv")
            summary["exclusiones_etiquetadas"] = EXCLUDED
            (stage / "verificacion.json").write_text(
                json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
            )
            stage.rename(destination)
        finally:
            if stage.is_dir() and stage.resolve().parent == root:
                shutil.rmtree(stage)
    print(json.dumps(summary, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
