import 'package:cropscan/features/scan/photo_source.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

const experimentalNotice = 'MODELO EXPERIMENTAL — RESULTADOS NO VALIDADOS';
const _channel = MethodChannel('pe.edu.cropscan/experimental');

Future<ExperimentalReading> analyzeExperimentalPhoto(Uint8List photo) async {
  final result = await _channel.invokeMapMethod<String, Object?>(
    'analyze',
    photo,
  );
  return ExperimentalReading.fromResponse(result);
}

class ExperimentalReading {
  const ExperimentalReading({
    required this.noVisibleSigns,
    required this.possibleScale,
    required this.loadMs,
    required this.prepareMs,
    required this.medianMs,
    required this.p95Ms,
    required this.repetitions,
    required this.maxScoreDelta,
  });

  factory ExperimentalReading.fromResponse(Map<String, Object?>? response) {
    final scores = response?['scores'];
    final repetitions = response?['repetitions'];
    if (scores is! List ||
        scores.length != 2 ||
        scores.any((p) => p is! num || !p.isFinite || p < 0 || p > 1) ||
        ((scores[0] as num) + (scores[1] as num) - 1).abs() >= 0.001 ||
        repetitions is! int ||
        repetitions < 1) {
      throw const FormatException('Respuesta experimental inválida.');
    }

    double measurement(String name) {
      final value = response?[name];
      if (value is! num || !value.isFinite || value < 0) {
        throw FormatException('Medición experimental inválida: $name.');
      }
      return value.toDouble();
    }

    return ExperimentalReading(
      noVisibleSigns: (scores[0] as num).toDouble(),
      possibleScale: (scores[1] as num).toDouble(),
      loadMs: measurement('loadMs'),
      prepareMs: measurement('prepareMs'),
      medianMs: measurement('medianMs'),
      p95Ms: measurement('p95Ms'),
      repetitions: repetitions,
      maxScoreDelta: measurement('maxScoreDelta'),
    );
  }

  final double noVisibleSigns;
  final double possibleScale;
  final double loadMs;
  final double prepareMs;
  final double medianMs;
  final double p95Ms;
  final int repetitions;
  final double maxScoreDelta;
}

class ExperimentalScreen extends StatefulWidget {
  const ExperimentalScreen({
    super.key,
    required this.photos,
    required this.analyze,
  });

  final PhotoSource photos;
  final Future<ExperimentalReading> Function(Uint8List) analyze;

  @override
  State<ExperimentalScreen> createState() => _ExperimentalScreenState();
}

class _ExperimentalScreenState extends State<ExperimentalScreen> {
  Uint8List? _photo;
  ExperimentalReading? _reading;
  String? _error;
  bool _busy = false;
  bool _showInconclusiveDemo = false;

  @override
  void initState() {
    super.initState();
    _selectPhoto(widget.photos.recover);
  }

  Future<void> _selectPhoto(Future<Uint8List?> Function() read) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await read();
      if (mounted && photo != null) {
        setState(() {
          _photo = photo;
          _reading = null;
          _showInconclusiveDemo = false;
        });
      }
    } on PhotoFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception {
      if (mounted) {
        setState(() => _error = 'No se pudo abrir la fotografía.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run() async {
    final photo = _photo;
    if (photo == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _reading = null;
      _showInconclusiveDemo = false;
    });
    try {
      final result = await widget.analyze(photo);
      if (mounted) setState(() => _reading = result);
    } on Exception catch (error) {
      final message =
          error is PlatformException && error.code == 'model_missing'
          ? 'El APK experimental no incluye el modelo.'
          : 'No se pudo ejecutar la inferencia local. Prueba otra foto JPG o PNG.';
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CropScan Experimental',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            ColoredBox(
              color: colors.errorContainer,
              child: const SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    experimentalNotice,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _selectPhoto(
                            () => widget.photos.pick(PhotoOrigin.camera),
                          ),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Tomar fotografía'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _selectPhoto(
                            () => widget.photos.pick(PhotoOrigin.gallery),
                          ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Elegir fotografía'),
                  ),
                  if (_photo case final photo?) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        photo,
                        height: 160,
                        cacheWidth: 720,
                        fit: BoxFit.contain,
                        semanticLabel: 'Vista previa de la fotografía',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _run,
                      child: const Text('Ejecutar inferencia local'),
                    ),
                  ],
                  if (_busy) const LinearProgressIndicator(),
                  if (_error case final message?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  if (_showInconclusiveDemo) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: const Text(
                        'No concluyente · Demostración',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Text(
                      'Estado simulado para mostrar el flujo. La CNN experimental '
                      'carece de un umbral validado. Puedes tomar o elegir otra foto.',
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _showInconclusiveDemo = false),
                      child: const Text('Volver a las probabilidades'),
                    ),
                  ] else if (_reading case final reading?) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Probabilidades del modelo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'no_visible_signs  ${reading.noVisibleSigns.toStringAsFixed(8)}',
                    ),
                    Text(
                      'possible_scale  ${reading.possibleScale.toStringAsFixed(8)}',
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _showInconclusiveDemo = true),
                      child: const Text('Demostrar el estado no concluyente'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Carga del modelo  ${reading.loadMs.toStringAsFixed(3)} ms',
                    ),
                    Text(
                      'Preparación RGB  ${reading.prepareMs.toStringAsFixed(3)} ms',
                    ),
                    Text(
                      'Mediana de inferencia  ${reading.medianMs.toStringAsFixed(3)} ms',
                    ),
                    Text(
                      'P95 de inferencia  ${reading.p95Ms.toStringAsFixed(3)} ms',
                    ),
                    Text('${reading.repetitions} ejecuciones medidas'),
                    Text(
                      'Diferencia máxima entre salidas  ${reading.maxScoreDelta.toStringAsExponential(2)}',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
