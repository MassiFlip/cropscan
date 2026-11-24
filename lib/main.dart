import 'package:cropscan/app.dart';
import 'package:cropscan/features/scan/android_inference.dart';
import 'package:cropscan/features/scan/inference.dart';
import 'package:cropscan/features/scan/photo_source.dart';
import 'package:flutter/widgets.dart';

void main() {
  const demo = bool.fromEnvironment('CROPSCAN_DEMO');
  const prototype = bool.fromEnvironment('CROPSCAN_PROTOTYPE');
  runApp(
    CropScanApp(
      photos: AndroidPhotoSource(),
      prototype: prototype,
      inference: demo && !prototype
          ? const DemoInferenceService()
          : const AndroidInferenceService(prototype: prototype),
    ),
  );
}
