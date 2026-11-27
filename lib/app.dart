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
    const green = Color(0xFF315640);
    const ink = Color(0xFF20291F);
    const headingFamily = 'Poppins';
    const interfaceFamily = 'Inter';
    final colors = ColorScheme.fromSeed(seedColor: green).copyWith(
      primary: green,
      primaryContainer: const Color(0xFFDDE9D0),
      onPrimaryContainer: ink,
      surface: const Color(0xFFEDF0E1),
      surfaceContainerLowest: Colors.white,
      surfaceContainer: const Color(0xFFE5EAD9),
      onSurface: ink,
      onSurfaceVariant: const Color(0xFF4F5C4C),
      outline: const Color(0xFF819B77),
      outlineVariant: const Color(0xFFD6DFCE),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: interfaceFamily,
    );
    final corners = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
    );

    return MaterialApp(
      title: prototype ? 'CropScan Prototipo' : 'CropScan',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: base.copyWith(
        scaffoldBackgroundColor: colors.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colors.surface,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 62,
          titleTextStyle: const TextStyle(
            fontFamily: headingFamily,
            fontSize: 19,
            letterSpacing: -0.35,
            color: ink,
            fontWeight: FontWeight.w500,
          ),
        ),
        textTheme: base.textTheme.copyWith(
          headlineSmall: const TextStyle(
            fontFamily: headingFamily,
            fontSize: 23,
            height: 1.18,
            letterSpacing: -0.55,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          titleLarge: const TextStyle(
            fontFamily: headingFamily,
            fontSize: 19,
            height: 1.22,
            letterSpacing: -0.35,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          titleMedium: const TextStyle(
            fontFamily: headingFamily,
            fontSize: 16,
            height: 1.28,
            letterSpacing: -0.2,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontSize: 14,
            height: 1.42,
            letterSpacing: 0,
            color: colors.onSurfaceVariant,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            height: 1.4,
            letterSpacing: 0,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 50),
            shape: corners,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: interfaceFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 50),
            shape: corners,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            side: BorderSide(color: colors.outline),
          ),
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
