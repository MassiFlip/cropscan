import 'package:cropscan/features/experimental/experimental_screen.dart';
import 'package:cropscan/features/scan/photo_source.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  if (!const bool.fromEnvironment('CROPSCAN_EXPERIMENTAL')) {
    throw StateError('Compila con --dart-define=CROPSCAN_EXPERIMENTAL=true.');
  }
  runApp(
    MaterialApp(
      title: 'CropScan Experimental',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315640)),
        fontFamily: 'Inter',
      ),
      home: ExperimentalScreen(
        photos: AndroidPhotoSource(maxDimension: null),
        analyze: analyzeExperimentalPhoto,
      ),
    ),
  );
}
