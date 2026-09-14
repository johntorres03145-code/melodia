import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Selecciona una imagen de la galería y la devuelve como bytes.
class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  /// Devuelve la imagen elegida como bytes, o null si se cancela.
  Future<Uint8List?> pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 85,
      );
      if (file == null) return null;
      return await file.readAsBytes();
    } catch (e) {
      _debugLog(e);
      return null;
    }
  }

  void _debugLog(Object e) {
    debugPrint('ImagePickerService: $e');
  }
}
