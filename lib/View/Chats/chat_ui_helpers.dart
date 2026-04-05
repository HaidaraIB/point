import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';

String chatInitialFromName(String name) {
  if (name.trim().isEmpty) return '?';
  final parts = name.trim().split(' ');
  return parts.first[0].toUpperCase();
}

bool isChatImageHttpUrl(String? raw) {
  if (raw == null) return false;
  final t = raw.trim();
  return t.startsWith('http://') || t.startsWith('https://');
}

/// شريط تقدم رفيع للشات عند الرفع إلى التخزين (بدون حوار يغطي الشاشة).
class ChatUploadProgressBanner extends StatelessWidget {
  const ChatUploadProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HomeController>();
    return Obx(() {
      if (!c.isUploading.value) return const SizedBox.shrink();
      final p = c.uploadProgress.value.clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'common.uploading'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 4,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xff00A389),
              ),
            ),
          ],
        ),
      );
    });
  }
}

Widget chatLeadingAvatar({
  required double radius,
  required Color backgroundColor,
  required String initial,
  IconData? groupIcon,
  String? imageUrl,
  Color iconColor = Colors.blueGrey,
  Color initialTextColor = Colors.black,
}) {
  if (groupIcon != null) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Icon(groupIcon, color: iconColor),
    );
  }
  if (isChatImageHttpUrl(imageUrl)) {
    final u = imageUrl!.trim();
    final dim = radius * 2;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: Image.network(
          u,
          width: dim,
          height: dim,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) => Text(
                initial,
                style: TextStyle(color: initialTextColor, fontSize: 14),
              ),
        ),
      ),
    );
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    child: Text(
      initial,
      style: TextStyle(color: initialTextColor),
    ),
  );
}
