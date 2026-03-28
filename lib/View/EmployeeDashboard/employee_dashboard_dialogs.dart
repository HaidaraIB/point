import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/View/Shared/in_app_notifications_panel.dart';

Future<bool> confirmEmployeeLogoutDialog(BuildContext context) async {
  final isArabic = Get.locale?.languageCode == 'ar';
  final result = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text('logout'.tr),
          content: Text(
            isArabic
                ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
                : 'Are you sure you want to log out?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('cancel'.tr),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'logout'.tr,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
  );
  return result ?? false;
}

void showEmployeeNotificationsDialog(
  BuildContext context,
  HomeController controller,
) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'header.notifications'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                    fontSize: 18,
                  ),
                ),
              ),
              Flexible(
                child: InAppNotificationsPanel(
                  controller: controller,
                  toggleMinWidth: 88,
                  listPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
