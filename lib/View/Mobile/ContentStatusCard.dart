import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/ContentPermissions.dart';
import 'package:point/View/Shared/ContentStatusPromotionDropdownChip.dart';
import 'package:point/View/Shared/attachment_thumbnail_tile.dart';
import 'package:point/View/Shared/task_status_visuals.dart';
import 'package:point/Utils/app_theme_extension.dart';

export 'package:point/Utils/media_url_opener.dart' show getFileType;

class ContentStatusCard extends StatelessWidget {
  final ContentModel? model;
  final VoidCallback? onTap;
  final int index;

  const ContentStatusCard({
    super.key,
    required this.index,
    required this.model,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final emp = Get.find<HomeController>().currentEmployee.value;
    final showPubDate = ContentPermissions.showContentPublishDateUi(emp);
    final showStatus = ContentPermissions.showContentStatusUi(emp);
    final showPromo = ContentPermissions.showContentPromotionUi(emp);
    final firstFile = model?.primaryAttachmentUrl;
    return InkWell(
      onTap: onTap,
      // borderRadius: BorderRadius.circular(0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: index.isOdd ? appTheme.elevatedSurface : appTheme.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: appTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(firstFile),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          model?.title.tr ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: appTheme.primaryText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 4),
                            Text(
                              '|',
                              style: TextStyle(color: appTheme.mutedText),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                FunHelper.trStored(
                                  model!.contentType,
                                  kind: StoredValueKind.contentType,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: appTheme.secondaryText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 3),
                          ],
                        ),
                        if (showPubDate) ...[
                          const SizedBox(height: 2),
                          Text(
                            FunHelper.formatdate(model?.publishDate) ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: appTheme.primaryText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showStatus) ...[
                        _buildstatusTag(context, model!.status),
                        const SizedBox(width: 6),
                      ],
                      if (!showStatus && showPromo) ...[
                        _buildPromotionTag(context, model!.promotion),
                        const SizedBox(width: 6),
                      ],
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: appTheme.mutedText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
Color _buildplatformColor(String platform) {
  switch (platform) {
    case 'platform_facebook':
      return Colors.blue;
    case 'platform_instagram':
      return Colors.purple;
    case 'twitter':
      return Colors.lightBlue;
    case 'platform_snapchat':
      return Colors.yellow;
    default:
      return Colors.grey;
  }
}

// ignore: unused_element
Widget _buildcontenttypeIcon(BuildContext context, String type) {
  final appTheme = context.appTheme;
  switch (type) {
    case 'content_video':
      return Icon(CupertinoIcons.play_arrow, size: 24, color: appTheme.secondaryText);
    case 'content_image':
      return Icon(Icons.image_outlined, size: 24, color: appTheme.secondaryText);
    case 'content_text':
      return Icon(
        Icons.format_align_center_outlined,
        size: 24,
        color: appTheme.secondaryText,
      );
    default:
      return Icon(Icons.device_unknown, size: 24, color: appTheme.secondaryText);
  }
}

// getFileType lives in media_url_opener.dart (path-based; query-safe).

Widget _buildIcon(String? url) {
  if (url == null || url.isEmpty) {
    return Image.asset(
      'assets/images/content_type_placeholder.png',
      width: 65,
      height: 65,
      fit: BoxFit.cover,
    );
  }
  // Shared tile: path-based type detection, Image.network errorBuilder, and
  // first-frame video thumbs (reels) — same path desktop contents table uses.
  return SizedBox(
    width: 65,
    height: 65,
    child: AttachmentThumbnailTile(url: url, borderRadius: 8),
  );
}

Widget _buildPromotionTag(BuildContext context, String? promotion) {
  final key = FunHelper.canonicalStoredPromotion(promotion);
  final label =
      promotion == null || promotion.trim().isEmpty
          ? '--'
          : FunHelper.trStored(
            promotion,
            kind: StoredValueKind.promotion,
          );
  final accent = getContentPromotionColor(key);
  final fg = context.statusChipForeground(accent);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: context.statusChipBackground(
        accent,
        getContentPromotionBgColor(key),
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: fg,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _buildstatusTag(BuildContext context, String text) {
  final key = FunHelper.canonicalStoredStatus(text);
  final accent = _getStatusColor(key);
  final fg = context.statusChipForeground(accent);
  final bg = context.statusChipBackground(accent, _getStatusbgColor(key));
  return TaskStatusVisuals.statusChip(
    rawStatus: text,
    fg: fg,
    bg: bg,
  );
}

Color _getStatusColor(String status) {
  switch (status) {
    case StorageKeys.status_under_revision: // تحت المراجعة
      return Colors.blue;

    case StorageKeys.status_ready_to_publish: // جاهز للنشر
      return Colors.teal;

    case StorageKeys.status_approved: // تم الموافقة
      return Colors.green;

    case StorageKeys.status_scheduled: // مجدوَل
      return Colors.orange;

    case StorageKeys.status_processing: // جاري التنفيذ
      return Colors.amber;

    case StorageKeys.status_published: // منشور
      return Colors.lightGreen;

    case StorageKeys.status_task_completed:
      return Colors.lightGreen;

    case StorageKeys.status_rejected: // مرفوض
      return Colors.red;

    case StorageKeys.status_in_edit: // جاري التعديل
      return Colors.purple;

    case StorageKeys.status_edit_requested: // طلب تعديل
      return Colors.deepOrange;

    case StorageKeys.status_not_start_yet: // لم يبدأ بعد
      return Colors.grey;

    default:
      return Colors.black45; // حالة غير معروفة
  }
}

Color _getStatusbgColor(String status) {
  switch (status) {
    case StorageKeys.status_under_revision:
      return Colors.blue.shade50;
    case StorageKeys.status_approved:
      return Colors.green.shade50;
    case StorageKeys.status_rejected:
      return Colors.red.shade50;
    default:
      return Colors.grey.shade200;
  }
}
