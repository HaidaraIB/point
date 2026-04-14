import 'package:get/get.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/View/Mobile/Shared/VideoCart.dart';
import 'package:url_launcher/url_launcher.dart';

String _mediaPathLower(String rawUrl) {
  try {
    return Uri.parse(rawUrl).path.toLowerCase();
  } catch (_) {
    return rawUrl.toLowerCase();
  }
}

bool isImageMediaUrl(String rawUrl) {
  final p = _mediaPathLower(rawUrl);
  return p.endsWith('.png') ||
      p.endsWith('.jpg') ||
      p.endsWith('.jpeg') ||
      p.endsWith('.gif') ||
      p.endsWith('.webp');
}

bool isVideoMediaUrl(String rawUrl) {
  final p = _mediaPathLower(rawUrl);
  return p.endsWith('.mp4') ||
      p.endsWith('.mov') ||
      p.endsWith('.webm') ||
      p.endsWith('.m4v') ||
      p.endsWith('.avi') ||
      p.endsWith('.mkv');
}

Future<bool> openUrlPreferInAppMedia(
  String rawUrl, {
  bool showErrorSnackbar = true,
}) async {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return false;

  if (isImageMediaUrl(trimmed)) {
    Get.to(() => ImagePreviewPage(url: trimmed));
    return true;
  }
  if (isVideoMediaUrl(trimmed)) {
    Get.to(() => VideoPlayerPage(url: trimmed));
    return true;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    if (showErrorSnackbar) {
      FunHelper.showSnackbar(
        'error'.tr,
        'errors.cannot_open_link_param'.trParams({'url': trimmed}),
      );
    }
    return false;
  }

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && showErrorSnackbar) {
    FunHelper.showSnackbar(
      'error'.tr,
      'errors.cannot_open_link_param'.trParams({'url': trimmed}),
    );
  }
  return ok;
}
