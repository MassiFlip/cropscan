import 'package:cropscan/features/scan/inference.dart';
import 'package:flutter/services.dart';

class AndroidInferenceService implements InferenceService {
  const AndroidInferenceService({this.prototype = false});

  final bool prototype;

  static const _channel = MethodChannel('pe.edu.cropscan/inference');

  @override
  bool get isDemo => false;

  @override
  Future<InferenceResult> analyze(Uint8List image) async {
    final Map<String, Object?>? response;
    try {
      response = await _channel.invokeMapMethod<String, Object?>(
        prototype ? 'analyzePrototype' : 'analyze',
        image,
      );
    } on PlatformException catch (error) {
      if (error.code == 'model_missing') {
        throw const InferenceFailure(
          'El modelo de CropScan no está instalado. Usa una versión de la app que incluya el modelo.',
        );
      }
      rethrow;
    }

    final category = switch (response?['category']) {
      'possible_scale' => ScanClass.possibleScale,
      'no_visible_signs' => ScanClass.noVisibleSigns,
      _ => null,
    };
    final confidence = response?['confidence'];
    final threshold = response?['threshold'];
    if (category == null ||
        confidence is! double ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1 ||
        threshold is! double ||
        !threshold.isFinite ||
        threshold <= 0 ||
        threshold > 1) {
      throw const FormatException('Respuesta inválida del modelo de CropScan.');
    }
    return InferenceResult(
      predictedClass: category,
      confidence: confidence,
      minimumConfidence: threshold,
    );
  }
}
