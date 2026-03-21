import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Tasks/Dialogs/ContentWriteDialog.dart';
import 'package:point/View/Tasks/Dialogs/DesignDialog.dart';
import 'package:point/View/Tasks/Dialogs/MontageDialog.dart';
import 'package:point/View/Tasks/Dialogs/PhotoGraphyDialog.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';
import 'package:point/View/Tasks/Dialogs/PromotionDialog.dart';
import 'package:point/View/Tasks/Dialogs/PublishDialog.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;

  TaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- العنوان + النقاط الثلاثة ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        child: PopupMenuButton<int>(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: Colors.white,
                          elevation: 4,
                          itemBuilder:
                              (context) => [
                                PopupMenuItem(
                                  value: 0,

                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('tasks.view'.tr),
                                      Icon(
                                        Icons.remove_red_eye_outlined,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 1,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('tasks.request_edit'.tr),
                                      Icon(
                                        Icons.edit_outlined,
                                        color: Colors.blueAccent,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 2,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('delete'.tr),
                                      Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 3,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('tasks.reject'.tr),
                                      Icon(
                                        Icons.close_rounded,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 4,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('tasks.accept'.tr),
                                      Icon(
                                        Icons.check,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                          onSelected: (value) {
                            if (value == 0) {
                              onTap();
                            } else if (value == 1) {
                              // controller.uploadedFilesPaths.clear();

                              switch (task.type) {
                                case '0':
                                  showPromotionDialog(context, model: task);
                                  break;
                                case '1':
                                  designDialog(context, model: task);
                                  break;
                                case '2':
                                  photoGraphyDialog(context, model: task);
                                  break;
                                case '3':
                                  contentWriteDiloag(context, model: task);
                                  break;
                                case '4':
                                  montageDiloag(context, model: task);
                                  break;
                                case '5':
                                  publishDilaog(context, model: task);
                                  break;
                                case '6':
                                  programmingDiloag(context, model: task);
                                  break;
                                default:
                              }
                            } else if (value == 2) {
                              FunHelper.showConfirmDailog(
                                context,
                                title: 'tasks.confirm_delete_title'.tr,
                                message: 'tasks.confirm_delete_message'.tr,
                                confirmText: 'delete'.tr,
                                confirmColor: Colors.red,
                                onTap: () async {
                                  await Get.find<HomeController>().deleteTask(
                                    task.id!,
                                  );
                                },
                              );
                            } else if (value == 3) {
                              FunHelper.showConfirmDailog(
                                context,
                                title: 'tasks.confirm_reject_title'.tr,
                                message: 'tasks.confirm_reject_message'.tr,
                                confirmText: 'tasks.reject'.tr,
                                confirmColor: Colors.red,
                                onTap: () async {
                                  await Get.find<HomeController>().updateTask(
                                    task.copyWith(
                                      status: StorageKeys.status_rejected,
                                    ),
                                  );
                                },
                              );
                            } else if (value == 4) {
                              FunHelper.showConfirmDailog(
                                context,
                                title: 'tasks.confirm_accept_title'.tr,
                                message: 'tasks.confirm_accept_message'.tr,
                                confirmText: 'tasks.accept'.tr,
                                confirmColor: Colors.green,
                                onTap: () async {
                                  await Get.find<HomeController>().updateTask(
                                    task.copyWith(
                                      status: StorageKeys.status_approved,
                                    ),
                                  );
                                },
                              );
                            }
                          },
                          child: const Icon(Icons.more_vert),
                          tooltip: 'tasks.options_tooltip'.tr,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // --- الحالة و الأولوية ---
                  Row(
                    children: [
                      _buildstatusTag(task.status),
                      const SizedBox(width: 8),
                      _buildpriortyTag(task.priority),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // --- الوصف ---
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  // --- التقدم ---
                  Text(
                    'tasks.progress_label'.tr,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: task.progress ?? 0,
                          color: Colors.blue,
                          backgroundColor: Colors.grey.shade200,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${((task.progress ?? 0) * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage(
                                task.assignedImageUrl.isEmpty
                                    ? '${StorageKeys.supabaseStorageBaseUrl}/Avatar.png'
                                    : task.assignedImageUrl,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                Get.find<HomeController>().employees
                                        .firstWhereOrNull(
                                          (emp) => emp.id == task.assignedTo,
                                        )
                                        ?.name ??
                                    '',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    FunHelper.formatdate(task.fromDate)
                                        .toString(),
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Builder(
                              builder: (_) {
                                final deadlineText = _stilltime(task.toDate);
                                return Text(
                                  deadlineText,
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        deadlineText ==
                                                'tasks.deadline_expired'.tr
                                            ? Colors.red
                                            : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('tasks.view_details'.tr),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _stilltime(DateTime enddate) {
    final now = DateTime.now();
    final difference = enddate.difference(now);

    if (difference.isNegative) {
      return 'tasks.deadline_expired'.tr;
    } else {
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;

      final parts = <String>[];
      if (days > 0) {
        parts.add('tasks.time_days'.trParams({'count': '$days'}));
      }
      if (hours > 0) {
        parts.add('tasks.time_hours'.trParams({'count': '$hours'}));
      }
      if (minutes > 0) {
        parts.add('tasks.time_minutes'.trParams({'count': '$minutes'}));
      }
      return parts.join(' ');
    }
  }

  Widget _buildpriortyTag(String raw) {
    final key = FunHelper.canonicalStoredPriority(raw);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getprioritybgColor(key),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        FunHelper.trStored(raw, kind: StoredValueKind.priority),
        style: TextStyle(
          color: _getPriorityColor(key),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

Widget _buildstatusTag(String raw) {
  final key = FunHelper.canonicalStoredStatus(raw);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _getStatusbgColor(key),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      FunHelper.trStored(raw, kind: StoredValueKind.taskStatus),
      style: TextStyle(
        color: _getStatusColor(key),
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Color _getPriorityColor(String priority) {
  switch (priority) {
    case 'normal':
      return Colors.blue;
    case 'imp':
      return Colors.orange;
    case 'veryimp':
      return Colors.red;
    case 'veryveryimp':
      return Colors.red.shade900;
    default:
      return Colors.green;
  }
}

Color _getprioritybgColor(String priority) {
  switch (priority) {
    case 'normal':
      return Colors.blue.shade50;
    case 'imp':
      return Colors.orange.shade50;
    case 'veryimp':
      return Colors.red.shade50;
    case 'veryveryimp':
      return Colors.red.shade100;
    default:
      return Colors.green.shade50;
  }
}

Color _getStatusColor(String status) {
  switch (status) {
    case StorageKeys.status_under_revision:
      return Colors.blue;
    case StorageKeys.status_ready_to_publish:
      return Colors.teal;
    case StorageKeys.status_approved:
      return Colors.green;
    case StorageKeys.status_scheduled:
      return Colors.orange;
    case StorageKeys.status_processing:
      return Colors.amber;
    case StorageKeys.status_published:
      return Colors.lightGreen;
    case StorageKeys.status_rejected:
      return Colors.red;
    case StorageKeys.status_in_edit:
      return Colors.purple;
    case StorageKeys.status_edit_requested:
      return Colors.deepOrange;
    case StorageKeys.status_not_start_yet:
      return Colors.grey;
    default:
      return Colors.black45;
  }
}

Color _getStatusbgColor(String status) {
  switch (status) {
    case StorageKeys.status_under_revision:
      return Colors.blue.shade50;
    case StorageKeys.status_ready_to_publish:
      return Colors.teal.shade50;
    case StorageKeys.status_approved:
      return Colors.green.shade50;
    case StorageKeys.status_scheduled:
      return Colors.orange.shade50;
    case StorageKeys.status_processing:
      return Colors.amber.shade50;
    case StorageKeys.status_published:
      return Colors.lightGreen.shade50;
    case StorageKeys.status_rejected:
      return Colors.red.shade50;
    case StorageKeys.status_in_edit:
      return Colors.purple.shade50;
    case StorageKeys.status_edit_requested:
      return Colors.deepOrange.shade50;
    case StorageKeys.status_not_start_yet:
      return Colors.grey.shade200;
    default:
      return Colors.grey.shade200;
  }
}

class OptionsMenu extends StatelessWidget {
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const OptionsMenu({this.onView, this.onEdit, this.onDelete, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            icon: Icons.remove_red_eye_outlined,
            text: 'tasks.view'.tr,
            color: Colors.green,
            onTap: onView,
          ),
          _buildOption(
            icon: Icons.edit_outlined,
            text: 'edit'.tr,
            color: Colors.blueAccent,
            onTap: onEdit,
          ),
          _buildOption(
            icon: Icons.delete_outline,
            text: 'delete'.tr,
            color: Colors.red,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 20),
            Text(
              text,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
