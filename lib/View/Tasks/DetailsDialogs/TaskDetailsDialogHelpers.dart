import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';

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
        tr ? text.tr : text,
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
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  softWrap: true,
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
            label: const Text('تنزيل'),
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

  /// Thumbnail tile used in task details dialogs.
  /// Tapping the thumbnail triggers [onOpen] (same behavior as "تنزيل").
  static Widget attachmentThumbnail(
    String url, {
    required VoidCallback onOpen,
  }) {
    final lower = url.toString().toLowerCase();
    final isImage =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');

    return LayoutBuilder(
      builder: (context, constraints) {
        final double size =
            constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;

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
                                child: const Icon(
                                  Icons.link,
                                  color: Colors.blueGrey,
                                  size: 24,
                                ),
                              ),
                        )
                        : Container(
                          color: Colors.blueGrey.shade100,
                          child: const Icon(
                            Icons.link,
                            color: Colors.blueGrey,
                            size: 24,
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
