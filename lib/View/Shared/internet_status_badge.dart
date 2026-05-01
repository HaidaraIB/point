import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/InternetStatusController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';

class InternetStatusBadge extends StatelessWidget {
  const InternetStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    final controller = Get.find<InternetStatusController>();
    return Obx(() {
      final online = controller.isOnline.value;
      final color = online ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
      final label = online
          ? AppLocaleKeys.internetOnlineBadge.tr
          : AppLocaleKeys.internetOfflineBadge.tr;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 9, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    });
  }
}
