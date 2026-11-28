"""Balance CropScan's experimental training split without changing its inputs."""

import argparse
import json
import math
import random
import shutil
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageOps

from prepare_experimental_dataset import CLASSES, SPLITS, digest, read_rows, write_rows
from train_experimental import verify_data


FIELDS = (
    "nombre_archivo", "clase", "particion", "tipo_origen", "archivo_fuente",
    "transformacion", "grupo_origen", "sha256", "sha256_fuente", "etiqueta_fuente",
    "variedad", "fuente", "archivo_experimental_previo",
)


def augment(image, pad, size, path, rng):
    width, height = size
    angle = round(rng.uniform(-10, 10), 3)
    zoom = round(rng.uniform(0.97, 1.04), 4)
    tx = round(rng.uniform(-0.03, 0.03) * width, 3)
    ty = round(rng.uniform(-0.03, 0.03) * height, 3)
    flip = rng.choice((False, True))
    brightness = round(rng.uniform(0.94, 1.06), 4)
    contrast = round(rng.uniform(0.94, 1.06), 4)
    cosine = math.cos(math.radians(angle)) / zoom
    sine = math.sin(math.radians(angle)) / zoom
    cx, cy = (width - 1) / 2, (height - 1) / 2
    inverse = (
        cosine, -sine, pad + cx - cosine * (cx + tx) + sine * (cy + ty),
        sine, cosine, pad + cy - sine * (cx + tx) - cosine * (cy + ty),
    )
    canvas = ImageOps.mirror(image) if flip else image
    result = canvas.transform(size, Image.Transform.AFFINE, inverse,
                              resample=Image.Resampling.BICUBIC)
    result = ImageEnhance.Brightness(result).enhance(brightness)
    result = ImageEnhance.Contrast(result).enhance(contrast)
    result.save(path, format="JPEG", quality=96, subsampling=0)
    return json.dumps({
        "rotacion_antihoraria_grados": angle, "volteo_horizontal": flip,
        "zoom": zoom, "traslacion_x_px": tx, "traslacion_y_px": ty,
        "brillo": brightness, "contraste": contrast, "borde": "extension_del_borde",
        "interpolacion": "bicubica", "jpeg_calidad": 96,
    }, ensure_ascii=False, separators=(",", ":"))


def output_row(entry, name, kind, file_hash, recipe, previous=""):
    return {
        "nombre_archivo": name, "clase": entry["clase"], "particion": entry["particion"],
        "tipo_origen": kind, "archivo_fuente": entry["archivo_original"],
        "transformacion": recipe, "grupo_origen": entry["grupo_origen"],
        "sha256": file_hash, "sha256_fuente": entry["sha256_original"],
        "etiqueta_fuente": entry["etiqueta_fuente"], "variedad": entry["variedad"],
        "fuente": entry["fuente"], "archivo_experimental_previo": previous,
    }


def build(source, stage, entries):
    for split in SPLITS:
        for label in CLASSES:
            (stage / split / label).mkdir(parents=True)
    rows, bases = [], []
    for entry in entries:
        kind, split, label = (entry[k] for k in ("tipo", "particion", "clase"))
        if kind != "original" and label == "con_queresa":
            continue
        name = f"{split}/{label}/{Path(entry['archivo']).name}"
        shutil.copyfile(source / entry["archivo"], stage / name)
        rows.append(output_row(entry, name, "original" if kind == "original" else "augmentada",
                               entry["sha256"], entry["transformacion"], entry["archivo"]))
        if split == "train" and label == "con_queresa" and entry["grupo_origen"] != "queensland_archivo":
            with Image.open(source / entry["archivo"]) as raw:
                image = ImageOps.exif_transpose(raw).convert("RGB")
            pad = math.ceil(max(image.size) * 0.23)
            pixels = np.pad(np.asarray(image), ((pad, pad), (pad, pad), (0, 0)), mode="edge")
            bases.append((entry, Image.fromarray(pixels), pad, image.size))

    train = Counter(row["clase"] for row in rows if row["particion"] == "train")
    needed = train["sanas"] - train["con_queresa"]
    if needed < 0 or not bases:
        raise ValueError("El conjunto no permite completar positivos desde sus originales.")
    hashes = {row["sha256"] for row in rows}
    rng = random.Random(42)
    fallback = []
    for index in range(needed):
        entry, image, pad, size = bases[index % len(bases)]
        stem = Path(entry["archivo"]).stem
        name = f"train/con_queresa/aug_bal_{index + 1:03d}_{stem}.jpg"
        path = stage / name
        for _ in range(20):
            recipe = augment(image, pad, size, path, rng)
            file_hash = digest(path)
            if file_hash not in hashes:
                hashes.add(file_hash)
                rows.append(output_row(entry, name, "augmentada", file_hash, recipe))
                break
        else:
            path.unlink()
            fallback.append((index, entry))
    for index, entry in fallback:
        name = f"train/con_queresa/dup_bal_{index + 1:03d}_{Path(entry['archivo']).name}"
        shutil.copyfile(source / entry["archivo"], stage / name)
        rows.append(output_row(entry, name, "duplicada", entry["sha256"], '{"copia_exacta":true}'))
    return sorted(rows, key=lambda row: row["nombre_archivo"])


def verify(stage, entries, rows):
    names = {row["nombre_archivo"] for row in rows}
    actual = {path.relative_to(stage).as_posix() for split in SPLITS
              for path in (stage / split).rglob("*") if path.is_file()}
    if names != actual or len(names) != len(rows):
        raise ValueError("Archivos y manifiesto discordantes.")
    prior = {row["archivo"]: row for row in entries}
    bases = {row["archivo_original"]: row for row in entries if row["tipo"] == "original"}
    retained = [row["archivo_experimental_previo"] for row in rows if row["archivo_experimental_previo"]]
    required = {row["archivo"] for row in entries if row["tipo"] == "original" or row["clase"] == "sanas"}
    if set(retained) != required or len(retained) != len(required):
        raise ValueError("Los originales o las variantes sanas conservadas difieren de la entrada.")
    groups, counts, hashes = defaultdict(set), Counter(), set()
    for row in rows:
        name, label, split, kind = (row[k] for k in ("nombre_archivo", "clase", "particion", "tipo_origen"))
        base = bases[row["archivo_fuente"]]
        if Path(name).parts[:2] != (split, label) or kind not in ("original", "augmentada", "duplicada"):
            raise ValueError(f"Clase, partición o tipo inválido: {name}")
        for key in ("clase", "particion", "grupo_origen", "etiqueta_fuente"):
            if not row[key] or row[key] != base[key]:
                raise ValueError(f"Linaje discordante: {name}")
        file_hash = digest(stage / name)
        if row["sha256_fuente"] != base["sha256"] or file_hash != row["sha256"]:
            raise ValueError(f"Hash discordante: {name}")
        if kind in ("original", "duplicada") and file_hash != base["sha256"]:
            raise ValueError(f"Se modificó una copia exacta: {name}")
        if kind != "original" and (split != "train" or not row["transformacion"]):
            raise ValueError(f"Variante fuera de entrenamiento o sin receta: {name}")
        if previous := row["archivo_experimental_previo"]:
            if file_hash != prior[previous]["sha256"]:
                raise ValueError(f"Se alteró un archivo conservado: {name}")
        if kind != "duplicada":
            if file_hash in hashes:
                raise ValueError(f"Duplicado sin marcar: {name}")
            hashes.add(file_hash)
        with Image.open(stage / name) as image:
            image.load()
        groups[row["grupo_origen"]].add(split)
        counts[split, label, kind] += 1
    train = [sum(n for (s, c, _), n in counts.items() if s == "train" and c == label)
             for label in CLASSES]
    if any(len(splits) != 1 for splits in groups.values()) or not train[0] or train[0] != train[1]:
        raise ValueError("Fuga de grupos o entrenamiento desbalanceado.")
    return counts


def summary(stage, before, after):
    lines = [
        "# CropScan · Balanceo de entrenamiento", "",
        "Entrada: dataset_900_experimental. El conjunto tenía 450 archivos por clase en total.",
        "Entrenamiento tenía más positivos por las variantes de la corrida anterior.", "",
        "| Partición | Sanas antes | Con queresa antes | Sanas después | Con queresa después |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    for split in SPLITS:
        nums = [sum(n for (s, c, _), n in counts.items() if (s, c) == (split, label))
                for counts in (before, after) for label in CLASSES]
        lines.append(f"| {split} | {nums[0]} | {nums[1]} | {nums[2]} | {nums[3]} |")
    totals = [sum(n for (_, c, _), n in counts.items() if c == label)
              for counts in (before, after) for label in CLASSES]
    lines.append(f"| Total | {totals[0]} | {totals[1]} | {totals[2]} | {totals[3]} |")
    originals = [sum(n for (_, c, k), n in after.items() if c == label and k == "original")
                 for label in CLASSES]
    lines += [
        "", f"- Originales etiquetados: {originals[0]} sanas y {originals[1]} con queresa.",
        f"- Originales en entrenamiento: {after['train', 'sanas', 'original']} sanas y "
        f"{after['train', 'con_queresa', 'original']} con queresa.",
        f"- Aumentos positivos nuevos: {after['train', 'con_queresa', 'augmentada']}. "
        f"Aumentos sanos previos conservados: {after['train', 'sanas', 'augmentada']}.",
        f"- Duplicaciones exactas nuevas: {after['train', 'con_queresa', 'duplicada']}.",
        f"- Total de imágenes: {sum(after.values())}.", "",
        "Los 444 aumentos positivos previos quedaron en el dataset anterior. La carpeta nueva",
        "se generó desde tres fotos de Casma con semilla 42. El original histórico de Queensland",
        "se conservó sin generar variantes. Se usaron rotaciones de hasta 10°, volteo horizontal,",
        "brillo y contraste de 0,94 a 1,06, zoom de 0,97 a 1,04 y traslación de hasta 3 % por eje.",
        "El borde se extiende al aplicar la transformación geométrica.", "",
        "Se verificaron hashes, trazabilidad y decodificación de todas las imágenes. Ningún grupo",
        "cruza particiones. Validación y prueba conservan los mismos originales y una positiva",
        "cada una. El balance de archivos no agrega muestras independientes.", "",
        "La carpeta contiene train, validation y test. Usar explícitamente el orden de clases",
        "sanas y con_queresa. Las rutas de nombre_archivo son relativas a este directorio y",
        "archivo_fuente es relativo a .tooling/dataset-queresa. Este formato es para un nuevo",
        "experimento. El script de la corrida 01 mantiene su verificación de 900 archivos.",
        "No se ejecutó entrenamiento.", "",
    ]
    (stage / "RESUMEN_BALANCEO.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset", type=Path)
    args = parser.parse_args()
    source = args.dataset.resolve()
    target = source.parent / "dataset_balanceado_entrenamiento"
    if target.exists():
        parser.error(f"El destino ya existe: {target}")
    entries, _ = verify_data(source)
    before = Counter((r["particion"], r["clase"], r["tipo"]) for r in entries)
    target.mkdir()
    try:
        rows = build(source, target, entries)
        counts = verify(target, entries, rows)
        write_rows(target / "manifest_balanceado.csv", rows, FIELDS)
        summary(target, before, counts)
    except BaseException:
        if target.is_dir() and target.resolve().parent == source.parent:
            shutil.rmtree(target)
        raise
    print(target)
    for key, number in sorted(counts.items()):
        print(*key, number)


if __name__ == "__main__":
    main()
