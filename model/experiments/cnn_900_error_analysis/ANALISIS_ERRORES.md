# CropScan · Análisis de errores de la CNN experimental

27 de noviembre de 2026

**La matriz de la corrida 01 se reprodujo por completo.** Los modelos guardados de Keras y TFLite predijeron las mismas clases en 86 archivos originales de prueba. Identificamos 56 sanas del inventario clasificadas como posibles queresas y 29 sanas acertadas. Los resultados describen este lote. Las etiquetas provienen de las fuentes y la prueba carece de validación agronómica para palta Naval de Huaral.

## Qué se revisó

Se verificaron el manifiesto experimental, los hashes de los archivos y el linaje de los aumentos. Se abrió el modelo de la época 6 y se utilizó el mismo `argmax` de la corrida. Las fotos de prueba no se usaron para elegir un umbral, seleccionar una época ni ajustar hiperparámetros. El entrenamiento, los modelos guardados, los archivos originales y las etiquetas se conservaron.

La [galería](galeria_falsos_positivos.html) incluye los 56 errores con su nombre, etiqueta de la fuente y las dos probabilidades de Keras. Cada miniatura enlaza al archivo local. También incluye las 29 sanas acertadas para comparar. Las probabilidades completas de ambos intérpretes están en [predicciones de prueba](predicciones_prueba.csv) y [lista de falsos positivos](falsos_positivos.csv).

## Matriz y métricas descriptivas

| Etiqueta del inventario | Predicha sana | Predicha con queresa | Total |
| --- | ---: | ---: | ---: |
| Sana | 29 | 56 | 85 |
| Con queresa | 0 | 1 | 1 |

| Clase | Precisión | Recall descriptivo | F1 |
| --- | ---: | ---: | ---: |
| Sana | 100,00 % (29/29) | 34,12 % (29/85) | 50,88 % |
| Con queresa | 1,75 % (1/57) | 100,00 % (1/1) | 3,45 % |

- Exactitud de **34,88 %** (30/86), exactitud balanceada de **67,06 %** y F1 macro de **27,16 %**.
- Tasa de falsos positivos de **65,88 %** (56/85). La puntuación mediana de `possible_scale` en esos 56 errores fue **0,99943**. En 46 casos fue al menos 0,99. Este conteo describe la distribución de salidas con la regla original y no se usó como umbral.
- Una regla que siempre devolviera “sana” acertaría 85/86 en este lote desequilibrado y perdería la única positiva. El recall positivo de 1/1 no aporta una estimación confiable de sensibilidad en campo. Las 85 sanas corresponden al mismo lote de origen y no acreditan 85 frutos independientes.

Los valores sin redondear y el orden de filas y columnas están en [métricas](metricas.json).

## Patrones observados en las sanas de prueba

La revisión del fondo se hizo sobre miniaturas numeradas sin puntuaciones y se cruzó después con las predicciones. El grupo neutro claro incluye algunas fotos con cartón marginal. El grupo de cartón dominante corresponde a tomas donde este ocupa una parte importante del encuadre.

| Fondo dominante observado | Falsos positivos | Sanas acertadas |
| --- | ---: | ---: |
| Superficie neutra clara | 25 | 29 |
| Cartón dominante, con o sin texto | 22 | 0 |
| Panel oscuro y superficie clara | 6 | 0 |
| Empaques | 3 | 0 |

**Iluminación.** La luma media mediana del cuadro de entrada fue 133,6/255 en los falsos positivos y 160,1/255 entre las sanas acertadas. Al comparar solo las fotos con fondo neutro claro, fue 125,2 frente a 160,1. Es una asociación observada. La medición reúne iluminación, color del fruto, sombra, fondo y área del encuadre ocupada por cada elemento. No permite atribuir los errores a subexposición del fruto.

**Color y textura.** Se observan errores en frutos verdes, oscuros y pardos. Por ejemplo, `agro227_1.png` es verde y recibió 0,99249 en `possible_scale`. En las tomas de aspecto pardo oscuro, `agro227_IMG_20250814_182138.jpg` fue acertada con 0,15549, mientras `agro227_IMG_20250814_182158.jpg` falló con 0,99637. Las tomas difieren también en contexto y encuadre. La saturación mediana del cuadro completo fue 0,252 frente a 0,148. Dentro del fondo neutro fue 0,161 frente a 0,148. La varianza mediana del laplaciano fue mayor en errores al agrupar todos los fondos, 353,5 frente a 313,4, y menor al restringir a fondo neutro, 288,3 frente a 313,4. Esta señal mide cambios de intensidad del encuadre. Incluye bordes del fondo, textura y nitidez, y no aísla detalles de la piel.

**Tamaño, resolución y calidad.** Ambos grupos tuvieron la misma resolución mediana de 12,53 MP y lado menor mediano de 3072 px. Los errores incluyen archivos de resolución baja y alta. Las 11 tomas horizontales y los 16 PNG de este lote fueron falsos positivos. Todos los PNG eran RGBA con alfa opaco, y ninguna sana tenía perfil ICC incrustado u orientación EXIF que requiriera giro. El formato y la orientación se concentran en sublotes y encuadres distintos. El redimensionamiento a 160 × 160 comprime detalles y puede deformar encuadres rectangulares. La revisión actual no establece que la resolución, la nitidez, el formato o la orientación expliquen los errores.

**Variedad.** Las 85 sanas pertenecen a Agrocomputation 227 y carecen de cultivar documentado. La única positiva de prueba figura como Hass y proviene de otra fuente. No es posible calcular errores por variedad ni inferir una variedad por la apariencia.

[Anotaciones de fondo por archivo](revision_fondos.csv) · [Medianas, cuartiles y metadatos de imagen](patrones_descriptivos.json)

## Preprocesamiento y origen del sobreajuste

- **Comprobado en Python.** Entrenamiento y evaluación corrigen EXIF con Pillow, convierten a RGB y redimensionan directamente a 160 × 160 con interpolación bilineal. El modelo recibe RGB en orden R, G, B con rango 0–255 y aplica internamente `Rescaling(1 / 255)`. La salida de dos probabilidades sigue el orden `no_visible_signs`, `possible_scale`.
- **Comprobado en Android.** El flujo experimental entrega los bytes al decodificador Android, solicita sRGB, fija 160 × 160 y empaca valores RGB `float32` en el mismo rango. No vuelve a dividir los valores por 255. En el emulador, dos PNG con los mismos píxeles de Python coincidieron a ocho decimales. Con el JPEG original se observó una diferencia de alrededor de 0,000033 en la puntuación positiva después del redimensionamiento nativo. No se compararon los 86 originales individualmente en Android. En Python, Keras y TFLite reprodujeron el `argmax` de los 86 archivos, con diferencia absoluta máxima de 0,000334. Los falsos positivos ya aparecen en Keras antes de exportar.
- **Comprobado en los datos.** En entrenamiento hay 252 sanas originales y 106 aumentos, todos del lote de estudio Fuerte de Chapingo. Hay 4 originales positivos, tres del mismo grupo de Casma y una referencia histórica. Los 444 aumentos positivos, 148 por original de Casma, conservan el fruto, la escena y la cámara de las tomas base. Las rotaciones, volteos, variaciones moderadas de luz y zoom no agregan parcelas, frutos ni dispositivos. Los 86 archivos de prueba son originales.
- **Comprobado en la iluminación de entrenamiento.** Más del 65 % del cuadro tenía luma igual o superior a 243/255 en 236 de las 252 sanas originales, 72 de las 106 sanas aumentadas y ninguna de las 448 positivas. El contraste entre clases ya estaba presente en las originales y persiste en las variantes. Es una señal de captura que la CNN pudo aprovechar.
- **Comprobado en las curvas.** En la época 6 la exactitud de entrenamiento llegó a 100 %, pero la de validación quedó en 4/8. La pérdida de validación subió de 0,6024 a 6,4611. Ese patrón muestra un deterioro fuera del entrenamiento en el pequeño lote de validación.
- **Hipótesis para distinguir.** La CNN pudo apoyarse en fondos, contraste, escala del fruto o textura vinculados a la fuente. También pudo memorizar detalles de las tres escenas positivas repetidas. La separación por grupo evita reutilizar esas escenas en prueba, pero deja variedad, cámara, iluminación y procedencia confundidas con la clase. Los conteos muestran asociaciones y las curvas muestran sobreajuste en la corrida. Ninguna observación identifica qué señal usa la CNN ni demuestra una causa individual.

[Código de entrenamiento experimental](../../train_experimental.py) · [Prueba Android](../ANDROID_EXPERIMENTAL.md) · [Curvas de la corrida 01](../cnn_900_run_01/curvas.png) · [Comparación visual de originales y aumentos](comparacion_originales_aumentos.jpg)

## Cambios para el siguiente entrenamiento

1. Recopilar primero originales Naval validados de ambas clases en las mismas parcelas, cámaras y condiciones de fondo y luz. Priorizar positivos independientes y sanas de campo de piel oscura o rugosa, con rasgos normales o marcas que el especialista confirme como negativos. El [plan de captura](PLAN_CAPTURA.md) especifica las vistas y los metadatos.
2. Construir nuevas particiones por unidad productiva antes de aumentar datos. Reservar suficientes positivos independientes en una validación nueva y en una prueba nueva. Mantener el test de la corrida 01 como referencia histórica.
3. Limitar el peso de las variantes de cada original o grupo y evaluar por fruto o parcela cuando exista esa trazabilidad. Comparar primero con un conjunto de originales de entrenamiento que represente ambos tipos de captura. Medir por separado el efecto de la resolución, el encuadre y el fondo en validación nueva, con comparaciones de la misma fruta en distintas condiciones y de las dos clases en condiciones equivalentes.
4. Verificar el preprocesamiento con referencias PNG y JPEG en Python y Android. Medir las diferencias de redimensionamiento y del área visible de la fruta usando un conjunto nuevo y la configuración que se decida antes de evaluar. La selección de arquitectura, época y umbral corresponde a esa validación nueva.

Para regenerar las predicciones y la galería con las [dependencias del experimento](../requirements.txt), ejecutar desde la raíz de CropScan:

```powershell
python model/experiments/cnn_900_error_analysis/reproducir.py .tooling/dataset-queresa/dataset_900_experimental model/experiments/cnn_900_run_01 .tooling/cnn_900_error_analysis_reproduccion
```
