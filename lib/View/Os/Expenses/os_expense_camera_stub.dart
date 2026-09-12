import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Non-web: open the device camera via image_picker.
Future<Uint8List?> captureOsExpenseCamera(BuildContext context) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 70,
    maxWidth: 1600,
    preferredCameraDevice: CameraDevice.rear,
  );
  if (file == null) return null;
  return file.readAsBytes();
}
