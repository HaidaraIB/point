import 'package:get/get.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Non-web: print HTML is unavailable; show [fallbackKey] or run [onUnsupported].
Future<void> openOsPrintDocument({
  required String html,
  required String titleKey,
  required String fallbackKey,
  Future<void> Function()? onUnsupported,
}) async {
  if (onUnsupported != null) {
    await onUnsupported();
    return;
  }
  OsSnackbar.error(titleKey.tr, fallbackKey.tr);
}
