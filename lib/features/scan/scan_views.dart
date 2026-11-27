import 'dart:typed_data';

import 'package:cropscan/features/scan/inference.dart';
import 'package:cropscan/features/scan/photo_source.dart';
import 'package:material_ui/material_ui.dart';

class CropScanMark extends StatelessWidget {
  const CropScanMark({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(Icons.eco_rounded, color: colors.onPrimary, size: 22),
      ),
    );
  }
}

class ScanBadge extends StatelessWidget {
  const ScanBadge({super.key, required this.label, this.warm = false});

  final String label;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: warm ? const Color(0xFFF4E0B8) : colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: warm ? const Color(0xFF53370E) : colors.onPrimaryContainer,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class ScanSteps extends StatelessWidget {
  const ScanSteps({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const stages = ['Foto', 'Revisión', 'Resultado'];
    return Semantics(
      label: 'Paso $step de 3: ${stages[step - 1]}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paso $step de 3 · ${stages[step - 1]}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              spacing: 6,
              children: [
                for (var position = 1; position <= stages.length; position++)
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: position <= step
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ],
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
    required this.onGallery,
  });

  final bool busy;
  final bool demo;
  final bool prototype;
  final VoidCallback onStart;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              AspectRatio(
                aspectRatio: 1.72,
                child: Image.asset(
                  'assets/images/palta-hojas.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.25),
                  semanticLabel: 'Hojas verdes de palta',
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.25, 1],
                      colors: [Color(0x0019251C), Color(0xE619251C)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revisa tu cultivo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prototype
                          ? 'Observa las marcas visibles de una hoja o un fruto.'
                          : 'Revisa una hoja o un fruto de palta Naval.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFE5ECDB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Surface(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: 11,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _IconTile(icon: Icons.center_focus_strong_outlined),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revisión por fotografía',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enfoca la zona que quieres revisar.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (busy) ...[
                const LinearProgressIndicator(semanticsLabel: 'Abriendo foto'),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: busy ? null : onStart,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Analizar planta'),
              ),
              TextButton.icon(
                onPressed: busy ? null : onGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Elegir de la galería'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Surface(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Consejos para tu foto', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              const _PhotoTip(
                icon: Icons.wb_sunny_outlined,
                text: 'Busca luz natural.',
              ),
              const _PhotoTip(
                icon: Icons.crop_free_rounded,
                text: 'Acércate a la hoja o al fruto.',
              ),
              const _PhotoTip(
                icon: Icons.center_focus_strong_outlined,
                text: 'Comprueba que quede enfocado.',
              ),
            ],
          ),
        ),
        if (demo || prototype) ...[
          const SizedBox(height: 12),
          Text(
            demo ? 'Modo demo con ejemplos simulados.' : 'Prototipo experimental de marcas visibles. La causa requiere revisión agrícola.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _PhotoTip extends StatelessWidget {
  const _PhotoTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        spacing: 10,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class SourceView extends StatelessWidget {
  const SourceView({
    super.key,
    required this.busy,
    required this.onPick,
    required this.onCancel,
    this.onKeep,
  });

  final bool busy;
  final ValueChanged<PhotoOrigin> onPick;
  final VoidCallback onCancel;
  final VoidCallback? onKeep;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading(
          title: 'Agrega una foto',
          description: 'Elige cómo quieres capturar la zona que vas a revisar.',
        ),
        const SizedBox(height: 18),
        _SourceOption(
          icon: Icons.photo_camera_outlined,
          label: 'Tomar foto',
          description: 'Abre la cámara del teléfono.',
          background: colors.primaryContainer,
          onTap: busy ? null : () => onPick(PhotoOrigin.camera),
        ),
        const SizedBox(height: 10),
        _SourceOption(
          icon: Icons.photo_library_outlined,
          label: 'Elegir de la galería',
          description: 'Usa una foto guardada en tu teléfono.',
          background: colors.surfaceContainerLowest,
          onTap: busy ? null : () => onPick(PhotoOrigin.gallery),
        ),
        if (busy) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(semanticsLabel: 'Abriendo foto'),
        ],
        const SizedBox(height: 16),
        const _CardNote(
          icon: Icons.center_focus_strong_outlined,
          title: 'Enfoca la zona de interés',
          description: 'Procura que la hoja o el fruto ocupe buena parte de la foto y evita las sombras fuertes.',
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: busy ? null : onKeep ?? onCancel,
          child: Text(
            onKeep == null ? 'Cancelar' : 'Volver a la foto anterior',
          ),
        ),
      ],
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: colors.onSurface,
        backgroundColor: background,
        disabledBackgroundColor: colors.surfaceContainer,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Row(
        spacing: 12,
        children: [
          _IconTile(icon: icon, background: colors.surfaceContainerLowest),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }
}

class PreviewView extends StatelessWidget {
  const PreviewView({
    super.key,
    required this.photo,
    required this.onAnalyze,
    required this.onReplace,
    required this.onCancel,
    required this.scenario,
    required this.onScenarioChanged,
  });

  final Uint8List photo;
  final VoidCallback onAnalyze;
  final VoidCallback onReplace;
  final VoidCallback onCancel;
  final DemoScenario? scenario;
  final ValueChanged<DemoScenario> onScenarioChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading(
          title: 'Revisa la foto',
          description: 'Verifica que la zona que quieres analizar esté iluminada y nítida.',
        ),
        const SizedBox(height: 16),
        _PhotoFrame(photo: photo, label: 'Foto que vas a analizar'),
        const SizedBox(height: 18),
        if (scenario case final selected?) ...[
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Escenario simulado',
              filled: true,
              fillColor: colors.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DemoScenario>(
                style: Theme.of(context).textTheme.bodyLarge,
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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onReplace,
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Reemplazar foto'),
        ),
        TextButton(onPressed: onCancel, child: const Text('Cancelar')),
      ],
    );
  }
}

class ProcessingView extends StatelessWidget {
  const ProcessingView({super.key, required this.demo, required this.photo});

  final bool demo;
  final Uint8List photo;

  @override
  Widget build(BuildContext context) {
    final title = demo ? 'Simulando análisis' : 'Analizando fotografía';
    return _PhotoAndSheet(
      photo: photo,
      label: 'Foto en proceso de análisis',
      sheet: _AnalysisSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(
              title: title,
              description: demo
                  ? 'Estamos preparando el resultado de ejemplo.'
                  : 'CropScan está revisando la imagen en tu teléfono.',
            ),
            const SizedBox(height: 18),
            LinearProgressIndicator(
              minHeight: 5,
              borderRadius: BorderRadius.circular(5),
              semanticsLabel: title,
            ),
          ],
        ),
      ),
    );
  }
}

class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    required this.result,
    required this.photo,
    required this.demo,
    required this.prototype,
    required this.onRetake,
    required this.onFinish,
  });

  final InferenceResult result;
  final Uint8List photo;
  final bool demo;
  final bool prototype;
  final VoidCallback onRetake;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final category = result.classify();
    final uncertain = category == ScanClass.inconclusive;
    final label = prototype
        ? switch (category) {
            ScanClass.possibleScale => 'Marcas visibles',
            ScanClass.noVisibleSigns => 'Sin marcas evidentes',
            ScanClass.inconclusive => 'No concluyente',
          }
        : category.label;
    final (icon, explanation, guidance) = switch (category) {
      ScanClass.possibleScale => (
        Icons.search_rounded,
        prototype
            ? 'El prototipo identificó marcas en la imagen. Su causa sigue pendiente de revisión.'
            : 'La foto presenta señales que podrían ser compatibles con queresa.',
        'Muestra la foto y revisa la planta con un especialista agrícola.',
      ),
      ScanClass.noVisibleSigns => (
        Icons.eco_outlined,
        prototype
            ? 'El prototipo no encontró marcas evidentes en esta imagen.'
            : 'El modelo no encontró señales evidentes de queresa en esta imagen.',
        'Sigue observando hojas y frutos. Si ves algún cambio, toma otra foto.',
      ),
      ScanClass.inconclusive => (
        Icons.help_outline_rounded,
        'La imagen no permite clasificar el resultado con suficiente seguridad.',
        'Acércate a la zona, busca mejor luz y vuelve a tomar la foto.',
      ),
    };
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final score = prototype
        ? 'Puntaje del prototipo: ${(result.confidence * 100).toStringAsFixed(1)} %'
        : 'Confianza estimada: ${(result.confidence * 100).round()} %';

    return _PhotoAndSheet(
      photo: photo,
      label: 'Fotografía analizada',
      sheet: _AnalysisSheet(
        warm: uncertain,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: 11,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconTile(
                  icon: icon,
                  background: colors.surfaceContainerLowest,
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(label, style: theme.textTheme.headlineSmall),
                  ),
                ),
              ],
            ),
            if (!demo) ...[
              const SizedBox(height: 12),
              Text(
                score,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: uncertain ? const Color(0xFF775520) : colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: result.confidence,
                  borderRadius: BorderRadius.circular(6),
                  minHeight: 6,
                  color: uncertain ? const Color(0xFF90652C) : colors.primary,
                  backgroundColor: const Color(0xFFF5F7EF),
                ),
              ),
            ],
            const SizedBox(height: 11),
            Text(
              demo
                  ? 'Este escenario muestra cómo se vería el resultado en la aplicación.'
                  : explanation,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 13),
            _CardNote(
              icon: uncertain
                  ? Icons.photo_camera_outlined
                  : Icons.arrow_forward_rounded,
              title: 'Qué puedes hacer',
              description: guidance,
            ),
            const SizedBox(height: 10),
            Text(
              demo ? 'MODO DEMO. Este ejemplo simulado no evalúa tu cultivo.' : 'Evaluación orientativa. CropScan no reemplaza el diagnóstico de un especialista.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetake,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(uncertain ? 'Repetir foto' : 'Nuevo análisis'),
            ),
            TextButton(
              onPressed: onFinish,
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoAndSheet extends StatelessWidget {
  const _PhotoAndSheet({
    required this.photo,
    required this.label,
    required this.sheet,
  });

  final Uint8List photo;
  final String label;
  final Widget sheet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final photoHeight = (constraints.maxWidth * 1.01).clamp(235.0, 440.0);
        return Stack(
          children: [
            SizedBox(
              height: photoHeight,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: ResizeImage(
                        MemoryImage(photo),
                        width: 1200,
                        height: 1200,
                        policy: ResizeImagePolicy.fit,
                      ),
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, 0.13),
                      semanticLabel: label,
                    ),
                    const IgnorePointer(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(29, 24, 29, 52),
                        child: CustomPaint(painter: _FocusPainter()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(10, photoHeight - 33, 10, 0),
              child: sheet,
            ),
          ],
        );
      },
    );
  }
}

class _FocusPainter extends CustomPainter {
  const _FocusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final edge = (size.shortestSide * 0.2).clamp(24.0, 52.0);
    const curve = 18.0;
    final w = size.width;
    final h = size.height;
    final outline = Path()
      ..moveTo(0, edge)
      ..lineTo(0, curve)
      ..quadraticBezierTo(0, 0, curve, 0)
      ..lineTo(edge, 0)
      ..moveTo(w - edge, 0)
      ..lineTo(w - curve, 0)
      ..quadraticBezierTo(w, 0, w, curve)
      ..lineTo(w, edge)
      ..moveTo(w, h - edge)
      ..lineTo(w, h - curve)
      ..quadraticBezierTo(w, h, w - curve, h)
      ..lineTo(w - edge, h)
      ..moveTo(edge, h)
      ..lineTo(curve, h)
      ..quadraticBezierTo(0, h, 0, h - curve)
      ..lineTo(0, h - edge);
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFFE6F1CF)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_FocusPainter oldDelegate) => false;
}

class _AnalysisSheet extends StatelessWidget {
  const _AnalysisSheet({required this.child, this.warm = false});

  final Widget child;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: warm
              ? const [Color(0xFFFCF6E8), Color(0xFFEDE3C9)]
              : const [Color(0xFFF5F6EC), Color(0xFFD5E3BF)],
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFF9FAF1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x241B2F22),
            blurRadius: 19,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(15), child: child),
    );
  }
}

class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({required this.photo, required this.label});

  final Uint8List photo;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: const Color(0xFF20352B),
          child: Image(
            image: ResizeImage(
              MemoryImage(photo),
              width: 1200,
              height: 1200,
              policy: ResizeImagePolicy.fit,
            ),
            fit: BoxFit.contain,
            semanticLabel: label,
          ),
        ),
      ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = isError
        ? colors.onErrorContainer
        : colors.onSurfaceVariant;
    return Semantics(
      liveRegion: isError,
      child: _Surface(
        background: isError ? colors.errorContainer : colors.surfaceContainer,
        padding: const EdgeInsets.all(13),
        child: Row(
          spacing: 10,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground, size: 20),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.background,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final Color? background;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? colors.surfaceContainerLowest,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C19372A),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.background});

  final IconData icon;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? colors.primaryContainer,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(icon, color: colors.primary, size: 22),
      ),
    );
  }
}

class _CardNote extends StatelessWidget {
  const _CardNote({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Surface(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          _IconTile(icon: icon),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: text.headlineSmall)),
        const SizedBox(height: 8),
        Text(description, style: text.bodyLarge),
      ],
    );
  }
}
