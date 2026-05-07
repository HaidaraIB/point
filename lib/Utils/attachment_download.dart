import 'package:get/get.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/final_deliverable_upload_names.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:url_launcher/url_launcher.dart';

import 'media_url_opener.dart';

/// Opens [rawUrl] in the browser with a suggested filename.
///
/// For **legacy Supabase** URLs, appends the `download` query via
/// [appendSupabaseStorageDownloadQuery]. R2 public URLs already carry the
/// filename in `Content-Disposition` when applicable; the extra query is harmless.
Future<bool> launchAttachmentDownload(String rawUrl) async {
  final trimmed = normalizeUrlForLaunch(rawUrl.trim());
  if (trimmed.isEmpty) return false;
  final name = TaskDetailsDialogHelpers.attachmentFileNameFromUrl(trimmed);
  final withDl =
      name.isNotEmpty
          ? appendSupabaseStorageDownloadQuery(trimmed, name)
          : trimmed;
  final uri = Uri.tryParse(withDl);
  if (uri == null) {
    FunHelper.showSnackbar(
      'error'.tr,
      'errors.cannot_open_link_param'.trParams({'url': trimmed}),
    );
    return false;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    FunHelper.showSnackbar(
      'error'.tr,
      'errors.cannot_open_link_param'.trParams({'url': trimmed}),
    );
  }
  return ok;
}
