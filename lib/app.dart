import 'package:cropscan/features/scan/inference.dart';
import 'package:cropscan/features/scan/photo_source.dart';
import 'package:cropscan/features/scan/scan_flow.dart';
import 'package:material_ui/material_ui.dart';

class CropScanApp extends StatelessWidget {
  const CropScanApp({
    super.key,
    required this.photos,
    required this.inference,
    this.prototype = false,
  });

  final PhotoSource photos;
  final InferenceService inference;
  final bool prototype;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF215B3B);
    final colors = ColorScheme.fromSeed(seedColor: green).copyWith(
      primary: green,
      surface: const Color(0xFFF8FAF7),
      onSurface: const Color(0xFF17291E),
    );
    const buttonSize = Size(0, 56);

    return MaterialApp(
      title: prototype ? 'CropScan Prototipo' : 'CropScan',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: colors,
        scaffoldBackgroundColor: colors.surface,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: buttonSize),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: buttonSize),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
      ),
      home: ScanFlow(
        photos: photos,
        inference: inference,
        prototype: prototype,
      ),
    );
  }
}
