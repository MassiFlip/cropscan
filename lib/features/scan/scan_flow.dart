import 'dart:typed_data';

import 'package:cropscan/features/scan/inference.dart';
import 'package:cropscan/features/scan/photo_source.dart';
import 'package:cropscan/features/scan/scan_views.dart';
import 'package:material_ui/material_ui.dart';

enum _Step { home, source, preview, processing, result }

class ScanFlow extends StatefulWidget {
  const ScanFlow({
    super.key,
    required this.photos,
    required this.inference,
    required this.prototype,
  });

  final PhotoSource photos;
  final InferenceService inference;
  final bool prototype;

  @override
  State<ScanFlow> createState() => _ScanFlowState();
}

class _ScanFlowState extends State<ScanFlow> {
  _Step _step = _Step.home;
  Uint8List? _photo;
  InferenceResult? _result;
  String? _error;
  DemoScenario _scenario = DemoScenario.possibleScale;
  bool _readingPhoto = true;
  bool _replacing = false;

  bool get _busy => _readingPhoto || _step == _Step.processing;

  @override
  void initState() {
    super.initState();
    if (widget.inference case final DemoInferenceService demo) {
      _scenario = demo.scenario;
    }
    _readPhoto(widget.photos.recover);
  }

  Future<void> _pickPhoto(PhotoOrigin origin) async {
    if (_busy) return;
    setState(() {
      _readingPhoto = true;
      _error = null;
    });
    await _readPhoto(() => widget.photos.pick(origin));
  }

  Future<void> _readPhoto(Future<Uint8List?> Function() read) async {
    try {
      final photo = await read();
      if (!mounted || photo == null) return;
      setState(() {
        _photo = photo;
        _step = _Step.preview;
        _replacing = false;
      });
    } on PhotoFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos abrir la foto. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _readingPhoto = false);
    }
  }

  Future<void> _analyze() async {
    final photo = _photo;
    if (_busy || photo == null) return;
    final service = widget.inference;
    final analysis = service is DemoInferenceService
        ? DemoInferenceService(scenario: _scenario, delay: service.delay)
        : service;
    final elapsed = Stopwatch()..start();
    setState(() {
      _step = _Step.processing;
      _error = null;
    });
    try {
      final result = await analysis.analyze(photo);
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = _Step.result;
      });
      if (!analysis.isDemo) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          elapsed.stop();
          debugPrint('CropScan analysis_ms=${elapsed.elapsedMilliseconds}');
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is InferenceFailure
            ? error.message
            : 'No pudimos completar el análisis. Intenta otra vez.';
        _step = _Step.preview;
      });
    }
  }

  void _openSource({bool replacing = false}) {
    setState(() {
      if (!replacing) {
        _photo = null;
        _result = null;
      }
      _replacing = replacing;
      _error = null;
      _step = _Step.source;
    });
  }

  void _goBack() {
    if (_busy) return;
    setState(() {
      _error = null;
      _step = switch (_step) {
        _Step.source when _replacing => _Step.preview,
        _Step.preview => _Step.source,
        _ => _Step.home,
      };
      if (_step != _Step.preview) _photo = null;
      _result = null;
      _replacing = false;
    });
  }

  void _closeScan() {
    if (_busy) return;
    setState(() {
      _step = _Step.home;
      _photo = null;
      _result = null;
      _error = null;
      _replacing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final demo = widget.inference.isDemo;
    final prototype = widget.prototype;
    final modeBadge = demo || prototype
        ? ScanBadge(label: demo ? 'MODO DEMO' : 'Prototipo', warm: demo)
        : null;
    final compactHeader =
        MediaQuery.sizeOf(context).width < 340 ||
        MediaQuery.textScalerOf(context).scale(19) >= 31;
    final title = switch (_step) {
      _Step.home => 'CropScan',
      _Step.source => 'Elegir foto',
      _Step.preview => 'Vista previa',
      _Step.processing => 'Procesamiento',
      _Step.result => 'Resultado',
    };
    final stage = switch (_step) {
      _Step.home => null,
      _Step.source => 1,
      _Step.preview => 2,
      _Step.result || _Step.processing => null,
    };
    final content = switch (_step) {
      _Step.home => HomeView(
        busy: _readingPhoto,
        demo: demo,
        prototype: prototype,
        onStart: () => _openSource(),
        onGallery: () => _pickPhoto(PhotoOrigin.gallery),
      ),
      _Step.source => SourceView(
        busy: _readingPhoto,
        onPick: _pickPhoto,
        onCancel: _closeScan,
        onKeep: _replacing ? _goBack : null,
      ),
      _Step.preview => PreviewView(
        photo: _photo!,
        onAnalyze: _analyze,
        onReplace: () => _openSource(replacing: true),
        onCancel: _closeScan,
        scenario: widget.inference is DemoInferenceService ? _scenario : null,
        onScenarioChanged: (scenario) => setState(() => _scenario = scenario),
      ),
      _Step.processing => ProcessingView(demo: demo, photo: _photo!),
      _Step.result => ResultView(
        result: _result!,
        photo: _photo!,
        demo: demo,
        prototype: prototype,
        onRetake: () => _openSource(),
        onFinish: _closeScan,
      ),
    };

    return PopScope<void>(
      canPop: _step == _Step.home && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: _step != _Step.home && !compactHeader,
          leading: _step != _Step.home && !_busy
              ? Center(
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: BackButton(onPressed: _goBack),
                  ),
                )
              : null,
          title: _step == _Step.home
              ? const Row(
                  spacing: 10,
                  children: [
                    CropScanMark(),
                    Flexible(
                      child: Text('CropScan', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                )
              : Text(title),
          actions: [
            if (modeBadge != null && !compactHeader)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: Center(child: modeBadge),
              ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => TweenAnimationBuilder<double>(
              key: ValueKey(_step),
              tween: Tween(begin: 0.86, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              builder: (_, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: SingleChildScrollView(
                key: ValueKey(_step),
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth < 360 ? 10 : 16,
                  8,
                  constraints.maxWidth < 360 ? 10 : 16,
                  24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (modeBadge != null && compactHeader) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: modeBadge,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (stage != null) ...[
                          ScanSteps(step: stage),
                          const SizedBox(height: 18),
                        ],
                        if (_error case final message?) ...[
                          ScanMessage(
                            icon: Icons.error_outline,
                            message: message,
                            isError: true,
                          ),
                          const SizedBox(height: 16),
                        ],
                        content,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
