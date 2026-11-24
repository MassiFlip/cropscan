import 'package:cropscan/features/scan/android_inference.dart';
import 'package:cropscan/features/scan/inference.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const channel = MethodChannel('pe.edu.cropscan/inference');

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('uses the model threshold returned by Android', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'analyze');
      expect(call.arguments, [1, 2, 3]);
      return {
        'category': 'possible_scale',
        'confidence': 0.81,
        'threshold': 0.85,
      };
    });

    final result = await const AndroidInferenceService().analyze(
      Uint8List.fromList([1, 2, 3]),
    );
    expect(result.classify(), ScanClass.inconclusive);
  });

  test('missing model produces an actionable error', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'model_missing');
    });

    await expectLater(
      const AndroidInferenceService().analyze(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<InferenceFailure>()),
    );
  });

  test('applies the confidence threshold, including the boundary', () {
    const result = InferenceResult(
      predictedClass: ScanClass.possibleScale,
      confidence: 0.70,
      minimumConfidence: 0.70,
    );
    const belowThreshold = InferenceResult(
      predictedClass: ScanClass.possibleScale,
      confidence: 0.70,
      minimumConfidence: 0.71,
    );
    expect(result.classify(), ScanClass.possibleScale);
    expect(belowThreshold.classify(), ScanClass.inconclusive);
  });

  test('demo examples do not change when the image changes', () async {
    const expected = {
      DemoScenario.possibleScale: ScanClass.possibleScale,
      DemoScenario.noVisibleSigns: ScanClass.noVisibleSigns,
      DemoScenario.lowConfidence: ScanClass.inconclusive,
    };

    for (final entry in expected.entries) {
      final service = DemoInferenceService(
        scenario: entry.key,
        delay: Duration.zero,
      );
      final first = await service.analyze(Uint8List.fromList([1, 2, 3]));
      final second = await service.analyze(Uint8List.fromList([5, 8]));
      expect(service.isDemo, isTrue);
      expect(first.confidence, second.confidence);
      expect(first.predictedClass, second.predictedClass);
      expect(first.classify(), entry.value);
    }
  });
}
