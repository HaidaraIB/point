import 'package:get/get.dart';
import 'package:point/Services/os_stamp_settings.dart';

/// Uploaded signature image for print/PDF footers (Settings → stamp section).
String osPrintSignatureImageHtml() {
  if (!Get.isRegistered<OsStampSettingsController>()) return '';
  final uri =
      Get.find<OsStampSettingsController>().signatureImageDataUri.value.trim();
  if (uri.isEmpty) return '';
  return '<img class="print-signature-img" src="$uri" alt=""/>';
}
