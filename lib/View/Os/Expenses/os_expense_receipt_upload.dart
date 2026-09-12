import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:point/Services/r2_storage_upload.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/config/app_config.dart';

class OsExpenseReceiptUpload {
  OsExpenseReceiptUpload._();

  static const _uploadTimeout = Duration(seconds: 90);

  static Future<XFile?> pick({ImageSource source = ImageSource.gallery}) {
    return ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
  }

  /// Uploads receipt bytes via the app's R2 presign path (works on web).
  /// Returns null when R2 is not configured or the upload fails/times out.
  static Future<String?> upload({
    required String expenseId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      if (AppConfig.r2SignerUrl.trim().isEmpty) {
        appLog('expense receipt upload skipped: R2 signer not configured');
        return null;
      }
      // Worker assigns the object key; fileName is used for extension only.
      final fileName =
          'os-expense-$expenseId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      return await uploadObjectToR2(
        data: bytes,
        fileName: fileName,
        contentType: contentType,
      ).timeout(_uploadTimeout);
    } catch (e, st) {
      appLog('expense receipt upload failed: $e\n$st');
      return null;
    }
  }
}
