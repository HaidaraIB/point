import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/Utils/chat_image_compress.dart';

class AttendancePhotoCapture {
  const AttendancePhotoCapture({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

class AttendancePhotoHelper {
  AttendancePhotoHelper._();

  static Future<AttendancePhotoCapture?> capture({
    required String action,
    required String employeeId,
  }) async {
    try {
      final xFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );
      if (xFile == null) return null;

      var bytes = await xFile.readAsBytes();
      if (bytes.isEmpty) return null;

      final baseName =
          'attendance_${employeeId.trim()}_${action}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (isChatCompressibleImageFileName(baseName)) {
        bytes = await compressChatImage(bytes, baseName);
      }

      return AttendancePhotoCapture(bytes: bytes, fileName: baseName);
    } catch (e, st) {
      appLog('AttendancePhotoHelper.capture failed: $e', error: e, stackTrace: st);
      return null;
    }
  }
}
