import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/View/Chats/ChatPage.dart';
import 'package:point/View/Chats/MChatPage.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/responsive.dart';

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

/// Shows the notifications panel as a dialog (used from mobile account dropdown).
void _showNotificationsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'الإشعارات',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                  fontSize: 18,
                ),
              ),
            ),
            Flexible(
              child: GetBuilder<HomeController>(
                builder: (controller) => Obx(
                  () {
                    final filtered = controller.notifications
                        .where((n) =>
                            n.data?['type'] != 'message' &&
                            n.data?['type'] != 'chat')
                        .toList();
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        final randomColor = bgColors[
                            filtered.indexOf(n) % bgColors.length];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: randomColor,
                          child: Text(
                            n.title.toString()[0],
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
                          FunHelper.formatdateTime(n.createdAt!).toString(),
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
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
    ),
  );
}

/// Opens chat screen (used from mobile account dropdown).
void _openChatFromMobile(BuildContext context) {
  Get.to(() => ChatsListScreen(onMinimize: () {}));
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
                role,
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
                      Icon(Icons.notifications_outlined, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('الإشعارات', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (isEmployee)
                  PopupMenuItem(
                    value: 2,
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('الدردشة', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
              ]);
            }
            items.add(
              PopupMenuItem(
                value: 0,
                height: 30,
                child: Container(
                  height: 30,
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.grey.shade200,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      const SizedBox(width: 5),
                      Text(
                        "تسجيل الخروج",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            );
            return items;
          },
          onSelected: (value) {
            if (value == 0) {
              if (isClient) {
                Get.offAllNamed('/auth/LoginUserAccount');
              } else {
                Get.offAllNamed('/auth/login');
              }
              FunHelper.removelogindata();
            } else if (value == 1) {
              _showNotificationsDialog(context);
            } else if (value == 2) {
              _openChatFromMobile(context);
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
  final int notificationCount;
  final bool? employee;
  final bool? client;

  const HeaderWidget({
    super.key,
    required this.name,
    required this.role,
    required this.avatarUrl,
    required this.notificationCount,
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
                role,
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
                        Icon(Icons.notifications_outlined, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('الإشعارات', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  if (employee == true)
                    PopupMenuItem(
                      value: 2,
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('الدردشة', style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                ]);
              }
              items.add(
                PopupMenuItem(
                  value: 0,
                  height: 30,
                  child: Container(
                    height: 30,
                    margin: EdgeInsets.all(2),
                    padding: EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: Colors.grey.shade200,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 5),
                        Text(
                          "تسجيل الخروج",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              return items;
            },
            onSelected: (value) {
              if (value == 0) {
                if (client == true) {
                  Get.offAllNamed('/auth/LoginUserAccount');
                } else {
                  Get.offAllNamed('/auth/login');
                }
                FunHelper.removelogindata();
              } else if (value == 1) {
                _showNotificationsDialog(context);
              } else if (value == 2) {
                _openChatFromMobile(context);
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
                        child: Obx(
                          () {
                            final filtered = controller.notifications
                                .where((n) =>
                                    n.data?['type'] != 'message' &&
                                    n.data?['type'] != 'chat')
                                .toList();
                            return ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: filtered.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 10),
                              itemBuilder: (context, index) {
                                final n = filtered[index];
                                final bgColors = [
                                  Colors.pink.shade100,
                                  Colors.green.shade100,
                                  Colors.purple.shade100,
                                  Colors.teal.shade100,
                                ];
                                final randomColor =
                                    bgColors[filtered.indexOf(n) % bgColors.length];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: randomColor,
                                  child: Text(
                                    n.title.toString()[0],
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
                                  FunHelper.formatdateTime(
                                    n.createdAt!,
                                  ).toString(),
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              );
                            },
                            );
                          },
                        ),
                      ),
                    ),
                    const PopupMenuItem(
                      enabled: false,
                      child: Center(
                        child: Text(
                          "الإشعارات",
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
              child: Container(
                height: 10,
                width: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
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
              child: Obx(() {
                final count = controller.totalUnreadMessages.value;
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
              }),
            ),
          ],
        );
      },
    );
  }
}
