"""Inventory and triage CropScan images without editing the dataset."""

import argparse
import csv
import hashlib
import json
from collections import Counter, defaultdict
from itertools import combinations
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

try:
    from pillow_heif import register_heif_opener
except ImportError:
    pass
else:
    register_heif_opener()


CLASSES = ("sanas", "con_queresa", "por_revisar")
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff", ".heic"}
REQUIRED_COLUMNS = {
    "archivo", "clase", "etiqueta_fuente", "variedad", "lugar", "evidencia",
    "original", "autores", "licencia", "fuente", "ancho", "alto", "sha256",
}
FIELD_COLUMNS = (
    "photo", "label", "unit", "split", "quality_ok",
    "cultivar", "location", "source", "permission_ref", "reviewer",
)
AUDIT_COLUMNS = (
    "ancho_visual", "alto_visual", "sha256_real", "nitidez", "fraccion_oscura",
    "fraccion_clara", "alertas_tecnicas", "observacion_visual", "alertas_agronomicas",
    "cola", "error",
)
PAIR_COLUMNS = ("archivo_a", "archivo_b", "criterio", "distancia_phash", "distancia_dhash",
                "diferencia_rgb")
DCT = np.cos(np.pi / 32 * np.arange(8)[:, None] * (np.arange(32) + 0.5))


def write_csv(path, rows, fields):
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def image_hashes(gray):
    low = DCT @ np.asarray(gray.resize((32, 32), Image.Resampling.LANCZOS)) @ DCT.T
    frequencies = low.ravel()[1:]
    gradients = np.diff(np.asarray(gray.resize((9, 8), Image.Resampling.LANCZOS),
                                   dtype=np.int16), axis=1)
    return (
        int.from_bytes(np.packbits(frequencies > np.median(frequencies)).tobytes(), "big"),
        int.from_bytes(np.packbits(gradients > 0).tobytes(), "big"),
    )


def inspect_image(root, entry, flags):
    name = entry["archivo"]
    info = dict.fromkeys(("ancho_visual", "alto_visual", "sha256_real", "nitidez",
                          "fraccion_oscura", "fraccion_clara", "error"), "")
    path = (root / name).resolve()
    if not path.is_relative_to(root) or not path.is_file():
        flags.add("archivo_ausente_o_fuera_del_dataset")
        return info, None, None
    try:
        with path.open("rb") as stream:
            info["sha256_real"] = hashlib.file_digest(stream, "sha256").hexdigest()
        if entry["sha256"] and entry["sha256"].lower() != info["sha256_real"]:
            flags.add("sha256_distinto_del_manifiesto")
        with Image.open(path) as photo:
            photo.verify()
        with Image.open(path) as photo:
            photo.load()
            if entry["ancho"] and entry["alto"] and (
                entry["ancho"], entry["alto"]
            ) != tuple(map(str, photo.size)):
                flags.add("dimensiones_distintas_del_manifiesto")
            rgb = ImageOps.exif_transpose(photo).convert("RGB")
        width, height = rgb.size
        info.update(ancho_visual=width, alto_visual=height)
        pixels = hashlib.sha256(rgb.tobytes()).hexdigest()
        gray = rgb.convert("L")
        probe = np.asarray(gray.resize((256, 256), Image.Resampling.BILINEAR), dtype=np.float32)
        interior = probe[1:-1, 1:-1]
        laplacian = (probe[:-2, 1:-1] + probe[2:, 1:-1] + probe[1:-1, :-2]
                     + probe[1:-1, 2:] - 4 * interior)
        sharpness = float(laplacian.var())
        dark, light = float((probe <= 12).mean()), float((probe >= 243).mean())
        info.update(nitidez=round(sharpness, 2), fraccion_oscura=round(dark, 4),
                    fraccion_clara=round(light, 4))
        for flagged, reason in (
            (min(width, height) < 224, "lado_menor_224_px"),
            (max(width, height) / min(width, height) > 2.2, "formato_muy_alargado"),
            (sharpness < 45, "posible_desenfoque"),
            (dark > 0.45, "muchos_pixeles_oscuros"),
            (light > 0.65, "fondo_claro_o_sobreexposicion"),
        ):
            if flagged:
                flags.add(reason)
        sample_rgb = np.asarray(rgb.resize((64, 64), Image.Resampling.BILINEAR), dtype=np.int16)
        if float(np.ptp(sample_rgb, axis=2).mean()) < 2:
            flags.add("sin_color")
        thumbnails = [rgb.resize((72, 72), Image.Resampling.LANCZOS)]
        for _ in range(3):
            thumbnails.append(thumbnails[-1].transpose(Image.Transpose.ROTATE_90))
        thumbnails += [image.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for image in thumbnails]
        hashes = [
            (*image_hashes(image.convert("L")),
             np.asarray(image.resize((48, 48), Image.Resampling.BILINEAR), dtype=np.int16))
            for image in thumbnails
        ]
        return info, (width, height, pixels), hashes
    except (OSError, SyntaxError, ValueError, Image.DecompressionBombError) as error:
        flags.add("archivo_danado_o_no_compatible")
        info["error"] = str(error)
        return info, None, None


def visual_distance(left, right):
    p_hash, d_hash, rgb = left
    other_p_hash, other_d_hash, other_rgb = right
    p = (p_hash ^ other_p_hash).bit_count()
    d = (d_hash ^ other_d_hash).bit_count()
    if p > 8 or d > 8:
        return None
    foreground = np.any((rgb < 230) | (other_rgb < 230), axis=2)
    difference = np.abs(rgb - other_rgb)
    # White studio backgrounds are common and should not dominate this comparison.
    mean = float(difference[foreground].mean() if foreground.any() else difference.mean())
    return (p, d, mean) if mean <= 8 else None


def duplicate_pairs(names, info, fingerprints, flags):
    pairs = []
    for a, b in combinations(names, 2):
        ia, ib = info[a], info[b]
        a_pixels, b_pixels = fingerprints[a][0], fingerprints[b][0]
        criterion, phash, dhash, rgb_diff = "", "", "", ""
        if ia["sha256_real"] and ia["sha256_real"] == ib["sha256_real"]:
            criterion = "bytes_identicos"
        elif a_pixels is not None and a_pixels == b_pixels:
            criterion = "pixeles_identicos"
        elif fingerprints[a][1] and fingerprints[b][1]:
            matches = [match for variant in fingerprints[b][1]
                       if (match := visual_distance(fingerprints[a][1][0], variant)) is not None]
            if matches:
                phash, dhash, rgb_diff = min(matches, key=lambda match: (match[2], *match[:2]))
                rgb_diff = round(rgb_diff, 2)
                criterion = "parecido_visual"
        if criterion:
            flags[a].add(criterion)
            flags[b].add(criterion)
            pairs.append(dict(archivo_a=a, archivo_b=b, criterio=criterion,
                              distancia_phash=phash, distancia_dhash=dhash, diferencia_rgb=rgb_diff))
    return pairs


def audit(root, output, observations=None):
    root = root.resolve()
    if output.resolve().is_relative_to(root):
        raise ValueError("La salida de auditoría debe quedar fuera del dataset original.")
    manifest = root / "manifest.csv"
    with manifest.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        columns = reader.fieldnames or []
        if not REQUIRED_COLUMNS.issubset(columns):
            raise ValueError("Faltan columnas en el manifiesto: " +
                             ", ".join(sorted(REQUIRED_COLUMNS.difference(columns))))
        original = [{key: (row.get(key) or "").strip() for key in columns} for row in reader]
    by_path = {row["archivo"]: row for row in original}
    if len(by_path) != len(original) or "" in by_path:
        raise ValueError("Hay rutas vacías o filas repetidas en el manifiesto.")
    if any(row["clase"] not in CLASSES for row in original):
        raise ValueError("Hay una clase desconocida en el manifiesto.")
    notes = {}
    if observations is not None:
        with observations.open(encoding="utf-8-sig", newline="") as stream:
            for row in csv.DictReader(stream):
                name, note = row["archivo"], row["observacion"].strip()
                if name not in by_path or name in notes or not note:
                    raise ValueError(f"Observación visual inválida para {name!r}.")
                notes[name] = note
    disk = {
        path.relative_to(root).as_posix()
        for label in CLASSES
        for path in (root / label).rglob("*")
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    }
    unlisted = sorted(disk.difference(by_path))
    unlisted_entries = [dict(archivo=name, alerta="sin_fila_en_manifiesto") for name in unlisted]
    flags = defaultdict(set)
    info, fingerprints = {}, {}
    for name, entry in by_path.items():
        if Path(name).parts[0] != entry["clase"]:
            flags[name].add("carpeta_y_clase_distintas")
        image_info, pixel_key, hashes = inspect_image(root, entry, flags[name])
        info[name] = image_info
        fingerprints[name] = pixel_key, hashes
    pairs = duplicate_pairs(by_path, info, fingerprints, flags)

    results = []
    for name, row in by_path.items():
        note = notes.get(name, "")
        if note:
            flags[name].add("observacion_visual")
        variety = row["variedad"].casefold()
        agronomy = ["sin_validacion_agronomica_del_proyecto", "sin_parcela_identificada"]
        if not row["lugar"]:
            agronomy.append("lugar_de_captura_sin_documentar")
        if row["licencia"] == "Material compartido por el equipo":
            agronomy.extend(("origen_de_captura_sin_documentar", "permiso_sin_documentar"))
        elif not row["fuente"] or not row["autores"] or not row["licencia"]:
            agronomy.append("origen_o_permiso_sin_documentar")
        if not variety:
            agronomy.append("variedad_sin_documentar")
        elif variety not in {"naval", "nabal"}:
            agronomy.append("variedad_distinta_de_naval")
        if row["clase"] == "por_revisar":
            agronomy.append("etiquetas_en_conflicto" if row["etiqueta_fuente"]
                            else "sin_etiqueta")
        else:
            agronomy.append("etiqueta_de_fuente")
        queue = "revision_tecnica" if flags[name] else "validacion_agronomica"
        results.append(dict(row, **info[name], cola=queue, observacion_visual=note,
                            alertas_tecnicas=";".join(sorted(flags[name])),
                            alertas_agronomicas=";".join(agronomy)))
    summary = {
        "sha256_manifiesto": hashlib.sha256(manifest.read_bytes()).hexdigest(),
        "clases": {label: sum(row["clase"] == label for row in results) for label in CLASSES},
        "por_cola": {queue: dict(Counter(row["clase"] for row in results if row["cola"] == queue))
                     for queue in ("revision_tecnica", "validacion_agronomica")},
        "alertas_tecnicas": Counter(flag for values in flags.values() for flag in values),
        "alertas_agronomicas": Counter(flag for row in results
                                       for flag in row["alertas_agronomicas"].split(";")),
        "pares": Counter(pair["criterio"] for pair in pairs),
        "archivos_sin_manifiesto": len(unlisted),
        "archivos_en_disco": len(disk),
    }
    output.mkdir(parents=True, exist_ok=False)
    write_csv(output / "inventario.csv", results, [*columns, *AUDIT_COLUMNS])
    for queue in summary["por_cola"]:
        write_csv(output / f"{queue}.csv", (row for row in results if row["cola"] == queue),
                  [*columns, *AUDIT_COLUMNS])
    write_csv(output / "pares_duplicados.csv", pairs, PAIR_COLUMNS)
    write_csv(output / "sin_manifiesto.csv", unlisted_entries, ("archivo", "alerta"))
    write_csv(output / "validacion_campo_plantilla.csv", [], FIELD_COLUMNS)
    (output / "resumen.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
                                         encoding="utf-8")
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--observations", type=Path, help="CSV con archivo y observacion")
    args = parser.parse_args()
    print(json.dumps(audit(args.dataset, args.output, args.observations), ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
