import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';

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
    return InkWell(
      onTap: onTap,
      // borderRadius: BorderRadius.circular(0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: index.isOdd ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(model!.files?.first),
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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
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
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                FunHelper.trStored(
                                  model!.contentType,
                                  kind: StoredValueKind.contentType,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 3),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FunHelper.formatdate(model?.publishDate) ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildstatusTag(model!.status),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
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
Widget _buildcontenttypeIcon(String type) {
  switch (type) {
    case 'content_video':
      return Icon(CupertinoIcons.play_arrow, size: 24, color: Colors.grey);
    case 'content_image':
      return Icon(Icons.image_outlined, size: 24, color: Colors.grey);
    case 'content_text':
      return Icon(
        Icons.format_align_center_outlined,
        size: 24,
        color: Colors.grey,
      );
    default:
      return const Icon(Icons.device_unknown, size: 24, color: Colors.grey);
  }
}

String getFileType(String url) {
  final lowerUrl = url.toLowerCase();
  if (lowerUrl.endsWith('.jpg') ||
      lowerUrl.endsWith('.jpeg') ||
      lowerUrl.endsWith('.png') ||
      lowerUrl.endsWith('.gif') ||
      lowerUrl.endsWith('.webp')) {
    return 'image';
  } else if (lowerUrl.endsWith('.mp4') ||
      lowerUrl.endsWith('.mov') ||
      lowerUrl.endsWith('.avi') ||
      lowerUrl.endsWith('.mkv')) {
    return 'video';
  } else if (lowerUrl.endsWith('.pdf')) {
    return 'pdf';
  } else {
    return 'unknown';
  }
}

Widget _buildIcon(String url) {
  var type = getFileType(url);
  switch (type) {
    case 'image':
      return Image.network(url, width: 65, height: 65, fit: BoxFit.cover);
    case 'content_image':
      return Image.asset(
        'assets/images/Arrow(1).png',
        width: 65,
        height: 65,
        fit: BoxFit.cover,
      );
    case 'content_text':
      return Image.asset(
        'assets/images/Arrow(2).png',
        width: 65,
        height: 65,
        fit: BoxFit.cover,
      );
    default:
      return Image.asset(
        'assets/images/Arrow(2).png',
        width: 65,
        height: 65,
        fit: BoxFit.cover,
      );
  }
}

Widget _buildstatusTag(String text) {
  final key = FunHelper.canonicalStoredStatus(text);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _getStatusbgColor(key),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      FunHelper.trStored(text, kind: StoredValueKind.taskStatus),
      style: TextStyle(
        color: _getStatusColor(key),
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
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
