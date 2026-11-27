import 'dart:convert';
import 'dart:typed_data';

import 'package:cropscan/app.dart';
import 'package:cropscan/features/scan/android_inference.dart';
import 'package:cropscan/features/scan/inference.dart';
import 'package:cropscan/features/scan/photo_source.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
  'EElEQVR4AQEFAPr/ACR1SP8DgwHhwGdScAAAAABJRU5ErkJggg==',
);

final _resultPhoto = find.byWidgetPredicate(
  (widget) => widget is Image && widget.semanticLabel == 'Fotografía analizada',
);

class _Photos implements PhotoSource {
  Uint8List? recovered;
  Uint8List? next;
  PhotoFailure? error;
  PhotoOrigin? lastOrigin;

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) async {
    lastOrigin = origin;
    if (error case final failure?) throw failure;
    return next;
  }

  @override
  Future<Uint8List?> recover() async => recovered;
}

class _FailingInference implements InferenceService {
  @override
  bool get isDemo => false;

  @override
  Future<InferenceResult> analyze(Uint8List image) async {
    throw StateError('inference failed');
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester,
  _Photos photos, {
  InferenceService inference = const DemoInferenceService(),
}) async {
  await tester.pumpWidget(CropScanApp(photos: photos, inference: inference));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('uses Poppins for headings and Inter for the interface', (
    tester,
  ) async {
    await _open(tester, _Photos());

    final hero = tester.widget<Text>(find.text('Revisa tu cultivo'));
    final card = tester.widget<Text>(find.text('Revisión por fotografía'));
    final tip = tester.widget<Text>(find.text('Busca luz natural.'));
    expect(hero.style?.fontFamily, 'Poppins');
    expect(card.style?.fontFamily, 'Poppins');
    expect(tip.style?.fontFamily, 'Inter');

    final appBarTheme = Theme.of(tester.element(find.byType(AppBar)));
    expect(appBarTheme.appBarTheme.titleTextStyle?.fontFamily, 'Poppins');
    expect(appBarTheme.textTheme.labelLarge?.fontFamily, 'Inter');
  });

  testWidgets('prototype shows visible marks and the model score', (
    tester,
  ) async {
    const channel = MethodChannel('pe.edu.cropscan/inference');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'analyzePrototype');
      return {
        'category': 'possible_scale',
        'confidence': 0.794,
        'threshold': 0.60,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      CropScanApp(
        photos: _Photos()..recovered = _photo,
        inference: const AndroidInferenceService(prototype: true),
        prototype: true,
      ),
    );
    await tester.pumpAndSettle();

    await _tap(tester, 'Analizar foto');

    expect(find.text('Marcas visibles'), findsOneWidget);
    expect(find.text('Puntaje del prototipo: 79.4 %'), findsOneWidget);
    expect(find.text('Posibles signos de queresa'), findsNothing);
    expect(_resultPhoto, findsOneWidget);
  });

  testWidgets('gallery, preview, processing and a labelled demo result', (
    tester,
  ) async {
    final photos = _Photos()..next = _photo;
    await _open(tester, photos);

    expect(find.text('MODO DEMO'), findsOneWidget);
    await _tap(tester, 'Elegir de la galería');
    expect(photos.lastOrigin, PhotoOrigin.gallery);
    expect(find.text('Vista previa'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    final simulate = find.text('Simular análisis');
    await tester.ensureVisible(simulate);
    await tester.pump();
    await tester.tap(simulate);
    await tester.pump();
    expect(find.text('Simulando análisis'), findsOneWidget);
    expect(find.text('MODO DEMO'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Posibles signos de queresa'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('MODO DEMO'), findsOneWidget);
    expect(_resultPhoto, findsOneWidget);
    await _tap(tester, 'Volver al inicio');
    expect(find.text('Analizar planta'), findsOneWidget);
  });

  testWidgets('selects low confidence and repeats the photo', (tester) async {
    final photos = _Photos()..next = _photo;
    await _open(tester, photos);
    await _tap(tester, 'Analizar planta');
    await _tap(tester, 'Tomar foto');
    expect(photos.lastOrigin, PhotoOrigin.camera);
    await _tap(tester, 'Posibles signos');
    await _tap(tester, 'No concluyente');
    await _tap(tester, 'Simular análisis');

    expect(find.text('No concluyente'), findsOneWidget);
    expect(find.text('MODO DEMO'), findsOneWidget);
    await _tap(tester, 'Repetir foto');
    expect(find.text('Agrega una foto'), findsOneWidget);
  });

  testWidgets('permission error and cancellation preserve the previous photo', (
    tester,
  ) async {
    final photos = _Photos()..recovered = _photo;
    await _open(tester, photos);
    expect(find.text('Vista previa'), findsOneWidget);
    await _tap(tester, 'Reemplazar foto');
    photos.error = const PhotoFailure('Revisa el permiso en Ajustes.');
    await _tap(tester, 'Tomar foto');
    expect(find.text('Revisa el permiso en Ajustes.'), findsOneWidget);

    photos.error = null;
    await _tap(tester, 'Elegir de la galería');
    expect(find.text('Elegir foto'), findsOneWidget);
    expect(find.text('Revisa el permiso en Ajustes.'), findsNothing);
    await _tap(tester, 'Volver a la foto anterior');
    expect(find.text('Vista previa'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('analysis errors return to preview for a retry', (tester) async {
    final photos = _Photos()..recovered = _photo;
    await _open(tester, photos, inference: _FailingInference());
    await _tap(tester, 'Analizar foto');
    expect(find.text('Vista previa'), findsOneWidget);
    expect(
      find.text('No pudimos completar el análisis. Intenta otra vez.'),
      findsOneWidget,
    );
    expect(find.text('Analizar foto'), findsOneWidget);
  });

  testWidgets('small screen stays usable with large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _open(tester, _Photos()..next = _photo);
    await _tap(tester, 'Analizar planta');
    await _tap(tester, 'Elegir de la galería');
    await _tap(tester, 'Simular análisis');
    await _tap(tester, 'Volver al inicio');
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects malformed photos before preview', (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        validatePhoto(Uint8List.fromList([0, 1, 2])),
        throwsA(isA<PhotoFailure>()),
      );
      await validatePhoto(_photo);
    });
  });
}
