# CropScan · Informe técnico consolidado de Machine Learning

**Informe universitario de Gerencia de Proyectos · 28 de noviembre de 2026**

**Alcance actual.** CropScan Experimental demostró en un emulador Android el flujo de captura o selección de una foto, inferencia sin Internet y visualización de las dos salidas del modelo. El estado no concluyente se verificó mediante una simulación identificada en pantalla. La evidencia disponible acredita el funcionamiento técnico del MVP académico. La evaluación agronómica y el cumplimiento de las metas del modelo de campo siguen pendientes. Se conserva v1 como referencia experimental y como modelo del APK de demostración. V2 queda archivada para comparación.

## 1. Objetivos previstos y estado

| Objetivo previsto | Resultado verificable | Estado |
| --- | --- | --- |
| Reunir al menos 300 fotos etiquetadas por clase para evaluar palta Naval de Huaral, con autorización, revisión especializada y al menos 90 % de calidad aprobada | Se prepararon dos datasets experimentales de fruto con 344 originales sanas y 6 positivas en ambos. El inventario carece de confirmación de Naval de Huaral. | Pendiente de campo |
| Alcanzar recall de queresa ≥ 85 % y F1 macro ≥ 0,85 | En la prueba exploratoria, ambas corridas acertaron la única positiva. El F1 macro fue 0,2716 en v1 y 0,2647 en v2. | Cumplimiento sin demostrar |
| Entrenar, exportar y reproducir inferencias de una CNN compacta | Dos entrenamientos completos con exportación a TensorFlow Lite y comprobación de sus salidas frente a Keras. | Verificado técnicamente |
| Ejecutar y mostrar una inferencia offline en Android | APK experimental con v1 probado en Pixel 7 emulado, Android API 36. HU-01 a HU-05 verificadas. HU-06 verificada como simulación manual. | Verificado en emulador |
| Validar el comportamiento y medir tiempos en un teléfono físico | Los registros de Android indican que ADB solo detectó el emulador. | Pendiente |

[Requisitos del proyecto](../../README.md) · [Inventario y procedencia](../dataset-queresa/README.md) · [Informe del MVP](../../.tooling/mvp-demo/INFORME_MVP.md).

## 2. Datos, arquitectura y pipeline

### Preparación y trazabilidad

- **Fotografía original.** Archivo tomado como base de la fuente, con su etiqueta de inventario y grupo de procedencia. Un original puede pertenecer a la misma sesión, lote o fruto que otros. De las 346 sanas del inventario se incorporaron 344. WA0149 se excluyó por probable recodificación de WA0137 y WA0181 por similitud con WA0193, cuya etiqueta estaba en conflicto.
- **Fotografía aumentada.** Variante derivada de un original de entrenamiento mediante transformaciones como rotación, volteo, ajuste de brillo o contraste y zoom. Conserva clase y grupo de origen. Las variantes amplían las formas en que se presenta la misma escena al modelo y no agregan frutos, parcelas ni sesiones.
- **Muestra agronómicamente validada.** Para el estudio de campo debe contar con condición sanitaria revisada por un especialista, variedad y procedencia registradas, permiso de uso y vínculo a la unidad productiva. Las corridas emplearon etiquetas de sus fuentes. Los archivos revisados no acreditan una muestra validada de palta Naval de Huaral para evaluar estos modelos.

| Partición | Sanas originales | Sanas aumentadas | Con queresa originales | Con queresa aumentadas v1 / v2 | Total v1 / v2 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Entrenamiento | 252 | 106 | 4 | 444 / 354 | 806 / 716 |
| Validación | 7 | 0 | 1 | 0 / 0 | 8 / 8 |
| Prueba | 85 | 0 | 1 | 0 / 0 | 86 / 86 |
| Total | 344 | 106 | 6 | 444 / 354 | 900 / 810 |

Se verificaron etiquetas, archivos, hashes y linaje de las variantes. Los siete grupos registrados quedaron confinados a una partición. No se incorporó ninguna de las 22 fotos pendientes de Drive. Las 94 fotos de validación y prueba coincidieron entre corridas por archivo, grupo, etiqueta y tensor preprocesado. Los aumentos positivos derivaron de tres fotos del mismo grupo de Casma, con 148 variantes por foto en v1 y 118 en v2. Una cuarta positiva de entrenamiento, de una fuente histórica de Queensland, se usó como original. V2 balanceó solo entrenamiento, con 358 archivos por clase y cero duplicados exactos.

[Registro v1](cnn_900_run_01/status.json) · [Registro v2](cnn_balanced_run_02/status.json) · [Detalle de preparación v1](cnn_900_run_01/INFORME.md).

### Entrenamiento y conversión

1. **Entrada.** Python corrigió la orientación EXIF con Pillow, convirtió a RGB y aplicó redimensionamiento bilineal a 160 × 160. La red recibe valores 0–255 y los escala internamente por 1/255.
2. **Arquitectura.** CNN de 12 690 parámetros con una convolución inicial de 16 filtros, tres bloques de convolución separable y agrupación máxima, promedio global y una capa de dos salidas softmax. El orden de clases es `no_visible_signs` y `possible_scale`.
3. **Configuración común.** TensorFlow 2.20.0 y Keras 3.15.1 en CPU, semilla 42, seis épocas fijas, lotes de 16, Adam con tasa 0,001 y pérdida de entropía cruzada categórica dispersa. La misma regla de ponderación por frecuencia produjo pesos sana/queresa de 1,1257/0,8996 en v1 y de 1,0/1,0 en v2. V2 cambió tanto la proporción de clases como la receta de aumentos positivos.
4. **Evaluación y exportación.** Se guardaron el historial, las curvas y los pesos de la sexta época. La evaluación experimental tomó la clase con mayor puntuación. Se exportaron modelos Keras y TFLite con pesos FP16, entrada RGB `float32 [1,160,160,3]` y salida `float32 [1,2]`. La repetición de v1 reprodujo exactamente el historial, su matriz, las salidas de prueba rápida y el hash del TFLite.

El pipeline experimental se ejecutó por separado. El prechequeo de campo rechazó el manifiesto experimental de v1 por su formato. El proceso de campo conserva sus requisitos de calidad y separación por unidad productiva, y prevé seleccionar el modelo y el umbral con validación antes de medir la prueba independiente. La prueba ya examinada de v1 y v2 se conserva como referencia histórica.

[Arquitectura y pipeline de campo](../train.py) · [Configuración experimental](config_cnn_900.json) · [Reproducibilidad v1](cnn_900_run_01/reproducibilidad.json) · [Comparación y reproducción v2](cnn_balanced_run_02/COMPARACION_MODELOS.md).

## 3. Comparación de resultados y análisis de errores

### Métricas descriptivas verificadas

| Indicador | v1 · 900 archivos | v2 · entrenamiento balanceado |
| --- | ---: | ---: |
| Aciertos en prueba | 30/86 | 29/86 |
| Exactitud en prueba | 34,88 % | 33,72 % |
| F1 macro en prueba | 0,2716 | 0,2647 |
| Falsos positivos entre fotos sanas | 56/85 (65,88 %) | 57/85 (67,06 %) |
| Recall positivo observado | 1/1 | 1/1 |
| Matriz de confusión¹ | `[[29, 56], [0, 1]]` | `[[28, 57], [0, 1]]` |
| Exactitud final de entrenamiento / validación | 100 % / 50 % | 100 % / 50 % |
| Pérdida de validación, época 1 → 6 | 0,6024 → 6,4611 | 0,5059 → 6,8775 |

¹ Filas de etiqueta de origen y columnas de predicción. En ambos ejes el orden es sana y con queresa.

V2 corrigió un falso positivo de v1 y añadió dos. Los dos modelos compartieron 55 falsos positivos. La diferencia neta fue de un caso en la prueba ya examinada. Como también cambió la receta de aumentos, no se puede aislar el efecto del balanceo. Se conserva v1 como referencia por el resultado descriptivo y por ser el modelo ya verificado en el APK.

[Métricas y equivalencia](cnn_balanced_run_02/comparacion.json) · [Predicciones por foto](cnn_balanced_run_02/predicciones_prueba_comparadas.csv) · [Curvas comparadas](cnn_balanced_run_02/curvas_comparadas.png) · [Épocas v1](cnn_900_run_01/history.csv) · [Épocas v2](cnn_balanced_run_02/history.csv).

### Hallazgos e hipótesis sobre el sobreajuste

- **Verificado en las curvas.** En ambas corridas la pérdida de entrenamiento cayó mientras la de validación aumentó después de la primera época. La exactitud final difirió en 50 puntos porcentuales entre entrenamiento y validación. V2 mantuvo esa brecha y terminó con mayor pérdida de validación.
- **Verificado en la revisión de v1.** Entre las sanas de prueba, las 22 tomas con cartón dominante fueron falsos positivos. La mediana de la intensidad luminosa media del encuadre fue 133,6/255 en los errores y 160,1/255 en los aciertos. En entrenamiento, 236 de 252 sanas originales y ninguna de las 448 positivas tuvieron más del 65 % del cuadro con luma de al menos 243/255. Los 56 errores de prueba reaparecieron tanto en Keras como en TFLite.
- **Hipótesis.** La CNN pudo aprovechar señales ligadas a la procedencia, como fondos, iluminación, encuadre o aspecto de la piel, o memorizar detalles de las tres escenas positivas en las variantes. Fondo, luz, textura y procedencia varían conjuntamente. La variedad de las sanas de prueba no está documentada y la única positiva de prueba figura como Hass. Los registros sustentan asociaciones y señales de sobreajuste, con causa individual aún indeterminada.

[Análisis de errores](cnn_900_error_analysis/ANALISIS_ERRORES.md) · [Galería de falsos positivos](cnn_900_error_analysis/galeria_falsos_positivos.html) · [Revisión de fondos](cnn_900_error_analysis/revision_fondos.csv).

### Por qué las metas de campo siguen pendientes

El recall de queresa mide la proporción de positivos reales que se detectan. Un acierto entre una sola positiva describe ese caso y aporta evidencia insuficiente para sostener un recall de al menos 85 % en campo. El F1 macro promedia los F1 de ambas clases y combina precisión y recall. Los valores observados quedan por debajo de 0,85 en este lote. Las 85 sanas de prueba proceden de un mismo lote de origen, y la validación también tiene una sola positiva. La falta de positivos independientes y de confirmación agronómica en palta Naval de Huaral limita ambas métricas. Una evaluación confirmatoria requiere nuevas particiones de campo y una prueba reservada para una única evaluación final con el modelo y umbral ya fijados.

## 4. TensorFlow Lite, Android y pruebas del MVP

**Equivalencia local.** En CPU, Keras y TFLite v1 coincidieron en las 86 clases predichas en prueba, con diferencia máxima de 0,000334 entre puntuaciones. Para v2 coincidieron en las 94 fotos de validación y prueba y la diferencia máxima fue 0,002402. El APK experimental sigue usando v1. [Métricas v1](cnn_900_error_analysis/metricas.json) · [Métricas v2](cnn_balanced_run_02/comparacion.json) · [Inspección del APK final](../../.tooling/mvp-demo/apk-inspeccion.txt).

**Prueba técnica de Android.** Flutter usa un canal Kotlin con LiteRT bajo el paquete experimental `pe.edu.cropscan.experimental`. Android corrige la orientación al decodificar, solicita sRGB, ajusta a 160 × 160 y entrega RGB en el mismo rango que el entrenamiento. En Pixel 7 emulado, API 36 y x86_64, se probaron dos PNG con píxeles idénticos a los de referencia en Python, en dos tandas por foto. Las salidas fueron repetibles y su diferencia máxima frente a Python fue aproximadamente 3,6 × 10⁻⁹. Las medianas de inferencia nativa oscilaron entre 0,436 y 0,987 ms. Cada tanda tuvo tres calentamientos y diez mediciones, con dos hilos de CPU. Los tiempos excluyen carga y preparación de imagen. El JPEG original produjo una pequeña variación al redimensionarse con Android. Las mediciones corresponden a la prueba de integración anterior a la verificación final del MVP y quedan pendientes en teléfono físico. [Prueba Android](ANDROID_EXPERIMENTAL.md) · [Registro de las cuatro tandas](cnn_900_run_01/android_emulator.json).

**Prueba final del MVP.** El APK final incorporó el mismo TFLite de v1 y ejecutó el flujo en modo avión, sin Wi-Fi, datos móviles ni permiso `INTERNET`. Las pantallas de CropScan mantuvieron el aviso **MODELO EXPERIMENTAL — RESULTADOS NO VALIDADOS**. El análisis estático de Flutter concluyó sin incidencias y pasaron 16 pruebas automatizadas. La denegación de cámara y la cancelación del selector se verificaron en el emulador. La imagen ilegible y el modelo ausente se cubrieron en pruebas automatizadas, con servicio simulado para el modelo ausente. [Informe del MVP](../../.tooling/mvp-demo/INFORME_MVP.md) · [Pruebas](../../.tooling/mvp-demo/tests-verificado.log) · [Análisis estático](../../.tooling/mvp-demo/analyze-verificado.log) · [Evidencias verificadas](../../.tooling/mvp-demo/verificacion-evidencias.json).

| Historia | Resultado verificado | Evidencia |
| --- | --- | --- |
| HU-01 · Tomar foto | Solicitud, denegación, reintento y concesión de permiso. Captura de la escena virtual y retorno a la vista previa. | [Denegación](../../.tooling/mvp-demo/evidencias/03_camara_denegada.png) · [Captura devuelta](../../.tooling/mvp-demo/evidencias/06_preview_camara.png) |
| HU-02 · Elegir desde galería | Selección de una foto local con el emulador en modo avión. | [Selector](../../.tooling/mvp-demo/evidencias/07_selector_galeria.png) |
| HU-03 · Previsualizar y cambiar | La vista previa conserva la foto al cancelar y muestra la nueva al reemplazarla. | [Cancelación](../../.tooling/mvp-demo/evidencias/08_cancelar_cambio.png) · [Reemplazo](../../.tooling/mvp-demo/evidencias/09_preview_galeria.png) |
| HU-04 · Analizar offline | Inferencia local con v1 sin conexión. | [Estado de red](../../.tooling/mvp-demo/estado-emulador.json) · [Resultado](../../.tooling/mvp-demo/evidencias/10_resultado_offline.png) |
| HU-05 · Mostrar resultados | Visualización de ambas puntuaciones con aviso experimental. | [Jerarquía de pantalla](../../.tooling/mvp-demo/evidencias/10_resultado_offline.xml) |
| HU-06 · Mostrar estado no concluyente | Simulación manual identificada en pantalla. Oculta los valores y permite volver a las mismas puntuaciones. Falta un umbral validado para activar el estado automáticamente. | [Simulación](../../.tooling/mvp-demo/evidencias/11_no_concluyente_demo.png) · [Retorno](../../.tooling/mvp-demo/evidencias/12_volver_probabilidades.png) |

## 5. Riesgos pendientes y acciones correctivas propuestas

| Riesgo e impacto | Acción propuesta | Evidencia de cierre y responsable propuesto |
| --- | --- | --- |
| Datos escasos y sesgo de captura. Los positivos derivados de pocas escenas pueden elevar los errores fuera del entrenamiento. | Cuando se reactive el trabajo de campo, recoger originales Naval de ambas clases en las mismas parcelas y condiciones comparables, variando árboles, frutos y sesiones. Registrar parcela, variedad, fecha, condición y revisión. | Bitácora de campo, autorizaciones y etiquetas aprobadas. **Datos y especialista agronómico.** |
| Prueba examinada y poca representación positiva. Las métricas podrían confundirse con validación de campo. | Definir suficientes positivos independientes por partición antes de entrenar. Separar por unidad productiva, reservar una prueba nueva y fijar de antemano los criterios de evaluación. | Manifiesto auditado y evaluación independiente de Keras y TFLite frente a las metas. **Equipo de ML.** |
| Puntuaciones interpretadas como diagnóstico o abstención automática. | Mantener el aviso y el carácter manual de HU-06 en la demostración. Antes de automatizar la abstención, seleccionar el umbral en una validación independiente y medir la cobertura y las métricas sobre la prueba reservada. | Evidencia de interfaz para la exposición e informe de calibración para el modelo de campo. **Producto y ML.** |
| Cámara, selector, preparación RGB y rendimiento variables en teléfonos físicos. | Ejecutar en un equipo físico la instalación, permisos, captura, galería, modo avión y paridad con imágenes de referencia. Medir por separado preparación e inferencia. | Registro por dispositivo con versiones, tiempos, resultados y capturas. **Android y pruebas.** |
| Fallo del flujo durante la exposición por fotos solo en la nube o selección del APK normal. | Usar el emulador verificado, dejar una foto disponible localmente y abrir el paquete experimental con el aviso visible. | Ensayo previo en modo avión con el APK de la entrega. **Equipo de demostración.** |

Las acciones de captura y validación agronómica quedan planificadas y pospuestas. La decisión actual mantiene v1 para la demostración y archiva v2, sin programar un tercer entrenamiento. [Plan de captura](cnn_900_error_analysis/PLAN_CAPTURA.md).

## 6. Resumen para la presentación universitaria

1. **Objetivo y alcance.** Construimos un MVP Android para ensayar la detección preliminar de queresa en palta. La entrega actual demuestra el flujo técnico offline.
2. **Datos y experimento.** Probamos dos CNN con los mismos originales y la misma evaluación. Los archivos aumentados proceden de fotografías existentes. En todo el dataset hay seis positivos originales.
3. **Resultado y decisión.** V1 produjo 56 falsos positivos y v2 produjo 57 sobre las mismas 85 sanas. V2 no redujo las señales de sobreajuste. Conservamos v1 como referencia y en el APK.
4. **Demostración.** Abrir CropScan Experimental en modo avión, tomar una foto, cambiarla por una foto local, mostrar las dos salidas y activar la simulación del estado no concluyente.
5. **Cierre.** El MVP quedó verificado en emulador. La verificación física y la evaluación de las metas de recall y F1 macro requieren evidencia adicional.
