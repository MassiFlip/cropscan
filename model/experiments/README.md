# Experimentos de CropScan

La configuración `config_cnn_900.json` y el script `../train_experimental.py` ejecutan una prueba técnica con `.tooling/dataset-queresa/dataset_900_experimental`. El prechequeo valida el manifiesto experimental, los hashes de las imágenes y sus grupos, el linaje respecto al inventario original y la ausencia de aumentos en validación o prueba. El script reutiliza la arquitectura de `model/train.py`. El entrenamiento de campo sigue usando su propio manifiesto y sus requisitos de aceptación.

## Reproducción en Windows

Desde la raíz de CropScan, con Python 3.13 de 64 bits:

```powershell
python -m venv .tooling/cropscan-exp-venv
$pythonExp = ".tooling/cropscan-exp-venv/Scripts/python.exe"
& $pythonExp -m pip install -r model/experiments/requirements.txt
& $pythonExp model/train_experimental.py .tooling/dataset-queresa/dataset_900_experimental model/experiments/cnn_900_repeticion
```

La configuración fija la semilla, el ancho de la CNN, las épocas, el tamaño de lote y la tasa de aprendizaje. El script utiliza CPU con operaciones deterministas. Los resultados incluyen versiones y hashes de entrada para comparar ejecuciones. Usa un directorio nuevo para conservar las ejecuciones anteriores.

## Contrato del archivo experimental

- Entrada RGB `float32` de forma `[1, 160, 160, 3]` con rango 0–255. El modelo normaliza internamente.
- Salida `float32` de forma `[1, 2]`, en orden `no_visible_signs`, `possible_scale`.
- El TFLite se valida con dos originales de prueba y se compara con la salida Keras. La exportación usa pesos FP16. La configuración no incluye un umbral agronómico.

Los resultados son descriptivos. El modelo queda en la carpeta del experimento para una prueba técnica posterior y carece de validación para diagnóstico.
