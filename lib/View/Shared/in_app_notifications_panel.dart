import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppNotificationInbox.dart';

/// لوحة إشعارات صندوق التطبيق: فلاتر، تعليم الكل كمقروء عند أول فتح، واختيار متعدد للحذف.
class InAppNotificationsPanel extends StatefulWidget {
  const InAppNotificationsPanel({
    super.key,
    required this.controller,
    this.toggleMinWidth = 88,
    this.listPadding = const EdgeInsets.all(12),
  });

  final HomeController controller;
  final double toggleMinWidth;
  final EdgeInsets listPadding;

  @override
  State<InAppNotificationsPanel> createState() =>
      _InAppNotificationsPanelState();
}

class _InAppNotificationsPanelState extends State<InAppNotificationsPanel> {
  int filterIndex = 2;
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

  List<NotificationModel> _filteredListFrom(List<NotificationModel> inbox) {
    return inbox.where((n) {
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
  }

  void _toggleSelectionMode() {
    setState(() {
      selectionMode = !selectionMode;
      if (!selectionMode) selectedIds.clear();
    });
  }

  void _onFilterChanged(int i) {
    setState(() {
      filterIndex = i;
      if (selectionMode) {
        final allowed = _filteredListFrom(
          widget.controller.notifications
              .where((n) => isAppInboxNotification(n))
              .toList(),
        ).map((n) => n.id).whereType<String>().where((id) => id.isNotEmpty).toSet();
        selectedIds.removeWhere((id) => !allowed.contains(id));
      }
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('notifications.confirm_delete_bulk_title'.tr),
        content: Text(
          'notifications.confirm_delete_bulk_message'
              .trParams({'count': '${ids.length}'}),
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
              'notifications.action.delete'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await FirestoreServices.deleteInAppNotifications(ids);
      if (mounted) {
        setState(() {
          selectedIds.clear();
          selectionMode = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteSingle(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('notifications.confirm_delete_title'.tr),
        content: Text('notifications.confirm_delete_message'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'notifications.action.delete'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirestoreServices.deleteInAppNotifications([id]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  var maxW = constraints.maxWidth;
                  if (!maxW.isFinite) {
                    maxW = MediaQuery.sizeOf(context).width;
                  }
                  // ToggleButtons يضيف حدوداً وبادينغ بين الأقسام؛ تقسيم العرض/3 لا يكفي.
                  // FittedBox يضمن عدم تجاوز العرض على الويب والشاشات الضيقة.
                  return SizedBox(
                    width: maxW,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: ToggleButtons(
                        isSelected: [
                          filterIndex == 0,
                          filterIndex == 1,
                          filterIndex == 2,
                        ],
                        onPressed: _onFilterChanged,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                        constraints: BoxConstraints(
                          minHeight: 36,
                          minWidth: widget.toggleMinWidth,
                        ),
                        children: [
                          Text(
                            'notifications.filter.unread'.tr,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'notifications.filter.read'.tr,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'notifications.filter.all'.tr,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Wrap(
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
                    ),
                    onPressed: _toggleSelectionMode,
                  ),
                  if (selectionMode) ...[
                    TextButton(
                      onPressed: () {
                        final inbox = widget.controller.notifications
                            .where((n) => isAppInboxNotification(n))
                            .toList();
                        _selectAllFiltered(_filteredListFrom(inbox));
                      },
                      child: Text('notifications.action.select_all'.tr),
                    ),
                    TextButton(
                      onPressed: _deselectAll,
                      child: Text('notifications.action.deselect_all'.tr),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: FilledButton.icon(
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () => _confirmDeleteBulk(
                                  context,
                                  selectedIds.toList(),
                                ),
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
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            widget.controller.notifications.length;
            final inbox = widget.controller.notifications
                .where((n) => isAppInboxNotification(n))
                .toList();
            final filtered = _filteredListFrom(inbox);

            return ListView.separated(
              padding: widget.listPadding,
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
                final randomColor = bgColors[index % bgColors.length];
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
                  );
                }

                return ListTile(
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
                      : null,
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
                        ? FunHelper.formatdateTime(n.createdAt!).toString()
                        : '',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
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
                                icon: const Icon(
                                  Icons.mark_email_read_outlined,
                                  color: AppColors.primary,
                                ),
                                onPressed: !hasId
                                    ? null
                                    : () async {
                                        await FirestoreServices
                                            .markInAppNotificationsAsRead(
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
