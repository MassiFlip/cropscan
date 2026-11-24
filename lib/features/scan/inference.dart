import 'dart:typed_data';

enum ScanClass {
  possibleScale('Posibles signos de queresa'),
  noVisibleSigns('Sin signos visibles de queresa'),
  inconclusive('No concluyente');

  const ScanClass(this.label);
  final String label;
}

class InferenceResult {
  const InferenceResult({
    required this.predictedClass,
    required this.confidence,
    required this.minimumConfidence,
  }) : assert(confidence >= 0 && confidence <= 1),
       assert(minimumConfidence > 0 && minimumConfidence <= 1),
       assert(predictedClass != ScanClass.inconclusive);

  final ScanClass predictedClass;
  final double confidence;
  final double minimumConfidence;

  ScanClass classify() {
    return confidence >= minimumConfidence
        ? predictedClass
        : ScanClass.inconclusive;
  }
}

class InferenceFailure implements Exception {
  const InferenceFailure(this.message);

  final String message;
}

abstract interface class InferenceService {
  /// The adapter owns preprocessing and inference on the encoded local image.
  Future<InferenceResult> analyze(Uint8List image);

  bool get isDemo;
}

enum DemoScenario {
  possibleScale('Posibles signos'),
  noVisibleSigns('Sin signos visibles'),
  lowConfidence('No concluyente');

  const DemoScenario(this.label);
  final String label;
}

class DemoInferenceService implements InferenceService {
  const DemoInferenceService({
    this.scenario = DemoScenario.possibleScale,
    this.delay = const Duration(milliseconds: 700),
  });

  static const _minimumConfidence = 0.70;

  final DemoScenario scenario;
  final Duration delay;

  @override
  bool get isDemo => true;

  @override
  Future<InferenceResult> analyze(Uint8List image) async {
    await Future<void>.delayed(delay);
    // Fixed examples deliberately independent of the photograph.
    return switch (scenario) {
      DemoScenario.possibleScale => const InferenceResult(
        predictedClass: ScanClass.possibleScale,
        confidence: 0.88,
        minimumConfidence: _minimumConfidence,
      ),
      DemoScenario.noVisibleSigns => const InferenceResult(
        predictedClass: ScanClass.noVisibleSigns,
        confidence: 0.82,
        minimumConfidence: _minimumConfidence,
      ),
      DemoScenario.lowConfidence => const InferenceResult(
        predictedClass: ScanClass.possibleScale,
        confidence: 0.53,
        minimumConfidence: _minimumConfidence,
      ),
    };
  }
}
