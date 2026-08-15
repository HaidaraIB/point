import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppNotificationInbox.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Services/notification_navigation/notification_navigation_coordinator.dart';

/// لوحة إشعارات صندوق التطبيق: تعليم الكل كمقروء عند أول فتح، واختيار متعدد للحذف.
class InAppNotificationsPanel extends StatefulWidget {
  const InAppNotificationsPanel({
    super.key,
    required this.controller,
    this.listPadding = const EdgeInsets.all(12),
  });

  final HomeController controller;
  final EdgeInsets listPadding;

  @override
  State<InAppNotificationsPanel> createState() =>
      _InAppNotificationsPanelState();
}

class _InAppNotificationsPanelState extends State<InAppNotificationsPanel> {
  bool selectionMode = false;
  final Set<String> selectedIds = {};
  bool _markedReadOnOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllUnreadInboxReadOnce();
    });
  }

  void _markAllUnreadInboxReadOnce() {
    if (!mounted || _markedReadOnOpen) return;
    _markedReadOnOpen = true;
    final ids = widget.controller.notifications
        .where(isAppInboxNotification)
        .where(isInAppNotificationUnread)
        .map((n) => n.id)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;
    FirestoreServices.markInAppNotificationsAsRead(ids);
  }

  void _toggleSelectionMode() {
    setState(() {
      selectionMode = !selectionMode;
      if (!selectionMode) selectedIds.clear();
    });
  }

  void _selectAllFiltered(List<NotificationModel> filtered) {
    setState(() {
      selectedIds.clear();
      for (final n in filtered) {
        final id = n.id;
        if (id != null && id.isNotEmpty) selectedIds.add(id);
      }
    });
  }

  void _deselectAll() {
    setState(selectedIds.clear);
  }

  Future<void> _confirmDeleteBulk(
    BuildContext context,
    List<String> ids,
  ) async {
    await FunHelper.showConfirmDailog(
      context,
      title: 'notifications.confirm_delete_bulk_title'.tr,
      message: 'notifications.confirm_delete_bulk_message'.trParams({
        'count': '${ids.length}',
      }),
      confirmText: 'notifications.action.delete'.tr,
      confirmColor: Colors.red,
      onTap: () async {
        await FirestoreServices.deleteInAppNotifications(ids);
        if (!mounted) return;
        setState(() {
          selectedIds.clear();
          selectionMode = false;
        });
      },
    );
  }

  Future<void> _confirmDeleteSingle(BuildContext context, String id) async {
    await FunHelper.showConfirmDailog(
      context,
      title: 'notifications.confirm_delete_title'.tr,
      message: 'notifications.confirm_delete_message'.tr,
      confirmText: 'notifications.action.delete'.tr,
      confirmColor: Colors.red,
      onTap: () async {
        await FirestoreServices.deleteInAppNotifications([id]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Wrap(
            spacing: 0,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: selectionMode
                    ? 'notifications.action.exit_selection'.tr
                    : 'notifications.action.selection_mode'.tr,
                icon: Icon(
                  selectionMode ? Icons.close : Icons.checklist_outlined,
                  color: context.appTheme.primaryText,
                ),
                onPressed: _toggleSelectionMode,
              ),
              if (selectionMode) ...[
                TextButton(
                  onPressed: () {
                    final inbox = widget.controller.notifications
                        .where((n) => isAppInboxNotification(n))
                        .toList();
                    _selectAllFiltered(inbox);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.appTheme.accentText,
                  ),
                  child: Text('notifications.action.select_all'.tr),
                ),
                TextButton(
                  onPressed: _deselectAll,
                  style: TextButton.styleFrom(
                    foregroundColor: context.appTheme.secondaryText,
                  ),
                  child: Text('notifications.action.deselect_all'.tr),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: FilledButton.icon(
                    onPressed: selectedIds.isEmpty
                        ? null
                        : () =>
                              _confirmDeleteBulk(context, selectedIds.toList()),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: Text('notifications.action.delete_selected'.tr),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            widget.controller.notifications.length;
            final inbox = widget.controller.notifications
                .where((n) => isAppInboxNotification(n))
                .toList();

            if (inbox.isEmpty) {
              return Center(
                child: Text(
                  'notifications.empty'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.appTheme.mutedText,
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: widget.listPadding,
              itemCount: inbox.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 10, color: context.appTheme.border),
              itemBuilder: (context, index) {
                final n = inbox[index];
                final accentColors = [
                  AppColors.primary,
                  Colors.green,
                  Colors.purple,
                  Colors.teal,
                ];
                final accent = accentColors[index % accentColors.length];
                final isUnread = isInAppNotificationUnread(n);
                final id = n.id;
                final hasId = id != null && id.isNotEmpty;
                final selected = hasId && selectedIds.contains(id);

                Widget leading;
                if (selectionMode && hasId) {
                  leading = Checkbox(
                    value: selected,
                    onChanged: (_) {
                      setState(() {
                        if (selected) {
                          selectedIds.remove(id);
                        } else {
                          selectedIds.add(id);
                        }
                      });
                    },
                  );
                } else {
                  leading = CircleAvatar(
                    radius: 24,
                    backgroundColor: accent.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: accent,
                    ),
                  );
                }

                return ListTile(
                  titleAlignment: ListTileTitleAlignment.top,
                  contentPadding: EdgeInsets.zero,
                  leading: leading,
                  onTap: selectionMode && hasId
                      ? () {
                          setState(() {
                            if (selected) {
                              selectedIds.remove(id);
                            } else {
                              selectedIds.add(id);
                            }
                          });
                        }
                      : (n.data == null || n.data!.isEmpty)
                      ? null
                      : () {
                          Navigator.of(context).maybePop();
                          NotificationNavigationCoordinator.handlePayload(
                            n.data,
                          );
                        },
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        n.title ?? '',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.appTheme.accentText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.body ?? '',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appTheme.primaryText,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    n.createdAt != null
                        ? FunHelper.formatTimeAgo(n.createdAt!).toString()
                        : '',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTheme.mutedText,
                    ),
                  ),
                  trailing: selectionMode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUnread)
                              IconButton(
                                tooltip: 'notifications.action.mark_as_read'.tr,
                                icon: Icon(
                                  Icons.mark_email_read_outlined,
                                  color: context.appTheme.accentText,
                                ),
                                onPressed: !hasId
                                    ? null
                                    : () async {
                                        await FirestoreServices.markInAppNotificationsAsRead(
                                          [id],
                                        );
                                      },
                              ),
                            IconButton(
                              tooltip: 'notifications.action.delete'.tr,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: !hasId
                                  ? null
                                  : () => _confirmDeleteSingle(context, id),
                            ),
                          ],
                        ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
