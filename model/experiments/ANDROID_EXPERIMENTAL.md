# Prueba técnica de CropScan en Android

La prueba usa `lib/main_experimental.dart` y el paquete Android `pe.edu.cropscan.experimental`. Gradle copia el TFLite de la corrida 01 como asset solamente en esa compilación. El canal Kotlin `pe.edu.cropscan/experimental` se registra únicamente en ese paquete y ejecuta el intérprete LiteRT en segundo plano. La compilación de campo conserva su identificador, canal, assets y umbral. [Canales de plataforma de Flutter](https://docs.flutter.dev/platform-integration/platform-channels)

## Compilación y prueba

```powershell
flutter build apk --release --target lib/main_experimental.dart --dart-define=CROPSCAN_EXPERIMENTAL=true
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n pe.edu.cropscan.experimental/pe.edu.cropscan.MainActivity
```

Selecciona una foto almacenada en el teléfono y pulsa **Ejecutar inferencia local**. En modo avión se requiere que la foto esté disponible localmente. La pantalla de CropScan mantiene visible **MODELO EXPERIMENTAL — RESULTADOS NO VALIDADOS** antes, durante y después de ejecutar la prueba.

## Contrato y medición

Android corrige la orientación al decodificar, solicita sRGB y ajusta a 160 × 160. Escribe el tensor `float32` NHWC `[1, 160, 160, 3]` como R, G y B en ese orden con valores 0–255. La normalización a 0–1 está dentro de la CNN. El selector de la prueba entrega los bytes de la imagen sin el límite de redimensionamiento del flujo convencional.

El intérprete comprueba el tensor `float32 [1, 2]`. Se muestran las probabilidades en el orden `no_visible_signs`, `possible_scale`. Se verifica que sean finitas, estén entre 0 y 1 y sumen aproximadamente 1. La pantalla muestra los dos valores sin aplicar un umbral agronómico.

La medición usa dos hilos CPU, tres ejecuciones de calentamiento y diez ejecuciones medidas con un reloj monotónico. Reporta mediana y P95 del tiempo de `Interpreter.run`, separados de la carga del modelo y la preparación RGB. También muestra la máxima diferencia absoluta entre las salidas de las repeticiones y la del último calentamiento. [API del intérprete LiteRT](https://ai.google.dev/edge/api/tflite/java/org/tensorflow/lite/InterpreterApi)

## Resultado del 27 de noviembre de 2026

En el emulador Pixel 7 con Android API 36 y ABI x86_64 se instaló el APK de release. El APK incluye el mismo SHA-256 del TFLite de la corrida 01. Su manifiesto carece de permiso `INTERNET`. Se verificó modo avión, Wi-Fi apagado y datos móviles apagados mientras se elegían las fotos y se ejecutaba el modelo.

Se hicieron dos tandas por foto con dos PNG de 160 × 160 obtenidos con el mismo preprocesamiento Pillow de la corrida Python. Eso mantiene iguales los píxeles al comparar los intérpretes.

| Foto de referencia | Salida en Android `[no_visible_signs, possible_scale]` | Medianas de inferencia | P95 |
| --- | --- | --- | --- |
| `agro227_1.png` | `[0.00751945, 0.99248052]` | 0,436 y 0,987 ms | 0,674 y 2,768 ms |
| `unprg_foto22.jpg` | `[0.00047532, 0.99952471]` | 0,691 y 0,597 ms | 1,997 y 14,552 ms |

Las 10 salidas por tanda coincidieron con la de calentamiento. Las dos tandas de cada foto coincidieron a los ocho decimales mostrados. La máxima diferencia de esos valores frente a Python fue de aproximadamente 3,6 × 10⁻⁹. Estas medidas corresponden al emulador y al tramo de inferencia nativa. Con 10 observaciones, el P95 por rango corresponde a la observación más lenta de cada tanda. Queda pendiente el tiempo en un teléfono físico porque ADB no detectó ninguno. [Registro de las cuatro tandas](cnn_900_run_01/android_emulator.json)

El resultado alto de `possible_scale` para la referencia sana reproduce un error que ya aparecía en Python. La coincidencia comprueba la integración técnica y las probabilidades carecen de validación para diagnóstico.

La prueba adicional con el JPEG original `unprg_foto22.jpg` de 590 × 412 también funcionó sin conexión. El redimensionamiento nativo produjo `[0.00044204, 0.99955791]` y una mediana de inferencia de 0,643 ms. La preparación de esa única tanda tardó 270,807 ms. Sus valores difieren ligeramente de los del PNG ya redimensionado, por lo que la comparación directa entre intérpretes se hizo con entradas de píxeles idénticas.

Flutter pasó el análisis estático y las 14 pruebas. Se corrigieron los avisos iniciales de importación usando `material_ui`, el paquete del proyecto. En la primera automatización del selector, el toque llegó antes de que Android mostrara la cuadrícula. La repetición esperó el control accesible de cada foto y completó las cuatro tandas.

También se compiló el APK normal. Su identificador es `pe.edu.cropscan` y su ZIP carece del asset `cropscan_experimental.tflite`. Los SHA-256 del modelo original, del script de entrenamiento de campo y de los dos manifiestos coinciden con los registrados al entrenar la corrida 01.
