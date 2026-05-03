import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Tasks/Dialogs/ContentWriteDialog.dart';
import 'package:point/View/Tasks/Dialogs/DesignDialog.dart';
import 'package:point/View/Tasks/Dialogs/MontageDialog.dart';
import 'package:point/View/Tasks/Dialogs/PhotographyDialog.dart';
import 'package:point/View/Tasks/Dialogs/AdministrativeDialog.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';
import 'package:point/View/Tasks/Dialogs/PromotionDialog.dart';
import 'package:point/View/Tasks/Dialogs/PublishDialog.dart';
import 'package:point/View/Tasks/Shared/add_task_comment_dialog.dart';
import 'package:point/View/Tasks/Shared/open_task_final_work.dart';
import 'package:point/View/Tasks/Shared/reject_task_dialog.dart';
import 'package:point/View/Tasks/Shared/request_task_modification_dialog.dart';
import 'package:point/View/Tasks/Shared/task_client_display_name.dart';
import 'package:point/View/Tasks/Shared/task_details_feedback_widgets.dart';
import 'package:point/View/Shared/task_status_visuals.dart';

bool _taskInManagementReview(TaskModel task) {
  final s = FunHelper.canonicalStoredStatus(task.status);
  if (task.type == '0') {
    return s == StorageKeys.status_promotion_ad_platform_review ||
        s == StorageKeys.status_awaiting_manager;
  }
  return s == StorageKeys.status_under_revision ||
      s == StorageKeys.status_awaiting_manager;
}

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
                  Builder(
                    builder: (context) {
                      final hc = Get.find<HomeController>();
                      final role = hc.currentEmployee.value?.role ?? '';
                      final canEditDirectly =
                          role == 'admin' || role == 'supervisor';
                      final canEscalate =
                          role == 'supervisor' &&
                          FunHelper.taskStatusAllowsSupervisorDirectOrEscalate(
                            task.status,
                          );
                      final hideAccept = FunHelper.supervisorShouldHideTaskAccept(
                        role,
                        task.status,
                      );
                      return Row(
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
                              itemBuilder: (context) {
                                final items = <PopupMenuEntry<int>>[
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
                                        Text(
                                          canEditDirectly
                                              ? 'edit'.tr
                                              : 'tasks.request_edit'.tr,
                                        ),
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
                                  if (canEditDirectly &&
                                      _taskInManagementReview(task))
                                    PopupMenuItem(
                                      value: 70,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'tasks.request_modification_menu'
                                                .tr,
                                          ),
                                          Icon(
                                            Icons.edit_note_outlined,
                                            color: Colors.deepOrange,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                ];
                                if (canEscalate && task.type != '0') {
                                  items.add(
                                    PopupMenuItem(
                                      value: 4,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'tasks.supervisor_approve_direct'
                                                .tr,
                                          ),
                                          Icon(
                                            Icons.check,
                                            color: Colors.green,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  items.add(
                                    PopupMenuItem(
                                      value: 5,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'tasks.supervisor_send_to_manager'
                                                .tr,
                                          ),
                                          Icon(
                                            Icons.forward_to_inbox_rounded,
                                            color: Colors.indigo,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else if (!hideAccept) {
                                  items.add(
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
                                  );
                                }
                                if (task.type == '0' && canEditDirectly) {
                                  items.add(const PopupMenuDivider(height: 12));
                                  items.add(
                                    PopupMenuItem(
                                      value: 20,
                                      child: TaskStatusVisuals.popupMenuRow(
                                        label: StorageKeys
                                            .status_promotion_in_progress
                                            .tr,
                                        rawOrCanonicalForIcon:
                                            StorageKeys.status_promotion_in_progress,
                                      ),
                                    ),
                                  );
                                  items.add(
                                    PopupMenuItem(
                                      value: 21,
                                      child: TaskStatusVisuals.popupMenuRow(
                                        label: StorageKeys
                                            .status_promotion_ad_platform_review
                                            .tr,
                                        rawOrCanonicalForIcon: StorageKeys
                                            .status_promotion_ad_platform_review,
                                      ),
                                    ),
                                  );
                                  items.add(
                                    PopupMenuItem(
                                      value: 22,
                                      child: TaskStatusVisuals.popupMenuRow(
                                        label: StorageKeys.status_promotion_running
                                            .tr,
                                        rawOrCanonicalForIcon:
                                            StorageKeys.status_promotion_running,
                                      ),
                                    ),
                                  );
                                  items.add(
                                    PopupMenuItem(
                                      value: 23,
                                      child: TaskStatusVisuals.popupMenuRow(
                                        label: StorageKeys.status_promotion_finished
                                            .tr,
                                        rawOrCanonicalForIcon:
                                            StorageKeys.status_promotion_finished,
                                      ),
                                    ),
                                  );
                                } else if (task.type != '0' && canEditDirectly) {
                                  // Same quick status paths as [EmployeeTaskCard]
                                  // (non–promotion tasks; type encodes department workflow).
                                  items.add(const PopupMenuDivider(height: 12));
                                  items.add(
                                    PopupMenuItem(
                                      value: 60,
                                      child: TaskStatusVisuals.popupMenuRow(
                                        label: StorageKeys.status_processing.tr,
                                        rawOrCanonicalForIcon:
                                            StorageKeys.status_processing,
                                      ),
                                    ),
                                  );
                                  items.add(
                                    PopupMenuItem(
                                      value: 61,
                                      child: TaskStatusVisuals.popupMenuRow(
                                        label: StorageKeys.status_under_revision.tr,
                                        rawOrCanonicalForIcon:
                                            StorageKeys.status_under_revision,
                                      ),
                                    ),
                                  );
                                }
                                return items;
                              },
                              onSelected: (value) {
                                if (value == 0) {
                                  onTap();
                                } else if (value == 1) {
                                  switch (task.type) {
                                    case '0':
                                      showPromotionDialog(context, model: task);
                                      break;
                                    case '1':
                                      designDialog(context, model: task);
                                      break;
                                    case '2':
                                      photographyDialog(
                                        context,
                                        model: task,
                                      );
                                      break;
                                    case '3':
                                      contentWriteDialog(context, model: task);
                                      break;
                                    case '4':
                                      montageDialog(context, model: task);
                                      break;
                                    case '5':
                                      publishDialog(context, model: task);
                                      break;
                                    case '6':
                                      programmingDialog(context, model: task);
                                      break;
                                    case '7':
                                      administrationDialog(context, model: task);
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
                                      await Get.find<HomeController>()
                                          .deleteTask(task.id!);
                                    },
                                  );
                                } else if (value == 3) {
                                  showRejectTaskDialog(
                                    context: context,
                                    task: task,
                                  );
                                } else if (value == 70) {
                                  showRequestTaskModificationDialog(
                                    context: context,
                                    task: task,
                                  );
                                } else if (value >= 20 &&
                                    value <= 23 &&
                                    task.type == '0') {
                                  final st = [
                                    StorageKeys.status_promotion_in_progress,
                                    StorageKeys
                                        .status_promotion_ad_platform_review,
                                    StorageKeys.status_promotion_running,
                                    StorageKeys.status_promotion_finished,
                                  ][value - 20];
                                  Get.find<HomeController>().updateTask(
                                    task.copyWithPromotionStatusAligned(st),
                                  );
                                } else if (value == 4) {
                                  if (canEscalate) {
                                    FunHelper.showConfirmDailog(
                                      context,
                                      title:
                                          'tasks.confirm_supervisor_approve_direct_title'
                                              .tr,
                                      message:
                                          'tasks.confirm_supervisor_approve_direct_message'
                                              .tr,
                                      confirmText:
                                          'tasks.supervisor_approve_direct'.tr,
                                      confirmColor: Colors.green,
                                      onTap: () async {
                                        final next =
                                            task.type == '0'
                                                ? task.copyWithPromotionStatusAligned(
                                                    StorageKeys.status_approved,
                                                  )
                                                : task.copyWith(
                                                    status: StorageKeys
                                                        .status_approved,
                                                  );
                                        await Get.find<HomeController>()
                                            .updateTask(next);
                                      },
                                    );
                                  } else {
                                    FunHelper.showConfirmDailog(
                                      context,
                                      title: 'tasks.confirm_accept_title'.tr,
                                      message:
                                          'tasks.confirm_accept_message'.tr,
                                      confirmText: 'tasks.accept'.tr,
                                      confirmColor: Colors.green,
                                      onTap: () async {
                                        final next =
                                            task.type == '0'
                                                ? task.copyWithPromotionStatusAligned(
                                                    StorageKeys.status_approved,
                                                  )
                                                : task.copyWith(
                                                    status: StorageKeys
                                                        .status_approved,
                                                  );
                                        await Get.find<HomeController>()
                                            .updateTask(next);
                                      },
                                    );
                                  }
                                } else if (value == 5) {
                                  FunHelper.showConfirmDailog(
                                    context,
                                    title:
                                        'tasks.confirm_send_to_manager_title'.tr,
                                    message:
                                        'tasks.confirm_send_to_manager_message'
                                            .tr,
                                    confirmText:
                                        'tasks.supervisor_send_to_manager'.tr,
                                    confirmColor: Colors.indigo,
                                    onTap: () async {
                                      await Get.find<HomeController>()
                                          .updateTask(
                                            task.copyWith(
                                              status: StorageKeys
                                                  .status_awaiting_manager,
                                            ),
                                          );
                                    },
                                  );
                                } else if (value == 60 &&
                                    task.type != '0' &&
                                    canEditDirectly) {
                                  Get.find<HomeController>().updateTask(
                                    task.copyWith(
                                      status: StorageKeys.status_processing,
                                    ),
                                  );
                                } else if (value == 61 &&
                                    task.type != '0' &&
                                    canEditDirectly) {
                                  // Match quick "In progress" (60): set status directly. Do not use
                                  // [openTaskFinalWorkDialog] — for admin/supervisor it opens the
                                  // final-deliverable editor instead of changing status.
                                  Get.find<HomeController>().updateTask(
                                    task.copyWith(
                                      status:
                                          StorageKeys.status_under_revision,
                                    ),
                                  );
                                }
                              },
                              child: const Icon(Icons.more_vert),
                              tooltip: 'tasks.options_tooltip'.tr,
                            ),
                          ),
                        ],
                      );
                    },
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
                  TaskCardClientNameRow(task: task),
                  Obx(() {
                    final hc = Get.find<HomeController>();
                    final live =
                        hc.tasks.firstWhereOrNull((x) => x.id == task.id) ??
                        task;
                    if (live.deadlineExtensionStatus.trim() !=
                        TaskModel.kDeadlineExtensionPending) {
                      return const SizedBox(height: 8);
                    }
                    final role = hc.currentEmployee.value?.role ?? '';
                    final mgr = role == 'admin' || role == 'supervisor';
                    final req = live.deadlineExtensionRequestedTo;
                    final theme = Theme.of(context);
                    final cs = theme.colorScheme;
                    const stripPurple = Color(0xFF5C5589);
                    const stripBg = Color(0xFFF7F6FF);
                    const stripBorder = Color(0xFFE4DEF7);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: stripBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: stripBorder),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer.withValues(
                                        alpha: 0.45,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.schedule_send_rounded,
                                        color: cs.primary,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: InkWell(
                                      onTap: onTap,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Text(
                                          'tasks.deadline_extension_pending_card_strip'
                                              .tr,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: stripPurple,
                                                height: 1.25,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (mgr) ...[
                                    const SizedBox(width: 10),
                                    Tooltip(
                                      message:
                                          'tasks.deadline_extension_approve'.tr,
                                      child: IconButton(
                                        visualDensity: VisualDensity.compact,
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF3D9142,
                                          ),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor:
                                              Colors.grey.shade300,
                                          minimumSize: const Size(36, 36),
                                          maximumSize: const Size(36, 36),
                                          padding: EdgeInsets.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          shape: const CircleBorder(),
                                          elevation: 0,
                                        ),
                                        onPressed:
                                            req == null
                                                ? null
                                                : () async {
                                                  await hc.updateTask(
                                                    live.copyWith(
                                                      toDate: req,
                                                      deadlineExtensionStatus:
                                                          '',
                                                      deadlineExtensionReason:
                                                          '',
                                                      deadlineExtensionRequestedAt:
                                                          '',
                                                      deadlineExtensionRequestedBy:
                                                          '',
                                                      deadlineExtensionDeniedNote:
                                                          '',
                                                      clearDeadlineExtensionRequestedTo:
                                                          true,
                                                    ),
                                                  );
                                                },
                                        icon: const Icon(
                                          Icons.check_rounded,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Tooltip(
                                      message:
                                          'tasks.deadline_extension_deny'.tr,
                                      child: IconButton(
                                        visualDensity: VisualDensity.compact,
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                              cs.surfaceContainerLowest,
                                          foregroundColor: cs.error,
                                          minimumSize: const Size(36, 36),
                                          maximumSize: const Size(36, 36),
                                          padding: EdgeInsets.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          shape: CircleBorder(
                                            side: BorderSide(
                                              color: cs.error.withValues(
                                                alpha: 0.35,
                                              ),
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed:
                                            () =>
                                                TaskDetailsFeedbackWidgets.showDenyDeadlineExtensionDialog(
                                                  context,
                                                  live,
                                                ),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),

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
                        child: Builder(
                          builder: (context) {
                            final dir = Directionality.of(context);
                            final deadlineText =
                                FunHelper.taskTimeUntilDeadline(task.toDate);
                            final expired =
                                deadlineText == 'tasks.deadline_expired'.tr;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'tasks.time_remaining_label'.tr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.start,
                                  textDirection: dir,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blueGrey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  deadlineText,
                                  maxLines: 2,
                                  softWrap: true,
                                  textAlign: TextAlign.start,
                                  textDirection: dir,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: expired
                                        ? Colors.red.shade700
                                        : const Color(0xFF5C5589),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onTap,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                'tasks.view_details'.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => showAddTaskCommentDialog(
                                context: context,
                                task: task,
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                'tasks.add_comment_title'.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Builder(
                        builder: (context) {
                          final role =
                              Get.find<HomeController>()
                                  .currentEmployee
                                  .value
                                  ?.role ??
                              '';
                          if (!shouldShowPrimaryFinalWorkTaskButton(
                                task,
                                role,
                              )) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => openTaskFinalWorkDialog(
                                    context: context,
                                    task: task,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                  child: Text(
                                    'tasks.final_deliverable_section'.tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
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
  return TaskStatusVisuals.statusChip(
    rawStatus: raw,
    fg: _getStatusColor(key),
    bg: _getStatusbgColor(key),
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
    case StorageKeys.status_awaiting_manager:
      return Colors.indigo.shade700;
    case StorageKeys.status_ready_to_publish:
      return Colors.teal;
    case StorageKeys.status_approved:
      return Colors.green;
    case StorageKeys.status_scheduled:
      return Colors.orange;
    case StorageKeys.status_processing:
      return Colors.amber;
    case StorageKeys.status_task_completed:
      return Colors.lightGreen;
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
    case StorageKeys.status_promotion_in_progress:
      return Colors.amber.shade900;
    case StorageKeys.status_promotion_ad_platform_review:
      return Colors.blue.shade800;
    case StorageKeys.status_promotion_running:
      return Colors.green.shade800;
    case StorageKeys.status_promotion_finished:
      return Colors.blueGrey.shade700;
    default:
      return Colors.black45;
  }
}

Color _getStatusbgColor(String status) {
  switch (status) {
    case StorageKeys.status_under_revision:
      return Colors.blue.shade50;
    case StorageKeys.status_awaiting_manager:
      return Colors.indigo.shade50;
    case StorageKeys.status_ready_to_publish:
      return Colors.teal.shade50;
    case StorageKeys.status_approved:
      return Colors.green.shade50;
    case StorageKeys.status_scheduled:
      return Colors.orange.shade50;
    case StorageKeys.status_processing:
      return Colors.amber.shade50;
    case StorageKeys.status_task_completed:
      return Colors.lightGreen.shade50;
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
    case StorageKeys.status_promotion_in_progress:
      return Colors.amber.shade50;
    case StorageKeys.status_promotion_ad_platform_review:
      return Colors.blue.shade50;
    case StorageKeys.status_promotion_running:
      return Colors.green.shade50;
    case StorageKeys.status_promotion_finished:
      return Colors.blueGrey.shade100;
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
