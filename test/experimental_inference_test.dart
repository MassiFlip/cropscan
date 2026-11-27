import 'dart:convert';

import 'package:cropscan/features/experimental/experimental_screen.dart';
import 'package:cropscan/features/scan/photo_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
  'EElEQVR4AQEFAPr/ACR1SP8DgwHhwGdScAAAAABJRU5ErkJggg==',
);

class _Photos implements PhotoSource {
  Uint8List? next = _photo;
  PhotoFailure? failure;
  PhotoOrigin? lastOrigin;

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) async {
    lastOrigin = origin;
    if (failure case final error?) throw error;
    return next;
  }

  @override
  Future<Uint8List?> recover() async => null;
}

void main() {
  const reading = ExperimentalReading(
    noVisibleSigns: 0.25,
    possibleScale: 0.75,
    loadMs: 5,
    prepareMs: 3,
    medianMs: 1,
    p95Ms: 2,
    repetitions: 10,
    maxScoreDelta: 0,
  );

  Future<void> tap(WidgetTester tester, String label) async {
    final button = find.text(label);
    if (button.evaluate().isEmpty) {
      final towardsTop =
          label == 'Tomar fotografía' || label == 'Elegir fotografía';
      await tester.scrollUntilVisible(
        button,
        towardsTop ? -180 : 180,
        scrollable: find.byType(Scrollable),
      );
    }
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('keeps the warning visible and displays the raw output order', (
    tester,
  ) async {
    const channel = MethodChannel('pe.edu.cropscan/experimental');
    final messenger = tester.binding.defaultBinaryMessenger;
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      expect(call.method, 'analyze');
      expect(call.arguments, _photo);
      return <String, Object>{
        'scores': <double>[0.25, 0.75],
        'loadMs': 5.0,
        'prepareMs': 3.0,
        'medianMs': 1.0,
        'p95Ms': 2.0,
        'repetitions': 10,
        'maxScoreDelta': 0.0,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final photos = _Photos();
    await tester.pumpWidget(
      MaterialApp(
        home: ExperimentalScreen(
          photos: photos,
          analyze: analyzeExperimentalPhoto,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final notice = find.text(experimentalNotice);
    expect(notice, findsOneWidget);
    expect(find.text('Ejecutar inferencia local'), findsNothing);
    await tester.tap(find.text('Elegir fotografía'));
    await tester.pumpAndSettle();
    expect(photos.lastOrigin, PhotoOrigin.gallery);
    expect(notice, findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Ejecutar inferencia local'));
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
      expect(find.text('no_visible_signs  0.25000000'), findsOneWidget);
      expect(find.text('possible_scale  0.75000000'), findsOneWidget);
    }
    expect(calls, 2);
  });

  testWidgets('camera selection handles denial, cancellation and replacement', (
    tester,
  ) async {
    final photos = _Photos()..failure = const PhotoFailure('Cámara denegada');
    final replacement = Uint8List.fromList(_photo);
    final analyzed = <Uint8List>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ExperimentalScreen(
          photos: photos,
          analyze: (photo) async {
            analyzed.add(photo);
            return reading;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Tomar fotografía');
    expect(photos.lastOrigin, PhotoOrigin.camera);
    expect(find.text('Cámara denegada'), findsOneWidget);
    expect(find.text('Ejecutar inferencia local'), findsNothing);

    photos.failure = null;
    await tap(tester, 'Tomar fotografía');
    await tap(tester, 'Ejecutar inferencia local');
    expect(analyzed.last, same(_photo));

    photos.next = null;
    await tap(tester, 'Elegir fotografía');
    expect(find.text('possible_scale  0.75000000'), findsOneWidget);
    await tap(tester, 'Ejecutar inferencia local');
    expect(analyzed.last, same(_photo));

    photos.next = replacement;
    await tap(tester, 'Elegir fotografía');
    expect(find.text('possible_scale  0.75000000'), findsNothing);
    await tap(tester, 'Ejecutar inferencia local');
    expect(analyzed.last, same(replacement));
  });

  testWidgets('simulates inconclusive only on request and supports retry', (
    tester,
  ) async {
    final photos = _Photos();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExperimentalScreen(
          photos: photos,
          analyze: (_) async {
            calls++;
            if (calls == 1) throw PlatformException(code: 'model_missing');
            return reading;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Elegir fotografía');
    await tap(tester, 'Ejecutar inferencia local');
    expect(
      find.text('El APK experimental no incluye el modelo.'),
      findsOneWidget,
    );
    await tap(tester, 'Ejecutar inferencia local');
    expect(find.text('No concluyente · Demostración'), findsNothing);
    await tap(tester, 'Demostrar el estado no concluyente');
    expect(find.text(experimentalNotice), findsOneWidget);
    expect(find.text('No concluyente · Demostración'), findsOneWidget);
    expect(find.text('possible_scale  0.75000000'), findsNothing);
    await tap(tester, 'Volver a las probabilidades');
    expect(find.text('possible_scale  0.75000000'), findsOneWidget);
    await tap(tester, 'Demostrar el estado no concluyente');
    await tap(tester, 'Tomar fotografía');
    expect(find.text('No concluyente · Demostración'), findsNothing);
    expect(calls, 2);
  });

  test('rejects output that does not normalize to one', () {
    expect(
      () => ExperimentalReading.fromResponse({
        'scores': [0.3, 0.3],
        'repetitions': 10,
      }),
      throwsFormatException,
    );
  });
}
