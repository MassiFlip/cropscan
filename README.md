# CropScan

MVP académico para Android 10 (API 29) o superior. Permite tomar o elegir una foto de una hoja o fruto de palta Naval, revisarla o cambiarla, y analizarla localmente con el modelo de CropScan. El resultado incluye la estimación, la confianza y una orientación. Por debajo del umbral del modelo muestra «No concluyente» y permite repetir la foto. La evaluación es preliminar y el usuario puede consultar a un especialista agrícola.

La ruta de análisis Android usa un intérprete TensorFlow Lite (LiteRT) incluido en el APK. CropScan necesita un modelo de campo y su umbral para emitir un resultado. Si faltan esos archivos, conserva la vista previa y muestra un mensaje de error. El selector de imágenes y la cámara pueden crear archivos temporales en la caché de Android.

## Entrenar y empacar el modelo

Para acreditar el MVP se requieren fotos autorizadas de hojas y frutos de palta Naval de Huaral, con etiquetas revisadas por un especialista y trazabilidad por unidad productiva. El conjunto debe tener al menos 600 imágenes etiquetadas y al menos 90 % con nitidez, encuadre y trazabilidad aprobados. Registra la procedencia, el permiso y la revisión de cada lote en la bitácora de campo.

El CSV de entrenamiento usa las columnas `photo,label,unit,split,quality_ok`. La ruta de cada foto es relativa al CSV. Las etiquetas son `no_visible_signs` y `possible_scale`. Usa el mismo identificador de unidad productiva en todas sus fotos y asigna cada unidad a una sola partición entre `train`, `validation` y `test`, con ambas clases en cada partición. Marca `quality_ok` con `1` cuando la foto aprueba los tres criterios y con `0` en los otros casos. El entrenamiento exige al menos 300 fotos etiquetadas por clase.

Para revisar el lote recopilado, ejecuta la auditoría en un directorio de salida nuevo. Usa las colas CSV para revisar la calidad y documentar la validación agronómica. Rellena el manifiesto de campo con etiquetas del especialista y comprueba su estructura antes de entrenar.

```shell
python model/audit_dataset.py .tooling/dataset-queresa .tooling/auditoria-nueva
python model/train.py <ruta-al-csv-de-campo> --check-only
```

```powershell
python -m pip install "tensorflow==2.20.0" Pillow
python model/train.py <ruta-al-csv> <nuevo-directorio-de-resultados>
```

El script compara dos CNN compactas, selecciona el modelo y el umbral con validación y evalúa el modelo base y el TFLite optimizado en la partición de prueba independiente. El informe `evaluation.json` incluye la matriz de confusión, el recall de queresa, el F1 macro y los resultados no concluyentes. Si ambos modelos superan o igualan los umbrales del DOCX (recall de queresa de 85 % y F1 macro de 0.85), la exportación genera `cropscan.tflite` y `cropscan-model.json`. Para empacar el modelo, coloca ambos en `android/app/src/main/assets/` antes de compilar.

Contrato Android del modelo. Entrada RGB sRGB `float32` NHWC de forma `[1, alto, ancho, 3]`, con valores de 0 a 255 y normalización dentro de la CNN. Android corrige la orientación al decodificar y ajusta la imagen al tamaño del tensor. Salida `float32` de forma `[1, 2]` con probabilidades en el orden `no_visible_signs`, `possible_scale`. El JSON contiene el campo `threshold` de validación de la versión TFLite.

## Compilar y verificar en Android

Instala Flutter, Android SDK Platform 36, NDK 28.2.13676358 y un JDK compatible con Gradle. En este workspace de Windows, puedes agregar el SDK de Flutter local al PATH con `$env:Path = "$(Resolve-Path .tooling/flutter/bin);$env:Path"`. La primera compilación necesita descargar las dependencias.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

El APK usa la clave de depuración del entorno para las pruebas académicas. Para mostrar el flujo con ejemplos simulados de forma explícita, ejecuta `flutter run --dart-define=CROPSCAN_DEMO=true`. Esa ejecución se identifica en pantalla como DEMO.

Para la verificación del MVP, usa un Android objetivo en modo avión, con Wi-Fi y datos desactivados. Prueba una captura de cámara, una imagen guardada en galería y un caso de baja confianza con resultado «No concluyente». Comprueba que se puede reemplazar la foto, reintentar tras un error e iniciar otro análisis.

Mide desde «Analizar foto» hasta el primer fotograma del resultado. El APK registra solo la duración de cada análisis completado, en milisegundos. Usa `adb logcat -v brief -s flutter` y busca `CropScan analysis_ms=`. Registra la versión del APK, el dispositivo y el promedio de al menos 30 inferencias por dispositivo objetivo. El límite es de 5 segundos en promedio.

## Probar el prototipo visual como app

La variante **CropScan Prototipo** incluye el modelo de marcas visibles de `model/prototype/` y se instala como una app independiente. Puedes tomar una foto o elegirla de la galería y pulsar «Analizar foto», incluso en modo avión. El resultado muestra el puntaje del prototipo. Usa un corte provisional del 60 % para mostrar «No concluyente».

```powershell
flutter build apk --release --dart-define=CROPSCAN_PROTOTYPE=true
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
