import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoOrigin { camera, gallery }

class PhotoFailure implements Exception {
  const PhotoFailure(this.message);
  final String message;
}

abstract interface class PhotoSource {
  Future<Uint8List?> pick(PhotoOrigin origin);
  Future<Uint8List?> recover();
}

class AndroidPhotoSource implements PhotoSource {
  AndroidPhotoSource({ImagePicker? picker, this.maxDimension = 1920})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final double? maxDimension;

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) {
    return _load(
      () => _picker.pickImage(
        source: switch (origin) {
          PhotoOrigin.camera => ImageSource.camera,
          PhotoOrigin.gallery => ImageSource.gallery,
        },
        maxWidth: maxDimension,
        maxHeight: maxDimension,
        requestFullMetadata: false,
      ),
    );
  }

  @override
  Future<Uint8List?> recover() {
    return _load(() async {
      final data = await _picker.retrieveLostData();
      if (data.exception case final exception?) throw exception;
      final files = data.files;
      return files == null || files.isEmpty ? null : files.first;
    });
  }

  Future<Uint8List?> _load(Future<XFile?> Function() read) async {
    try {
      final file = await read();
      if (file == null) return null;
      final length = await file.length();
      if (length == 0 || length > 24 * 1024 * 1024) {
        throw const PhotoFailure(
          'La imagen está vacía o pesa demasiado. Elige otra foto.',
        );
      }
      final bytes = await file.readAsBytes();
      await validatePhoto(bytes);
      return bytes;
    } on PlatformException catch (error) {
      final message = switch (error.code) {
        'camera_access_denied' || 'camera_access_restricted' => 'No se pudo acceder a la cámara. Revisa el permiso en Ajustes o usa la galería.',
        'photo_access_denied' || 'photo_access_restricted' => 'No se pudo acceder a la galería. Revisa el permiso en Ajustes o toma una foto.',
        'no_available_camera' || 'no_camera' =>
          'No hay una cámara disponible. Puedes elegir una foto de la galería.',
        _ => 'No pudimos abrir la foto. Vuelve a intentarlo.',
      };
      throw PhotoFailure(message);
    } on PhotoFailure {
      rethrow;
    } on Exception {
      throw const PhotoFailure(
        'No pudimos leer la foto. Elige una imagen guardada en el teléfono.',
      );
    }
  }
}

/// Verifies decoding before the image can reach the preview or the service.
Future<void> validatePhoto(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 40 * 1000 * 1000) {
      throw const PhotoFailure(
        'La imagen tiene demasiados píxeles. Elige otra foto.',
      );
    }
    final landscape = descriptor.width >= descriptor.height;
    codec = await descriptor.instantiateCodec(
      targetWidth: landscape && descriptor.width > 1200 ? 1200 : null,
      targetHeight: !landscape && descriptor.height > 1200 ? 1200 : null,
    );
    final frame = await codec.getNextFrame();
    frame.image.dispose();
  } on PhotoFailure {
    rethrow;
  } catch (_) {
    throw const PhotoFailure(
      'No pudimos abrir la imagen. Prueba con una foto JPG o PNG.',
    );
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}
