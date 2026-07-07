import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/LibraryFileModel.dart';
import 'package:point/Utils/attachment_download.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:point/View/Tasks/Shared/task_attachment_gallery.dart';

class LibraryDirectFileCard extends StatelessWidget {
  final LibraryFileModel file;
  final VoidCallback? onDeleted;

  const LibraryDirectFileCard({
    super.key,
    required this.file,
    this.onDeleted,
  });

  String _formatTs(DateTime d) {
    final loc = Get.locale?.toLanguageTag() ?? 'ar';
    return DateFormat.yMMMd(loc).add_jm().format(d.toLocal());
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final id = file.id;
    if (id == null || id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('library.delete_file'.tr),
        content: Text('library.delete_file_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final hc = Get.find<HomeController>();
    final deleted = await hc.deleteLibraryFile(id);
    if (deleted) onDeleted?.call();
  }

  Widget _compactActionIcon({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 20,
      padding: const EdgeInsets.all(4),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = file.url.trim();
    final name = file.fileName.trim().isEmpty
        ? TaskDetailsDialogHelpers.attachmentFileNameFromUrl(u)
        : file.fileName.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.insert_drive_file_outlined, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        'library.direct_upload_label'.tr,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${'library.uploaded_at'.tr}: ${_formatTs(file.uploadedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (u.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 104,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 88,
                              height: 88,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: TaskDetailsDialogHelpers.attachmentThumbnail(
                                  u,
                                  onOpen: () => openUrlPreferInAppMedia(u),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 0,
                              runSpacing: 0,
                              children: [
                                _compactActionIcon(
                                  tooltip: 'library.download_file'.tr,
                                  icon: Icons.download_outlined,
                                  onPressed: () => launchAttachmentDownload(u),
                                ),
                                if (isImageMediaUrl(u))
                                  _compactActionIcon(
                                    tooltip: 'tasks.attachment_gallery'.tr,
                                    icon: Icons.collections_outlined,
                                    onPressed: () => openTaskAttachmentGallery(
                                      imageUrls: [u],
                                      initialIndex: 0,
                                    ),
                                  ),
                                _compactActionIcon(
                                  tooltip: 'library.delete_file'.tr,
                                  icon: Icons.delete_outline,
                                  onPressed: () => _confirmDelete(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
