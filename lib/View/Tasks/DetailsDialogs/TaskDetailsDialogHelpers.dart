import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/media_url_opener.dart';

/// Shared helpers for task details dialogs (web). Used by GenericTaskDetailsDialog
/// and type-specific sections to avoid duplication.
class TaskDetailsDialogHelpers {
  TaskDetailsDialogHelpers._();

  static double gridCellWidth(
    double maxWidth, {
    int columns = 3,
    double spacing = 12,
    double min = 140,
    double max = 260,
  }) {
    if (columns <= 0) return min;
    final raw = (maxWidth - (spacing * (columns - 1))) / columns;
    return raw.clamp(min, max);
  }

  static Color getPriorityColor(String priority) {
    switch (priority) {
      case 'normal':
        return Colors.blue;
      case 'imp':
        return Colors.orange;
      case 'veryimp':
        return Colors.red;
      case 'veryveryimp':
        return Colors.red.shade900;
      default:
        return Colors.green;
    }
  }

  static Color getPriorityBgColor(String priority) {
    switch (priority) {
      case 'normal':
        return Colors.blue.shade50;
      case 'imp':
        return Colors.orange.shade50;
      case 'veryimp':
        return Colors.red.shade50;
      case 'veryveryimp':
        return Colors.red.shade100;
      default:
        return Colors.green.shade50;
    }
  }

  /// Priority tag widget using standard priority colors.
  static Widget buildTag(String text, {bool tr = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getPriorityBgColor(text),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tr ? FunHelper.translateAppKey(text) : text,
        style: TextStyle(
          color: getPriorityColor(text),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Info box for web details dialog (row layout, fixed width per cell).
  static Widget infoBox(
    String title,
    String value, {
    Widget? child,
    double? width,
    double? height,
  }) {
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: height ?? 0),
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          child ??
              Tooltip(
                message: value,
                child: LinkifiedText(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primaryfontColor,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  /// Date info box with icon (for web details dialog).
  static Widget infoBoxDates(String title, String? value, IconData icon) {
    return Container(
      width: 170,
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.grey),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppColors.primaryfontColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Attachment card with download button.
  static Widget attachmentCard(
    String title,
    String size, {
    required VoidCallback onDownload,
  }) {
    return Container(
      width: 200,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.withValues(alpha: 0.2),
                radius: 14,
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Tooltip(
                  message: title,
                  child: Text(
                    title,
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primaryfontColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(size, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download, size: 18),
            label: Text('tasks.download'.tr),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: const Color(0xffF9F5FF),
              foregroundColor: Colors.blue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }

  static String _attachmentPathLower(String rawUrl) {
    try {
      return Uri.parse(rawUrl).path.toLowerCase();
    } catch (_) {
      return rawUrl.toLowerCase();
    }
  }

  /// Last path segment of [raw] for display (decoded), or `download` query if present.
  static String attachmentFileNameFromUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return v;
    final uri = Uri.tryParse(v);
    if (uri != null) {
      final dl = uri.queryParameters['download'];
      if (dl != null && dl.trim().isNotEmpty) {
        return dl.trim();
      }
      if (uri.pathSegments.isNotEmpty) {
        return Uri.decodeComponent(uri.pathSegments.last);
      }
    }
    return v.length > 48 ? '${v.substring(0, 45)}…' : v;
  }

  /// Icon for non-image attachments from URL path extension.
  static IconData iconForAttachmentUrl(String rawUrl) {
    final p = _attachmentPathLower(rawUrl);
    if (p.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (p.endsWith('.zip') ||
        p.endsWith('.rar') ||
        p.endsWith('.7z')) {
      return Icons.folder_zip_outlined;
    }
    if (p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.webm') ||
        p.endsWith('.mkv') ||
        p.endsWith('.m4v')) {
      return Icons.video_file_outlined;
    }
    if (p.endsWith('.mp3') ||
        p.endsWith('.wav') ||
        p.endsWith('.aac') ||
        p.endsWith('.m4a') ||
        p.endsWith('.flac')) {
      return Icons.audio_file_outlined;
    }
    if (p.endsWith('.doc') ||
        p.endsWith('.docx') ||
        p.endsWith('.odt')) {
      return Icons.description_outlined;
    }
    if (p.endsWith('.xls') ||
        p.endsWith('.xlsx') ||
        p.endsWith('.ods')) {
      return Icons.table_chart_outlined;
    }
    if (p.endsWith('.ppt') ||
        p.endsWith('.pptx') ||
        p.endsWith('.odp')) {
      return Icons.slideshow_outlined;
    }
    if (p.endsWith('.txt') ||
        p.endsWith('.csv') ||
        p.endsWith('.json') ||
        p.endsWith('.xml')) {
      return Icons.article_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  /// Thumbnail tile used in task details dialogs.
  /// Tapping the thumbnail triggers [onOpen] (same behavior as "تنزيل").
  static Widget attachmentThumbnail(
    String url, {
    required VoidCallback onOpen,
  }) {
    final isImage = isImageMediaUrl(url);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double size =
            constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;

        final iconSize = (size * 0.38).clamp(22.0, 40.0);

        return InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child:
                    isImage
                        ? Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Container(
                                color: Colors.blueGrey.shade100,
                                child: Icon(
                                  iconForAttachmentUrl(url),
                                  color: Colors.blueGrey.shade700,
                                  size: iconSize,
                                ),
                              ),
                        )
                        : Container(
                          color: Colors.blueGrey.shade100,
                          child: Icon(
                            iconForAttachmentUrl(url),
                            color: Colors.blueGrey.shade700,
                            size: iconSize,
                          ),
                        ),
              ),
            ),
          ),
        );
      },
    );
  }
}
