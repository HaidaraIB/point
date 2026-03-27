import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppNotificationInbox.dart';

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
      var filterIndex = 2; // 0=unread, 1=read, 2=all
      return StatefulBuilder(
        builder: (ctx, setState) {
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ToggleButtons(
                      isSelected: [
                        filterIndex == 0,
                        filterIndex == 1,
                        filterIndex == 2,
                      ],
                      onPressed: (i) => setState(() => filterIndex = i),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(10)),
                      constraints: const BoxConstraints(
                        minHeight: 36,
                        minWidth: 88,
                      ),
                      children: [
                        Text(
                          'notifications.filter.unread'.tr,
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'notifications.filter.read'.tr,
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'notifications.filter.all'.tr,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Obx(() {
                      final base = controller.notifications
                          .where((n) => isAppInboxNotification(n))
                          .toList();

                      final filtered = base.where((n) {
                        switch (filterIndex) {
                          case 0:
                            return isInAppNotificationUnread(n);
                          case 1:
                            return n.isRead == true;
                          case 2:
                          default:
                            return true;
                        }
                      }).toList();

                      return ListView.separated(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 10),
                        itemBuilder: (context, index) {
                          final n = filtered[index];
                          final bgColors = [
                            Colors.pink.shade100,
                            Colors.green.shade100,
                            Colors.purple.shade100,
                            Colors.teal.shade100,
                          ];
                          final randomColor =
                              bgColors[index % bgColors.length];

                          final isUnread = isInAppNotificationUnread(n);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: randomColor,
                              child: Text(
                                n.title.toString().isNotEmpty
                                    ? n.title.toString()[0]
                                    : 'N',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title ?? '',
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  n.body ?? '',
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            subtitle: Text(
                              n.createdAt != null
                                  ? FunHelper.formatdateTime(n.createdAt!)
                                      .toString()
                                  : '',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isUnread)
                                  IconButton(
                                    tooltip:
                                        'notifications.action.mark_as_read'.tr,
                                    icon: const Icon(
                                      Icons.mark_email_read_outlined,
                                      color: AppColors.primary,
                                    ),
                                    onPressed: () async {
                                      final id = n.id;
                                      if (id == null || id.isEmpty) return;
                                      await FirestoreServices
                                          .markInAppNotificationsAsRead([id]);
                                    },
                                  ),
                                IconButton(
                                  tooltip: 'notifications.action.delete'.tr,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    final id = n.id;
                                    if (id == null || id.isEmpty) return;

                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(
                                          'notifications.confirm_delete_title'.tr,
                                        ),
                                        content: Text(
                                          'notifications.confirm_delete_message'.tr,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: Text('cancel'.tr),
                                          ),
                                          ElevatedButton(
                                            style:
                                                ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: Text(
                                              'notifications.action.delete'.tr,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (ok == true) {
                                      await FirestoreServices
                                          .deleteInAppNotifications([id]);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
