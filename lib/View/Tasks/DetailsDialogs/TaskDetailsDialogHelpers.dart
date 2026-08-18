import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Shared/attachment_thumbnail_tile.dart'
    as attachment_thumb;
import 'package:point/Utils/app_theme_extension.dart';

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

  static String displayOrDash(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? '-' : v;
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

  static Color getPriorityBgColor(BuildContext context, String priority) {
    final fg = getPriorityColor(priority);
    if (Theme.of(context).brightness == Brightness.dark) {
      return fg.withValues(alpha: 0.18);
    }
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
  static Widget buildTag(BuildContext context, String text, {bool tr = false}) {
    final canonical = text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getPriorityBgColor(context, canonical),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tr ? FunHelper.translateAppKey(text) : text,
        style: TextStyle(
          color: getPriorityColor(canonical),
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
    final theme = resolveAppTheme();
    final displayValue = displayOrDash(value);
    final isPlaceholder = displayValue == '-';

    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: height ?? 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: theme.secondaryText),
          ),
          const SizedBox(height: 10),
          child ??
              Tooltip(
                message: isPlaceholder ? '' : displayValue,
                child: LinkifiedText(
                  displayValue,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isPlaceholder ? FontWeight.w600 : FontWeight.bold,
                    fontSize: 12,
                    color: isPlaceholder ? theme.mutedText : theme.primaryText,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  /// Date info box with icon (for web details dialog).
  static Widget infoBoxDates(String title, String? value, IconData icon) {
    final theme = resolveAppTheme();
    final displayValue = displayOrDash(value);

    return Container(
      width: 200,
      constraints: const BoxConstraints(minHeight: 104),
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, color: theme.secondaryText, size: 18),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    color: theme.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            displayValue,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: displayValue == '-' ? FontWeight.w600 : FontWeight.bold,
              fontSize: 12,
              color: displayValue == '-' ? theme.mutedText : theme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  /// Keeps start/end date cards the same height when labels wrap.
  static Widget dateBoxesRow(List<Widget> boxes) {
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: boxes,
      ),
    );
  }

  /// Attachment card with download button.
  static Widget attachmentCard(
    String title,
    String size, {
    required VoidCallback onDownload,
  }) {
    final theme = resolveAppTheme();

    return Container(
      width: 200,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.cardSurface,
        border: Border.all(color: theme.border),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: resolveAppTheme().primaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(size, style: TextStyle(color: theme.secondaryText)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download, size: 18),
            label: Text('tasks.download'.tr),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: theme.panelTint,
              foregroundColor: theme.accentText,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ],
      ),
    );
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
  static IconData iconForAttachmentUrl(String rawUrl) =>
      attachment_thumb.iconForAttachmentUrl(rawUrl);

  /// Thumbnail tile used in task details dialogs.
  /// Tapping the thumbnail triggers [onOpen] (same behavior as "تنزيل").
  static Widget attachmentThumbnail(
    String url, {
    required VoidCallback onOpen,
  }) {
    return attachment_thumb.AttachmentThumbnailTile(url: url, onTap: onOpen);
  }
}
