import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/View/EmployeeDashboard/Shared/AddContentEmployeeDialog.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/task_status_visuals.dart';
import 'package:point/View/Tasks/Shared/add_task_comment_dialog.dart';
import 'package:point/View/Tasks/Shared/task_client_display_name.dart';
import 'package:point/View/Tasks/Shared/deadline_extension_request_dialog.dart';
import 'package:point/View/Tasks/Shared/open_task_final_work.dart';
import 'package:point/View/Tasks/Shared/task_details_feedback_widgets.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// صورة المكلَّف في البطاقة: الحقل المخزّن في المهمة قد يكون فارغاً لمهام قديمة،
/// فيُستكمل من بيانات الموظف الحالية كما في الهيدر.
/// After approval (or once the task is completed), status must not be reverted
/// from the quick menu — use final work instead.
bool _employeeHideQuickStatusChangeMenu(TaskModel task) {
  final s = FunHelper.canonicalStoredStatus(task.status);
  if (s == StorageKeys.status_rejected) return true;
  if (s == StorageKeys.status_approved) return true;
  if (StorageKeys.isTaskSuccessfulTerminalStatus(s)) return true;
  return false;
}

bool _employeeRejectedReadOnlyView(TaskModel task) {
  return FunHelper.canonicalStoredStatus(task.status) ==
      StorageKeys.status_rejected;
}

String _resolvedAssignedAvatarUrl(TaskModel task, EmployeeModel? assignee) {
  final fromTask = task.assignedImageUrl.trim();
  if (fromTask.isNotEmpty) return fromTask;
  final fromEmployee = assignee?.image?.trim() ?? '';
  if (fromEmployee.isNotEmpty) return fromEmployee;
  return kDefaultAvatarUrl;
}

/// "كل الأقسام" on the employee dashboard: show which department the task belongs to.
bool _showTaskDepartmentBadge(HomeController controller) {
  final e = controller.currentEmployee.value;
  if (e == null || e.role.trim().toLowerCase() != 'employee') return false;
  return controller.employeeDashboardDepartmentFilterArg == null;
}

bool _employeeMayShowDeadlineExtension(HomeController c, TaskModel t) {
  final id = c.currentEmployee.value?.id ?? '';
  if (id.isEmpty || t.assignedTo.trim() != id) return false;
  if (!StorageKeys.isTaskOngoing(t)) return false;
  if (t.deadlineExtensionStatus.trim() ==
      TaskModel.kDeadlineExtensionPending) {
    return false;
  }
  return true;
}

class EmployeeTaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;

  EmployeeTaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        final latestNote = task.notes.isNotEmpty ? task.notes.last : null;
        final assignee = controller.employees.firstWhereOrNull(
          (emp) => emp.id == task.assignedTo,
        );
        final assignedAvatarUrl = _resolvedAssignedAvatarUrl(task, assignee);
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
              color: resolveAppTheme().cardSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: resolveAppTheme().shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = Responsive.isDesktop(context);
              final scrollView = SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- العنوان + النقاط الثلاثة ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!_employeeHideQuickStatusChangeMenu(task))
                          SizedBox(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                textTheme: Theme.of(context).textTheme.apply(
                                  bodyColor: resolveAppTheme().primaryText,
                                  displayColor: resolveAppTheme().primaryText,
                                ),
                              ),
                              child: PopupMenuButton<int>(
                              tooltip: 'tasks.options_tooltip'.tr,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color: resolveAppTheme().cardSurface,
                              elevation: 4,
                              itemBuilder: (context) {
                                if (task.type == '0') {
                                  return [
                                    PopupMenuItem(
                                      value: 10,
                                      child: TaskStatusVisuals.popupMenuRow(context: context,
                                        label: StorageKeys
                                            .status_promotion_in_progress
                                            .tr,
                                        rawOrCanonicalForIcon:
                                            StorageKeys.status_promotion_in_progress,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 11,
                                      child: TaskStatusVisuals.popupMenuRow(context: context,
                                        label: StorageKeys
                                            .status_promotion_ad_platform_review
                                            .tr,
                                        rawOrCanonicalForIcon: StorageKeys
                                            .status_promotion_ad_platform_review,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 12,
                                      child: TaskStatusVisuals.popupMenuRow(context: context,
                                        label: StorageKeys.status_promotion_running
                                            .tr,
                                        rawOrCanonicalForIcon:
                                            StorageKeys.status_promotion_running,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 13,
                                      child: TaskStatusVisuals.popupMenuRow(context: context,
                                        label: StorageKeys.status_promotion_finished
                                            .tr,
                                        rawOrCanonicalForIcon:
                                            StorageKeys.status_promotion_finished,
                                      ),
                                    ),
                                  ];
                                }
                                return [
                                  PopupMenuItem(
                                    value: 0,
                                    child: TaskStatusVisuals.popupMenuRow(context: context,
                                      label: StorageKeys.status_processing.tr,
                                      rawOrCanonicalForIcon:
                                          StorageKeys.status_processing,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 1,
                                    child: TaskStatusVisuals.popupMenuRow(context: context,
                                      label: StorageKeys.status_under_revision.tr,
                                      rawOrCanonicalForIcon:
                                          StorageKeys.status_under_revision,
                                    ),
                                  ),
                                ];
                              },
                              onSelected: (value) {
                                if (_employeeHideQuickStatusChangeMenu(task)) {
                                  return;
                                }
                                if (task.type == '0') {
                                  final String? st =
                                      value == 10
                                          ? StorageKeys.status_promotion_in_progress
                                          : value == 11
                                          ? StorageKeys
                                              .status_promotion_ad_platform_review
                                          : value == 12
                                          ? StorageKeys.status_promotion_running
                                          : value == 13
                                          ? StorageKeys.status_promotion_finished
                                          : null;
                                  if (st != null) {
                                    controller.updateTask(
                                      task.copyWithPromotionStatusAligned(st),
                                    );
                                  }
                                  return;
                                }
                                if (value == 0) {
                                  controller.updateTask(
                                    task.copyWith(
                                      status: StorageKeys.status_processing,
                                    ),
                                  );
                                } else if (value == 1) {
                                  openTaskFinalWorkDialog(
                                    context: context,
                                    task: task,
                                  );
                                }
                              },
                              child: Container(
                                constraints:
                                    isDesktop
                                        ? const BoxConstraints(
                                          minWidth: 110,
                                          maxWidth: 110,
                                        )
                                        : const BoxConstraints(minWidth: 0),
                                height: 32,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: resolveAppTheme().border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'tasks.change_status'.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.keyboard_arrow_down_sharp,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // --- القسم (عند «كل الأقسام») + الحالة + الأولوية ---
                      Obx(() {
                        controller.activeDepartmentFilter.value;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_showTaskDepartmentBadge(controller))
                              _buildTaskDepartmentBadge(context, task),
                            _buildStatusTag(context, task.status),
                            _buildPriorityTag(context, task.priority),
                          ],
                        );
                      }),
                      TaskCardClientNameRow(task: task),
                      Obx(() {
                        final live =
                            controller.tasks.firstWhereOrNull(
                              (x) => x.id == task.id,
                            ) ??
                            task;
                        return TaskDetailsFeedbackWidgets.compactEmployeeAlerts(
                          context,
                          live,
                        );
                      }),
                      const SizedBox(height: 8),

                      // --- الوصف ---
                      Text(
                        task.description,
                        maxLines: 3,
                        style: TextStyle(
                          color: resolveAppTheme().secondaryText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- التقدم ---
                      Text(
                        'tasks.progress_label'.tr,
                        style: TextStyle(color: resolveAppTheme().mutedText),
                      ),
                      const SizedBox(height: 4),
                      Obx(() {
                        final live =
                            controller.tasks.firstWhereOrNull(
                              (x) => x.id == task.id,
                            ) ??
                            task;
                        return SizedBox(
                          width: constraints.maxWidth,
                          height: 56,
                          child:
                              _employeeRejectedReadOnlyView(live)
                                  ? Center(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: LinearProgressIndicator(
                                        value: live.progress ?? 0,
                                        minHeight: 10,
                                        backgroundColor: resolveAppTheme().unselected,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  )
                                  : DraggableProgressBar(
                                    key: ValueKey('progress-${live.id}'),
                                    initialValue: live.progress ?? 0,
                                    color: Colors.blue,
                                    backgroundColor: resolveAppTheme().unselected,
                                    height: 10,
                                    borderRadius: BorderRadius.circular(20),
                                    onChanged: (value) {
                                      controller.updateTask(
                                        live.copyWith(progress: value),
                                      );
                                    },
                                  ),
                        );
                      }),

                      const SizedBox(height: 12),

                      if (latestNote != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: resolveAppTheme().panelTint,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'tasks.latest_comment'.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: resolveAppTheme().accentText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                latestNote.note,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: resolveAppTheme().primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _buildNoteMeta(
                                  latestNote.byWho,
                                  latestNote.timestamp,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: resolveAppTheme().mutedText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // --- المكلَّف ---
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(assignedAvatarUrl),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              (assignee?.name ?? '')
                                  .substring(
                                    0,
                                    ((assignee?.name ?? '').length > 10)
                                        ? 10
                                        : (assignee?.name ?? '').length,
                                  ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Builder(
                        builder: (ctx) {
                          final dir = Directionality.of(ctx);
                          final remaining = FunHelper.taskTimeUntilDeadline(
                            task.toDate,
                          );
                          final expired =
                              remaining == 'tasks.deadline_expired'.tr;
                          final isDark =
                              Theme.of(ctx).brightness == Brightness.dark;
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  expired
                                      ? Colors.red.withValues(
                                        alpha: isDark ? 0.14 : 0.08,
                                      )
                                      : (isDark
                                          ? AppColors.primary.withValues(
                                            alpha: 0.12,
                                          )
                                          : const Color(0xFFEFF6FF)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    expired
                                        ? Colors.red.withValues(alpha: 0.35)
                                        : (isDark
                                            ? AppColors.primary.withValues(
                                              alpha: 0.3,
                                            )
                                            : const Color(0xFFBFDBFE)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'tasks.time_remaining_label'.tr,
                                  textAlign: TextAlign.start,
                                  textDirection: dir,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: ctx.appTheme.mutedText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  remaining,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.start,
                                  textDirection: dir,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        expired
                                            ? Colors.red.shade700
                                            : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Builder(
                          builder: (context) {
                            if (_employeeRejectedReadOnlyView(task)) {
                              // [Padding] above uses 12+12 horizontal; fill that row width.
                              final rowW = (constraints.maxWidth - 24)
                                  .clamp(0.0, double.infinity);
                              return SizedBox(
                                width: rowW,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        resolveAppTheme().primaryText,
                                    side: BorderSide(
                                      color: resolveAppTheme().border,
                                    ),
                                    minimumSize: Size(rowW, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onPressed: onTap,
                                  child: Text(
                                    'tasks.view_task_details'.tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              );
                            }
                            final columnGap =
                                Responsive.isDesktop(context) ? 12.0 : 8.0;
                            const rowGap = 10.0;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                employeeTaskCardActionRows(
                                  columnSpacing: columnGap,
                                  rowSpacing: rowGap,
                                  cells: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            resolveAppTheme().primaryText,
                                        side: BorderSide(
                                          color: resolveAppTheme().border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                      onPressed: () {
                                        addContentEmployeeDialog(
                                          context,
                                          model: task,
                                        );
                                      },
                                      child: Text(
                                        'addcontent'.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            resolveAppTheme().primaryText,
                                        side: BorderSide(
                                          color: resolveAppTheme().border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                      onPressed:
                                          () => showAddTaskCommentDialog(
                                            context: context,
                                            task: task,
                                          ),
                                      child: Text(
                                        'tasks.add_comment_title'.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                      onPressed: onTap,
                                      child: Text(
                                        'tasks.view_task_details'.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: rowGap),
                                if (_employeeMayShowDeadlineExtension(
                                  controller,
                                  task,
                                )) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            resolveAppTheme().primaryText,
                                        side: BorderSide(
                                          color: resolveAppTheme().border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                      onPressed: () =>
                                          showDeadlineExtensionRequestDialog(
                                            context: context,
                                            task: task,
                                          ),
                                      child: Text(
                                        'tasks.deadline_extension_button'.tr,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: rowGap),
                                ],
                                if (shouldShowPrimaryFinalWorkTaskButton(
                                      task,
                                      controller.currentEmployee.value?.role ??
                                          '',
                                    )) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                      onPressed: () => openTaskFinalWorkDialog(
                                        context: context,
                                        task: task,
                                      ),
                                      child: Text(
                                        'tasks.final_deliverable_section'.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (constraints.hasBoundedHeight &&
                  constraints.maxHeight.isFinite) {
                return SizedBox(
                  height: constraints.maxHeight,
                  width: constraints.maxWidth,
                  child: scrollView,
                );
              }
              return scrollView;
            },
          ),
        );
      },
    );
  }

  String _buildNoteMeta(String author, DateTime timestamp) {
    final safeAuthor =
        author.trim().isEmpty ? 'content.dialog.unknown'.tr : author.trim();
    return '$safeAuthor • ${_formatRelativeTime(timestamp)}';
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 60) return 'common.now'.tr;
    if (diff.inMinutes < 60) {
      return 'time.ago_minutes'.trParams({'count': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'time.ago_hours'.trParams({'count': '${diff.inHours}'});
    }
    if (diff.inDays < 30) {
      return 'time.ago_days'.trParams({'count': '${diff.inDays}'});
    }
    final months = (diff.inDays / 30).floor();
    if (months < 12) {
      return 'time.ago_months'.trParams({'count': '$months'});
    }
    final years = (months / 12).floor();
    return 'time.ago_years'.trParams({'count': '$years'});
  }

  Widget _buildPriorityTag(BuildContext context, String raw) {
    final key = FunHelper.canonicalStoredPriority(raw);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPriorityBgColor(context, key),
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

/// صفوف بعرض البطاقة: زرّان في كل صف؛ إن وُجد عدد فردي يكون الصف الأخير بعرض كامل.
/// أضف عناصر إلى [cells] بالترتيب لإنشاء صفوف إضافية (كل صفين = صف واحد).
Widget employeeTaskCardActionRows({
  required List<Widget> cells,
  required double columnSpacing,
  required double rowSpacing,
}) {
  final rows = <Widget>[];
  for (var i = 0; i < cells.length; i += 2) {
    if (i > 0) rows.add(SizedBox(height: rowSpacing));
    if (i + 1 < cells.length) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: cells[i]),
            SizedBox(width: columnSpacing),
            Expanded(child: cells[i + 1]),
          ],
        ),
      );
    } else {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Expanded(child: cells[i])],
        ),
      );
    }
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: rows,
  );
}

Widget _buildTaskDepartmentBadge(BuildContext context, TaskModel task) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: resolveAppTheme().panelTint,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.35),
      ),
    ),
    child: Text(
      NotificationService.departmentNameFromTaskType(task.type),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: resolveAppTheme().accentText,
      ),
    ),
  );
}

Widget _buildStatusTag(BuildContext context, String raw) {
  final key = FunHelper.canonicalStoredStatus(raw);
  return TaskStatusVisuals.statusChip(
    rawStatus: raw,
    fg: _getStatusColor(key),
    bg: _getStatusBgColor(context, key),
  );
}

Color _getPriorityColor(String priority) {
  switch (priority) {
    case 'normal':
      return Colors.blue.shade700;
    case 'imp':
      return Colors.orange.shade800;
    case 'veryimp':
      return Colors.red.shade700;
    case 'veryveryimp':
      return Colors.red.shade900;
    default:
      return Colors.blueGrey.shade700;
  }
}

Color _getStatusColor(String status) {
  switch (status) {
    case StorageKeys.status_under_revision:
      return Colors.blue.shade700;
    case StorageKeys.status_awaiting_manager:
      return Colors.indigo.shade700;
    case StorageKeys.status_ready_to_publish:
      return Colors.teal.shade700;
    case StorageKeys.status_approved:
      return Colors.green.shade700;
    case StorageKeys.status_scheduled:
      return Colors.orange.shade800;
    case StorageKeys.status_processing:
      return Colors.amber.shade900;
    case StorageKeys.status_task_completed:
      return Colors.lightGreen.shade800;
    case StorageKeys.status_published:
      return Colors.lightGreen.shade800;
    case StorageKeys.status_rejected:
      return Colors.red.shade700;
    case StorageKeys.status_in_edit:
      return Colors.purple.shade700;
    case StorageKeys.status_edit_requested:
      return Colors.deepOrange.shade700;
    case StorageKeys.status_not_start_yet:
      return Colors.grey.shade700;
    case StorageKeys.status_promotion_in_progress:
      return Colors.amber.shade900;
    case StorageKeys.status_promotion_ad_platform_review:
      return Colors.blue.shade800;
    case StorageKeys.status_promotion_running:
      return Colors.green.shade800;
    case StorageKeys.status_promotion_finished:
      return Colors.blueGrey.shade700;
    default:
      return Colors.blueGrey.shade700;
  }
}

Color _getStatusBgColor(BuildContext context, String status) {
  final fg = _getStatusColor(status);
  if (Theme.of(context).brightness == Brightness.dark) return fg.withValues(alpha: 0.18);
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
      return Colors.blueGrey.shade50;
  }
}

Color _getPriorityBgColor(BuildContext context, String priority) {
  final fg = _getPriorityColor(priority);
  if (Theme.of(context).brightness == Brightness.dark) return fg.withValues(alpha: 0.18);
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
      return Colors.blueGrey.shade50;
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
              color: resolveAppTheme().cardSurface,
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
                color: resolveAppTheme().primaryText,
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

class DraggableProgressBar extends StatefulWidget {
  final double initialValue;
  final Color color;
  final Color backgroundColor;
  final double height;
  final BorderRadius borderRadius;
  final ValueChanged<double>? onChanged;
  final int stepsCount;

  const DraggableProgressBar({
    Key? key,
    this.initialValue = 0,
    this.color = Colors.blue,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.height = 6,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.onChanged,
    this.stepsCount = 5,
  }) : super(key: key);

  @override
  State<DraggableProgressBar> createState() => _DraggableProgressBarState();
}

class _DraggableProgressBarState extends State<DraggableProgressBar> {
  double progress = 0.0;

  @override
  void initState() {
    super.initState();
    progress = _snapToStep(widget.initialValue.clamp(0.0, 1.0));
  }

  @override
  void didUpdateWidget(covariant DraggableProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      progress = _snapToStep(widget.initialValue.clamp(0.0, 1.0));
    }
  }

  double _snapToStep(double value) {
    final segments = (widget.stepsCount - 1).clamp(1, 100);
    final stepSize = 1 / segments;
    final snapped = (value / stepSize).round() * stepSize;
    return snapped.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveMarkerColor =
        isDark ? theme.elevatedSurface : Colors.white;
    final inactiveBorderColor =
        isDark ? theme.border : Colors.grey.shade400;
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth;
        final segments = (widget.stepsCount - 1).clamp(1, 100);
        final currentStepIndex = (progress * segments).round();
        final markerSize = widget.height + 8;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: markerSize,
              child: Stack(
                children: [
                  Positioned(
                    top: (markerSize - widget.height) / 2,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: widget.borderRadius,
                      child: Stack(
                        children: [
                          Container(
                            height: widget.height,
                            color: widget.backgroundColor,
                          ),
                          Positioned(
                            right: 0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: widget.height,
                              width: boxWidth * progress,
                              color: widget.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(widget.stepsCount, (index) {
                        final isActive = index <= currentStepIndex;
                        return InkWell(
                          borderRadius: BorderRadius.circular(markerSize),
                          onTap: () {
                            final stepProgress = index / segments;
                            final snapped = _snapToStep(stepProgress);
                            if (snapped == progress) return;
                            setState(() => progress = snapped);
                            widget.onChanged?.call(snapped);
                          },
                          child: Container(
                            width: markerSize,
                            height: markerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? widget.color : inactiveMarkerColor,
                              border: Border.all(
                                color:
                                    isActive
                                        ? widget.color
                                        : inactiveBorderColor,
                                width: 1.2,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.secondaryText,
              ),
            ),
          ],
        );
      },
    );
  }
}
