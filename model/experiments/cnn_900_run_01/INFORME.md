# CropScan · Experimento CNN 900

27 de noviembre de 2026. Se completaron seis épocas en CPU, la evaluación descriptiva y la exportación del modelo experimental. El intérprete TFLite cargó el modelo y produjo salidas comparables a las de Keras en dos originales de prueba. No se modificaron imágenes, el pipeline de campo ni la aplicación.

## Datos verificados antes de entrenar

| Partición | Sanas originales | Sanas aumentadas | Con queresa originales | Con queresa aumentadas | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Entrenamiento | 252 | 106 | 4 | 444 | 806 |
| Validación | 7 | 0 | 1 | 0 | 8 |
| Prueba | 85 | 0 | 1 | 0 | 86 |
| **Total** | **344** | **106** | **6** | **444** | **900** |

- Se validaron los hashes de los 900 archivos, las etiquetas de su fuente y la trazabilidad contra el inventario principal. Los siete grupos quedaron en una sola partición cada uno. Validación y prueba contienen solo originales y ninguna de las 22 fotos pendientes de Drive entró al experimento.
- De las 346 sanas del inventario se excluyeron dos. **WA0149** es una probable recodificación de **WA0137**, que se incluyó. **WA0181** es casi idéntica a **WA0193**, cuya etiqueta está en conflicto. Se conservaron 344 originales sanas.
- Se comprobó que los **444 aumentos positivos** tienen como base exclusivamente `uns_anexo1_A.jpg`, `uns_anexo1_B.jpg` y `uns_anexo1_C.jpg`, 148 por foto. Los tres archivos originales están en entrenamiento y pertenecen al mismo grupo de Casma. La cuarta positiva de entrenamiento, una referencia histórica, no generó aumentos.
- Se ejecutó `model/train.py --check-only` con el manifiesto experimental. El prechequeo de campo rechazó ese formato como se esperaba. El [registro](status.json) conserva el SHA-256 del pipeline de campo, del script y de los manifiestos. Se confirmó que `model/train.py` mantuvo el mismo hash durante la ejecución.

## Configuración y resultados observados

Se reutilizó la arquitectura del pipeline de campo, una CNN de 12 690 parámetros con convoluciones separables y ancho base 16. Se usó RGB de 160 × 160, Adam con tasa de 0,001, pérdida de entropía cruzada categórica dispersa, lote de 16, semilla 42 y seis épocas fijas. La pérdida de entrenamiento usó pesos por clase de 1,1257 para sanas y 0,8996 para con queresa. La exactitud se calculó por archivo sin ponderar. El archivo TFLite usa los pesos de la última época. No se ajustó un umbral ni se seleccionó un modelo a partir de prueba. [Configuración](../config_cnn_900.json)

| Época | Pérdida entrenamiento | Exactitud entrenamiento | Pérdida validación | Exactitud validación |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 0,6618 | 63,03 % | 0,6024 | 6/8 |
| 2 | 0,1929 | 97,52 % | 3,9180 | 4/8 |
| 3 | 0,000677 | 100 % | 5,3224 | 4/8 |
| 4 | 0,000217 | 100 % | 5,7261 | 4/8 |
| 5 | 0,000124 | 100 % | 6,1958 | 4/8 |
| 6 | 0,000083 | 100 % | 6,4611 | 4/8 |

La caída en validación al tiempo que cae la pérdida de entrenamiento es consistente con sobreajuste a estas fuentes de imágenes. En la prueba original se observó pérdida 4,7701 y **30 aciertos de 86** usando la clase de mayor probabilidad. El modelo marcó **56 de las 85 sanas** como positivas. Validación y prueba contienen una sola positiva original cada una. Estos números describen la corrida y carecen de soporte para estimar recall o F1 de campo. [Historial CSV](history.csv) · [Curvas](curvas.png)

## Exportación y comprobación

- [Modelo TFLite experimental](cropscan_experimental.tflite) de 32 648 bytes, con pesos FP16. Entrada RGB `float32 [1, 160, 160, 3]` en rango 0–255 y salida `float32 [1, 2]` en orden `no_visible_signs`, `possible_scale`. El modelo incluye la normalización.
- La inferencia se ejecutó en CPU sobre una sana y una positiva originales de prueba. La diferencia absoluta máxima entre TFLite y Keras fue **0,00000823**. Esa cercanía comprueba la conversión, incluso cuando ambos modelos clasifican mal una de las dos fotos.
- Quedaron guardados los pesos en formato [Keras](cropscan_experimental.keras), el [registro técnico](status.json) y el [log de ejecución](ejecucion.log).

## Incidencias y pendientes

No falló ninguna etapa experimental. Keras avisó que el parámetro de barajado de `fit` es ignorado para un `tf.data.Dataset`. El conjunto de entrenamiento ya se barajó explícitamente con su semilla y validación y prueba conservaron su orden. TensorFlow también emitió una advertencia de obsolescencia del intérprete Python. La carga y las inferencias finalizaron correctamente con la versión instalada. El entorno fue Python 3.13.5, TensorFlow 2.20.0, Keras 3.15.1 y Matplotlib 3.10.8. [Cómo reproducir la ejecución](../README.md)

La comprobación en Flutter/Android sigue pendiente. El artefacto queda identificado como experimental y carece de umbral agronómico calibrado. Para evaluar el modelo de campo hacen falta fotos de Naval de Huaral validadas por un especialista, con suficientes positivos independientes y parcelas separadas en validación y prueba.

La corrida se repitió en el mismo entorno y con la misma configuración. Coincidieron exactamente las seis épocas de métricas, la matriz de prueba, las salidas de las dos inferencias y el SHA-256 del TFLite. [Comprobación de reproducibilidad](reproducibilidad.json)
