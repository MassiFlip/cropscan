# CropScan · Comparación experimental de v1 y v2

**MODELO EXPERIMENTAL — RESULTADOS NO VALIDADOS**

El balanceo de entrenamiento dejó un falso positivo adicional en las mismas 85 fotos sanas de prueba. V2 corrigió un error de v1 y cometió dos nuevos. Ambos modelos acertaron la única foto positiva. Conviene conservar v1 como referencia experimental y archivar v2 como comparación reproducible. La diferencia de un caso en este conjunto ya examinado es descriptiva.

## Datos y configuración

| Partición | v1 sanas | v1 con queresa | v2 sanas | v2 con queresa |
| --- | ---: | ---: | ---: | ---: |
| Entrenamiento | 358 | 448 | 358 | 358 |
| Validación | 7 | 1 | 7 | 1 |
| Prueba | 85 | 1 | 85 | 1 |
| Total | 450 | 450 | 450 | 360 |

Se comprobó la correspondencia de los 810 archivos de v2 con el manifiesto, sus SHA-256, su decodificación y la trazabilidad de las etiquetas. Los siete grupos registrados quedaron confinados a su partición. Entrenamiento incluyó 252 originales sanas y 106 aumentos sanos conservados de v1, más cuatro originales con queresa y 354 aumentos positivos. Cada una de tres fotos de Casma generó 118 aumentos. La cuarta foto positiva de entrenamiento, una imagen histórica de Queensland, se usó como original. Se incluyeron cero duplicados exactos y cero fotografías del lote pendiente.

Validación y prueba contienen exclusivamente originales. Las 94 fotografías tienen el mismo SHA-256, grupo y etiqueta que en v1. Los tensores preprocesados también coincidieron elemento por elemento. El [registro de ejecución](status.json) conserva los conteos y hashes de los manifiestos.

Se reutilizaron la CNN de 12 690 parámetros, la semilla 42 y las seis épocas fijas. El preprocesamiento aplica orientación EXIF, conversión a RGB, redimensionamiento bilineal a 160 × 160 y escalado interno por 1/255. Se mantuvieron Adam con tasa 0,001, lotes de 16, entropía cruzada categórica dispersa y ejecución determinista en CPU. La regla de pesos por frecuencia se mantuvo y produjo pesos 1,0/1,0 para v2 frente a 1,1257/0,8996 para v1, en orden sana/queresa.

El cambio de dataset redujo los aumentos positivos de 444 a 354 y utilizó una receta de aumentos distinta. Se mantuvieron las mismas fotos originales de entrenamiento. La comparación describe el efecto conjunto de esos cambios y de los pesos resultantes.

## Prueba pareada sobre 86 originales

| Métrica descriptiva | v1 | v2 |
| --- | ---: | ---: |
| Aciertos | 30/86 | 29/86 |
| Exactitud | 34,88 % | 33,72 % |
| F1 macro | 0,2716 | 0,2647 |
| Sanas clasificadas como posible queresa | 56/85 (65,88 %) | 57/85 (67,06 %) |
| Positivas clasificadas como sanas | 0/1 | 0/1 |

Las matrices tienen filas de etiqueta real y columnas de predicción. En ambos ejes el orden es sana y con queresa.

| Modelo | Real sana → sana | Real sana → posible queresa | Real con queresa → sana | Real con queresa → posible queresa |
| --- | ---: | ---: | ---: | ---: |
| v1 | 29 | 56 | 0 | 1 |
| v2 | 28 | 57 | 0 | 1 |

De las 85 sanas, 55 fueron falsos positivos en ambos modelos, 27 se clasificaron correctamente en ambos, una pasó de error a acierto y dos pasaron de acierto a error. El [CSV de predicciones pareadas](predicciones_prueba_comparadas.csv) identifica cada foto con su etiqueta, grupo, puntuaciones y cambio observado. Las clases se obtuvieron por la salida de mayor valor, sin ajustar umbrales. Para ambos modelos se usaron los pesos de la sexta época.

## Curvas y sobreajuste

| Indicador | v1 | v2 |
| --- | ---: | ---: |
| Exactitud de entrenamiento al final | 100 % | 100 % |
| Exactitud de validación al final | 50 % | 50 % |
| Brecha de exactitud al final | 50 puntos porcentuales | 50 puntos porcentuales |
| Pérdida de entrenamiento al final | 0,00008268 | 0,00005368 |
| Pérdida de validación en época 1 | 0,6024 | 0,5059 |
| Pérdida de validación en época 6 | 6,4611 | 6,8775 |

Las dos curvas muestran señales de sobreajuste. La pérdida de validación fue mínima en la primera época y aumentó mientras caía la de entrenamiento. V2 empezó con menor pérdida de validación, pero terminó con una pérdida de validación mayor y la misma brecha de exactitud. En estas ocho fotos, ambos modelos obtuvieron al final la matriz `[[3, 4], [0, 1]]`. El balanceo no redujo las señales observadas de sobreajuste. [Curvas comparadas](curvas_comparadas.png) · [Historial v2](history.csv) · [Historial v1](../cnn_900_run_01/history.csv).

## Exportación y comprobación local

V2 se exportó a [Keras](cropscan_experimental.keras) y a [TensorFlow Lite FP16](cropscan_experimental.tflite). La entrada es RGB `float32` de forma `[1, 160, 160, 3]` con valores de 0 a 255. La salida `float32` tiene forma `[1, 2]` y conserva el orden `no_visible_signs`, `possible_scale`.

| Comparación Keras–TFLite de v2 | Originales | Mayor diferencia absoluta por salida | Cambios de clase |
| --- | ---: | ---: | ---: |
| Validación | 8 | 0,002402 | 0 |
| Prueba | 86 | 0,002369 | 0 |

Los 94 casos quedaron dentro de la tolerancia configurada de 0,02. La comprobación se ejecutó en CPU con TensorFlow 2.20.0. La ejecución completó todas las etapas. Se registraron avisos de Keras sobre el parámetro de barajado de `fit` y de TensorFlow sobre la futura retirada de `tf.lite.Interpreter`. El barajado efectivo proviene de `tf.data.Dataset.shuffle`. Se comprobaron los SHA-256 de los dos modelos v1 y el APK previo. [Salida de ejecución](ejecucion.log) · [Métricas y equivalencia](comparacion.json).

## Alcance de los resultados

Hay seis originales positivos en todo el dataset y los 354 aumentos positivos de v2 proceden de tres fotos. Las variantes comparten contenido y condiciones de captura con sus fuentes. Validación y prueba tienen una sola foto positiva cada una. La prueba de 86 fotos ya se había examinado y se usó aquí como comparación exploratoria sobre los mismos casos. La exactitud y el F1 macro describen este conjunto y son insuficientes para estimar efectividad en campo, acreditar objetivos de recall o F1, o respaldar un diagnóstico agrícola.

## Reproducción

Ejecutar desde la raíz de CropScan con Python 3.13.5, TensorFlow 2.20.0, Keras 3.15.1, NumPy 2.5.5, Pillow 13 y Matplotlib 3.10.8. En este equipo los paquetes están en las dos carpetas indicadas en `PYTHONPATH`. Usar una ruta de salida nueva para conservar esta corrida.

```powershell
$env:PYTHONPATH = "$(Resolve-Path '.tooling/cropscan-ml');$(Resolve-Path '.tooling/cropscan-experiments-deps')"
$env:TF_ENABLE_ONEDNN_OPTS = '0'
$python = "$env:LOCALAPPDATA/Programs/Python/Python313/python.exe"
$dataset = '.tooling/dataset-queresa/dataset_balanceado_entrenamiento'
$v1 = 'model/experiments/cnn_900_run_01'
$repeticion = 'model/experiments/cnn_balanced_run_02_repeticion'
& $python model/train_balanced_experimental.py $dataset $repeticion
& $python model/compare_balanced_experiments.py $dataset $v1 $repeticion
```
