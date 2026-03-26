import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/Utils/AppNotificationInbox.dart';
import 'package:point/View/Chats/ChatPage.dart';
import 'package:point/View/Chats/MChatPage.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/responsive.dart';

/// Firestore role slug (e.g. employee, admin) shown in headers.
String _localizedStoredRole(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return raw;
  return s.tr;
}

Widget _buildAvatar(String url, {required double radius}) {
  if (url.isEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      child: Icon(Icons.person, color: Colors.grey.shade600, size: radius),
    );
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: Colors.grey.shade300,
    child: ClipOval(
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.grey.shade600, size: radius),
      ),
    ),
  );
}

/// Red numeric badge (e.g. chat / notifications); hidden when [count] <= 0.
class HeaderCountBadge extends StatelessWidget {
  final int count;

  const HeaderCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Shows the notifications panel as a dialog (used from mobile account dropdown).
void _showNotificationsDialog(BuildContext context) {
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
              constraints: const BoxConstraints(
                maxWidth: 400,
                maxHeight: 500,
              ),
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
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
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
                    child: GetBuilder<HomeController>(
                      builder: (controller) => Obx(
                        () {
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
                            separatorBuilder: (_, __) =>
                                const Divider(height: 10),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                              .markInAppNotificationsAsRead(
                                            [id],
                                          );
                                        },
                                      ),
                                    IconButton(
                                      tooltip:
                                          'notifications.action.delete'.tr,
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
                                              'notifications.confirm_delete_title'
                                                  .tr,
                                            ),
                                            content: Text(
                                              'notifications.confirm_delete_message'
                                                  .tr,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(false),
                                                child: Text('cancel'.tr),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
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
                        },
                      ),
                    ),
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

/// نفس [_showNotificationsDialog]؛ يُستدعى من شريط الموبايل في [ResponsiveScaffold] (admin/supervisor).
void showInAppNotificationsDialog(BuildContext context) {
  _showNotificationsDialog(context);
}

/// Opens chat screen (used from mobile account dropdown).
void _openChatFromMobile(BuildContext context) {
  Get.to(() => ChatsListScreen(onMinimize: () {}));
}

Future<bool> _confirmLogoutDialog(BuildContext context) async {
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

/// Compact profile widget for the mobile app bar (avatar + name/role + dropdown).
/// Placed on the side opposite to the drawer.
class MobileAppBarProfileWidget extends StatelessWidget {
  final String name;
  final String role;
  final String avatarUrl;
  final bool isEmployee;
  final bool isClient;

  const MobileAppBarProfileWidget({
    super.key,
    required this.name,
    required this.role,
    required this.avatarUrl,
    this.isEmployee = true,
    this.isClient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAvatar(avatarUrl, radius: 18),
        const SizedBox(width: 8),
        Flexible(
          fit: FlexFit.loose,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _localizedStoredRole(role),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        PopupMenuButton<int>(
          tooltip: 'tasks.options_tooltip'.tr,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          elevation: 4,
          itemBuilder: (context) {
            final items = <PopupMenuItem<int>>[];
            if (!isClient) {
              items.addAll([
                PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'header.notifications'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Obx(
                        () {
                          final n = unreadInAppInboxCount(
                            Get.find<HomeController>().notifications,
                          );
                          if (n <= 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: HeaderCountBadge(count: n),
                          );
                        },
                      ),
                      Icon(Icons.notifications_outlined, color: AppColors.primary),
                    ],
                  ),
                ),
                if (isEmployee)
                  PopupMenuItem(
                    value: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'header.chat'.tr,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Obx(
                          () {
                            final n =
                                Get.find<HomeController>().totalUnreadMessages.value;
                            if (n <= 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: HeaderCountBadge(count: n),
                            );
                          },
                        ),
                        Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                      ],
                    ),
                  ),
              ]);
            }
            items.add(
              PopupMenuItem(
                value: 3,
                child: Row(
                  children: [
                    Text(
                      'resetpassword'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.lock_reset, color: AppColors.primary),
                  ],
                ),
              ),
            );
            items.add(
              PopupMenuItem(
                value: 0,
                height: 30,
                child: Container(
                  height: 30,
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Text(
                        'logout'.tr,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.logout, color: Colors.red),
                    ],
                  ),
                ),
              ),
            );
            return items;
          },
          onSelected: (value) async {
            if (value == 0) {
              final shouldLogout = await _confirmLogoutDialog(context);
              if (!shouldLogout) return;
              Get.find<HomeController>().clearEmployeeSession();
              await FirestoreServices().signOut();
              if (isClient) {
                Get.offAllNamed('/auth/LoginUserAccount');
              } else {
                Get.offAllNamed('/auth/login');
              }
              FunHelper.removeLoginData();
            } else if (value == 1) {
              _showNotificationsDialog(context);
            } else if (value == 2) {
              _openChatFromMobile(context);
            } else if (value == 3) {
              Get.toNamed('/auth/resetPassword');
            }
          },
        ),
      ],
    );
  }
}

class HeaderWidget extends StatelessWidget {
  final String name;
  final String role;
  final String avatarUrl;
  final bool? employee;
  final bool? client;

  const HeaderWidget({
    super.key,
    required this.name,
    required this.role,
    required this.avatarUrl,
    this.employee,
    this.client,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    if (isMobile) return const SizedBox.shrink();

    final screenWidth = MediaQuery.sizeOf(context).width;

    final Widget logoOrSearch = (employee == true || client == true)
        ? Padding(
            padding: EdgeInsets.only(left: isMobile ? 8 : 0, right: isMobile ? 8 : 0),
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              child: Image.asset(
                AppImages.images.logocolored,
                height: isMobile ? 40 : 50,
                fit: BoxFit.contain,
              ),
            ),
          )
        : Container(
            margin: const EdgeInsets.only(top: 5),
            width: isMobile ? 120 : 200,
            child: InputText(
              hintText: 'search'.tr,
              borderRadius: 25,
              fillColor: Colors.white,
              prefixIcon: Icon(
                CupertinoIcons.search,
                color: Colors.grey,
                size: 16,
              ),
            ),
          );

    // On mobile: simplified row (avatar + name/role + dropdown with Notifications, Chat, Logout).
    // On desktop/tablet: full row with NotificationDropdown, _chats, avatar, name/role, dropdown.
    final Widget userGroup = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isMobile && client != true) NotificationDropdown(),
        if (!isMobile && employee == true && client != true) _chats(),
        _buildAvatar(avatarUrl, radius: isMobile ? 18 : 20),
        SizedBox(width: isMobile ? 6 : 15),
        Flexible(
          fit: FlexFit.loose,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 13 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _localizedStoredRole(role),
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: isMobile ? 11 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        SizedBox(
          child: PopupMenuButton<int>(
            tooltip: 'tasks.options_tooltip'.tr,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
            elevation: 4,
            itemBuilder: (context) {
              final items = <PopupMenuItem<int>>[];
              if (isMobile && client != true) {
                items.addAll([
                  PopupMenuItem(
                    value: 1,
                    child: Row(
                      children: [
                        Text(
                        'header.notifications'.tr,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                        SizedBox(width: 8),
                        Icon(Icons.notifications_outlined, color: AppColors.primary),
                      ],
                    ),
                  ),
                  if (employee == true)
                    PopupMenuItem(
                      value: 2,
                      child: Row(
                        children: [
                          Text(
                          'header.chat'.tr,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                          SizedBox(width: 8),
                          Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                        ],
                      ),
                    ),
                ]);
              }
              items.add(
                PopupMenuItem(
                  value: 3,
                  child: Row(
                    children: [
                      Text(
                        'resetpassword'.tr,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.lock_reset, color: AppColors.primary),
                    ],
                  ),
                ),
              );
              items.add(
                PopupMenuItem(
                  value: 0,
                  height: 30,
                  child: Container(
                    height: 30,
                    margin: EdgeInsets.all(2),
                    padding: EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Text(
                          'logout'.tr,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 5),
                        Icon(Icons.logout, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              );
              return items;
            },
            onSelected: (value) async {
              if (value == 0) {
                final shouldLogout = await _confirmLogoutDialog(context);
                if (!shouldLogout) return;
                Get.find<HomeController>().clearEmployeeSession();
                await FirestoreServices().signOut();
                if (client == true) {
                  Get.offAllNamed('/auth/LoginUserAccount');
                } else {
                  Get.offAllNamed('/auth/login');
                }
                FunHelper.removeLoginData();
              } else if (value == 1) {
                _showNotificationsDialog(context);
              } else if (value == 2) {
                _openChatFromMobile(context);
              } else if (value == 3) {
                Get.toNamed('/auth/resetPassword');
              }
            },
            child: Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ),
      ],
    );

    final rowChild = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isMobile)
          SizedBox(
            width: 56,
            child: logoOrSearch,
          )
        else
          logoOrSearch,
        SizedBox(width: isMobile ? 6 : 20),
        if (isMobile)
          Expanded(child: userGroup)
        else ...[
          const Spacer(),
          userGroup,
        ],
      ],
    );

    final boundedWidth = screenWidth.isFinite ? screenWidth : 400.0;

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Container(
          width: boundedWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: rowChild,
        ),
      );
    }

    return Container(
      color: Colors.white,
      width: boundedWidth,
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: rowChild,
    );
  }
}

class NotificationDropdown extends StatelessWidget {
  NotificationDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                int filterIndex = 2; // 0=unread, 1=read, 2=all
                final RenderBox button =
                    context.findRenderObject() as RenderBox;
                final RenderBox overlay =
                    Overlay.of(context).context.findRenderObject() as RenderBox;

                final position = RelativeRect.fromRect(
                  Rect.fromPoints(
                    button.localToGlobal(Offset.zero, ancestor: overlay),
                    button.localToGlobal(
                      button.size.bottomRight(Offset.zero),
                      ancestor: overlay,
                    ),
                  ),
                  Offset.zero & overlay.size,
                );

                showMenu(
                  context: context,
                  position: position,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  items: [
                    PopupMenuItem(
                      enabled: false,
                      padding: EdgeInsets.zero,

                      child: Container(
                        width: 700,
                        constraints: const BoxConstraints(maxHeight: 800),
                        child: StatefulBuilder(
                          builder: (context, setState) {
                            return Column(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 12, 12, 6),
                                  child: ToggleButtons(
                                    isSelected: [
                                      filterIndex == 0,
                                      filterIndex == 1,
                                      filterIndex == 2,
                                    ],
                                    onPressed: (i) =>
                                        setState(() => filterIndex = i),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                    constraints: const BoxConstraints(
                                      minHeight: 36,
                                      minWidth: 100,
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
                                Expanded(
                                  child: Obx(
                                    () {
                                      final base = controller.notifications
                                          .where((n) =>
                                              isAppInboxNotification(n))
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
                                        padding: const EdgeInsets.all(12),
                                        itemCount: filtered.length,
                                        separatorBuilder:
                                            (_, __) =>
                                                const Divider(height: 10),
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

                                          final isUnread =
                                              isInAppNotificationUnread(n);
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  n.body ?? '',
                                                  textDirection: TextDirection.rtl,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                            subtitle: Text(
                                              n.createdAt != null
                                                  ? FunHelper
                                                      .formatdateTime(
                                                        n.createdAt!,
                                                      )
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
                                                    tooltip: 'notifications.action.mark_as_read'.tr,
                                                    icon: const Icon(
                                                      Icons
                                                          .mark_email_read_outlined,
                                                      color: AppColors.primary,
                                                    ),
                                                    onPressed: () async {
                                                      final id = n.id;
                                                      if (id == null ||
                                                          id.isEmpty) return;
                                                      await FirestoreServices
                                                          .markInAppNotificationsAsRead(
                                                        [id],
                                                      );
                                                    },
                                                  ),
                                                IconButton(
                                                  tooltip:
                                                      'notifications.action.delete'.tr,
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.redAccent,
                                                  ),
                                                  onPressed: () async {
                                                    final id = n.id;
                                                    if (id == null ||
                                                        id.isEmpty) return;

                                                    final ok = await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                        title: Text(
                                                          'notifications.confirm_delete_title'.tr,
                                                        ),
                                                        content: Text(
                                                          'notifications.confirm_delete_message'.tr,
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(ctx)
                                                                    .pop(false),
                                                            child: Text('cancel'.tr),
                                                          ),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                            ),
                                                            onPressed: () =>
                                                                Navigator.of(ctx)
                                                                    .pop(true),
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
                                                          .deleteInAppNotifications(
                                                        [id],
                                                      );
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      enabled: false,
                      child: Center(
                        child: Text(
                          'header.notifications'.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            Positioned(
              right: 6,
              top: 6,
              child: Obx(
                () => HeaderCountBadge(
                      count: unreadInAppInboxCount(controller.notifications),
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ignore: must_be_immutable
class _chats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.chat_bubble_outline),
              onPressed: () {
                Responsive.isMobile(context)
                    ? Get.to(() => ChatsListScreen(onMinimize: () {}))
                    :
                    // _toggleFloatingChat(context);
                    showDialog(
                      context: context,
                      builder:
                          (context) => Dialog(
                            insetPadding: const EdgeInsets.all(20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            backgroundColor: Colors.transparent,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.7,
                              height: MediaQuery.of(context).size.height * 0.9,
                              child: ChatScreen(
                                onMinimize: () {
                                  Get.back();
                                },
                              ),
                            ),
                          ),
                    );
              },
            ),

            Positioned(
              right: 6,
              top: 6,
              child: Obx(
                () => HeaderCountBadge(
                  count: controller.totalUnreadMessages.value,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
