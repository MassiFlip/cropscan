import 'dart:typed_data';

import 'package:cropscan/features/scan/inference.dart';
import 'package:cropscan/features/scan/photo_source.dart';
import 'package:material_ui/material_ui.dart';

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFFFE8BD),
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'DEMO',
            style: TextStyle(
              color: Color(0xFF5B3807),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.busy,
    required this.demo,
    required this.prototype,
    required this.onStart,
  });

  final bool busy;
  final bool demo;
  final bool prototype;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(28)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF173E2A), Color(0xFF276244)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFDBEFC4),
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.eco_outlined,
                      color: Color(0xFF173E2A),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  prototype
                      ? 'Revisa marcas visibles'
                      : 'Revisa tu palta Naval',
                  style: text.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  prototype
                      ? 'Fotografía de cerca una hoja o un fruto de palta.'
                      : 'Fotografía una hoja o un fruto de tu cultivo en Huaral.',
                  style: text.bodyLarge?.copyWith(
                    color: const Color(0xFFE6F4DF),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (demo) ...[
          const ScanMessage(
            icon: Icons.science_outlined,
            message: 'Modo DEMO. La aplicación muestra resultados de ejemplo y no detecta queresas en la foto.',
          ),
          const SizedBox(height: 16),
        ],
        if (busy)
          const LinearProgressIndicator(semanticsLabel: 'Recuperando foto'),
        FilledButton.icon(
          onPressed: busy ? null : onStart,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Empezar con una foto'),
        ),
      ],
    );
  }
}

class SourceView extends StatelessWidget {
  const SourceView({
    super.key,
    required this.busy,
    required this.onPick,
    this.onKeep,
  });

  final bool busy;
  final ValueChanged<PhotoOrigin> onPick;
  final VoidCallback? onKeep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          title: 'Agrega una foto',
          description: 'Puedes tomarla ahora o elegir una del teléfono.',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : () => onPick(PhotoOrigin.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Tomar foto'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : () => onPick(PhotoOrigin.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Elegir de la galería'),
        ),
        if (onKeep != null)
          TextButton(
            onPressed: busy ? null : onKeep,
            child: const Text('Volver a la foto anterior'),
          ),
        const SizedBox(height: 20),
        if (busy) ...[
          const LinearProgressIndicator(semanticsLabel: 'Abriendo foto'),
          const SizedBox(height: 16),
        ],
        const ScanMessage(
          icon: Icons.light_mode_outlined,
          message: 'Busca buena luz, acerca la cámara y enfoca la zona que quieres revisar.',
        ),
      ],
    );
  }
}

class PreviewView extends StatelessWidget {
  const PreviewView({
    super.key,
    required this.photo,
    required this.onAnalyze,
    required this.onReplace,
    required this.scenario,
    required this.onScenarioChanged,
  });

  final Uint8List photo;
  final VoidCallback onAnalyze;
  final VoidCallback onReplace;
  final DemoScenario? scenario;
  final ValueChanged<DemoScenario> onScenarioChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          title: 'Revisa la foto',
          description: 'Comprueba que la hoja o el fruto se vea con claridad.',
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Image(
                image: ResizeImage(
                  MemoryImage(photo),
                  width: 1200,
                  height: 1200,
                  policy: ResizeImagePolicy.fit,
                ),
                fit: BoxFit.contain,
                semanticLabel: 'Foto de la hoja o el fruto que vas a revisar',
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (scenario case final selected?) ...[
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Escenario simulado',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DemoScenario>(
                value: selected,
                isExpanded: true,
                items: [
                  for (final option in DemoScenario.values)
                    DropdownMenuItem(
                      value: option,
                      child: Text(
                        option.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onScenarioChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          onPressed: onAnalyze,
          icon: const Icon(Icons.document_scanner_outlined),
          label: Text(scenario == null ? 'Analizar foto' : 'Simular análisis'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onReplace,
          child: const Text('Reemplazar foto'),
        ),
      ],
    );
  }
}

class ProcessingView extends StatelessWidget {
  const ProcessingView({super.key, required this.demo});

  final bool demo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Center(
          child: CircularProgressIndicator(
            semanticsLabel: demo ? 'Simulando análisis' : 'Analizando foto',
          ),
        ),
        const SizedBox(height: 28),
        _SectionHeading(
          title: demo ? 'Simulando análisis' : 'Analizando foto',
          description: demo
              ? 'Estamos preparando el resultado de ejemplo.'
              : 'El análisis se realiza en tu teléfono.',
        ),
      ],
    );
  }
}

class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    required this.result,
    required this.demo,
    required this.prototype,
    required this.onRetake,
    required this.onFinish,
  });

  final InferenceResult result;
  final bool demo;
  final bool prototype;
  final VoidCallback onRetake;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final category = result.classify();
    final label = prototype
        ? switch (category) {
            ScanClass.possibleScale => 'Marcas visibles',
            ScanClass.noVisibleSigns => 'Sin marcas evidentes',
            ScanClass.inconclusive => 'No concluyente',
          }
        : category.label;
    final (icon, orientation) = switch (category) {
      ScanClass.possibleScale => (
        Icons.search,
        'Si observas señales que te preocupan en la planta, pide una revisión a un especialista agrícola.',
      ),
      ScanClass.noVisibleSigns => (
        Icons.eco_outlined,
        'Sigue observando hojas y frutos. Si encuentras cambios, pide una revisión.',
      ),
      ScanClass.inconclusive => (
        Icons.help_outline,
        'Repite la foto con buena luz y enfoca la zona. Si la duda continúa, consulta a un especialista agrícola.',
      ),
    };
    final percent = (result.confidence * 100).round();
    final confidence = demo ? 'Confianza simulada' : 'Confianza estimada';
    final confidenceLevel = category == ScanClass.inconclusive
        ? 'baja'
        : 'suficiente';
    final score = prototype
        ? 'Puntaje del prototipo: ${(result.confidence * 100).toStringAsFixed(1)} %'
        : '$confidence: $percent % ($confidenceLevel)';
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: category == ScanClass.inconclusive
                ? const Color(0xFFFFF1D7)
                : colors.primaryContainer,
            borderRadius: const BorderRadius.all(Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 30),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(score),
                const SizedBox(height: 8),
                ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: result.confidence,
                    borderRadius: BorderRadius.circular(12),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (demo) ...[
          const SizedBox(height: 16),
          const ScanMessage(
            icon: Icons.science_outlined,
            message: 'Este resultado es un ejemplo simulado. No indica el estado de tu cultivo.',
          ),
        ],
        const SizedBox(height: 20),
        _SectionHeading(title: 'Qué puedes hacer', description: orientation),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onRetake,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(
            category == ScanClass.inconclusive
                ? 'Repetir foto'
                : 'Usar otra foto',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onFinish,
          child: const Text('Volver al inicio'),
        ),
      ],
    );
  }
}

class ScanMessage extends StatelessWidget {
  const ScanMessage({
    super.key,
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = isError ? colors.onErrorContainer : colors.onSurface;
    return Semantics(
      liveRegion: isError,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.surfaceContainer,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: TextStyle(color: foreground)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Text(description, style: text.bodyLarge),
      ],
    );
  }
}
