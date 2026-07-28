import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/firestore/firestore_task_utils.dart'
    show taskTypeCodeForNormalizedDepartment;
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/View/EmployeeDashboard/attendance_check_in_card.dart';
import 'package:point/View/EmployeeDashboard/employee_mobile_app_bar.dart';
import 'package:point/View/EmployeeDashboard/Shared/EmployeeTaskCard.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/app_version_label.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/task_list_filters_bar.dart';
import 'package:point/View/Shared/task_status_visuals.dart';
import 'package:point/View/Tasks/DetailsDialogs/DContentWriteDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DDesignDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DMontageDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPhotographyDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DAdministrativeDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/LibraryPermissions.dart';

void _openEmployeeDashboardTaskDetails(BuildContext context, TaskModel task) {
  switch (task.type) {
    case '0':
      showCampaignDetailsDialog(context, task: task);
      break;
    case '1':
      showDesignDetailsDialog(context, task: task);
      break;
    case '2':
      showDPhotographyDialog(context, task: task);
      break;
    case '3':
      showContentWriteDialog(context, task: task);
      break;
    case '4':
      showMontageDialog(context, task: task);
      break;
    case '5':
      showPublishDialog(context, task: task);
      break;
    case '6':
      showProgrammingDialog(context, task: task);
      break;
    case '7':
      showAdministrativeTaskDetailsDialog(context, task: task);
      break;
    default:
  }
}

Widget _employeeDashboardDepartmentChip(
  BuildContext context, {
  required String label,
  required bool selected,
  required VoidCallback onSelected,
}) {
  final theme = context.appTheme;
  final foreground = selected ? Colors.white : theme.primaryText;
  final background = selected ? AppColors.primary : theme.inputFill;
  final borderColor = selected ? AppColors.primary : theme.border;

  return Material(
    color: background,
    shape: StadiumBorder(side: BorderSide(color: borderColor)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onSelected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 18, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _employeeDashboardDepartmentChips(
  BuildContext context,
  HomeController controller,
) {
  return Obx(() {
    final emp = controller.currentEmployee.value;
    if (emp == null ||
        emp.role.trim().toLowerCase() != 'employee' ||
        emp.departments.length <= 1) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _employeeDashboardDepartmentChip(
            context,
            label: 'employee.dashboard.all_departments'.tr,
            selected: controller.activeDepartmentFilter.value.isEmpty,
            onSelected: () {
              controller.activeDepartmentFilter.value = '';
              controller.filterTasks();
              controller.schedulePersistEmployeeDashboardTaskFilters();
            },
          ),
          ...emp.departments.map(
            (d) => _employeeDashboardDepartmentChip(
              context,
              label: StorageKeys.semanticDepartmentLabelKey(d).tr,
              selected: controller.activeDepartmentFilter.value == d,
              onSelected: () {
                controller.activeDepartmentFilter.value = d;
                controller.filterTasks();
                controller.schedulePersistEmployeeDashboardTaskFilters();
              },
            ),
          ),
        ],
      ),
    );
  });
}

Widget _employeeDashboardAttendanceSection(
  BuildContext context,
  HomeController controller,
) {
  final isMobile = Responsive.isMobile(context);
  final section = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AttendanceCheckInCard(),
      const SizedBox(height: 24),
      _employeeDashboardDepartmentChips(context, controller),
    ],
  );

  if (isMobile) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: section,
    );
  }

  return Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 28),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: section,
      ),
    ),
  );
}

/// Per-status counts for assigned tasks, ordered like the status filter dropdown.
/// Only statuses with count > 0 are returned.
List<MapEntry<String, int>> employeeDashboardAssignedTaskStatEntriesOrdered({
  required Iterable<TaskModel> assignedTasks,
  required String? departmentFilterArg,
}) {
  final ordered =
      StorageKeys.employeeDashboardTaskStatusFilterDropdownValuesForDepartment(
        departmentFilterArg,
      );
  final allowed = ordered.toSet();
  final counts = <String, int>{};
  for (final t in assignedTasks) {
    final c = FunHelper.canonicalStoredStatus(t.status);
    if (!allowed.contains(c)) continue;
    counts[c] = (counts[c] ?? 0) + 1;
  }
  final out = <MapEntry<String, int>>[];
  for (final s in ordered) {
    final n = counts[s] ?? 0;
    if (n > 0) out.add(MapEntry(s, n));
  }
  return out;
}

Widget _employeeLibraryNavButton({double width = 160}) {
  return Obx(() {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!LibraryPermissions.canAccessLibrary(emp)) {
      return const SizedBox.shrink();
    }
    return MainButton(
      width: width,
      height: 45,
      borderSize: 35,
      fontColor: Colors.white,
      backgroundColor: AppColors.primary,
      widget: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'library.sidebar'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.folder_copy_outlined, color: Colors.white),
        ],
      ),
      onPressed: () => Get.toNamed('/library'),
    );
  });
}

Widget _buildAssignedTasksSectionTitle(BuildContext context) {
  return Text(
    'employee.dashboard.tasks_assigned_to_you'.tr,
    style: TextStyle(
      color: context.appTheme.secondaryText,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    ),
  );
}

Widget _buildAssignedTasksSectionActions(HomeController controller) {
  final emp = controller.currentEmployee.value;
  final showContent = emp != null &&
      (emp.hasDepartment(StorageKeys.departmentPromotion) ||
          emp.hasDepartment(StorageKeys.departmentPublishing));

  return Obx(() {
    final showLibrary = LibraryPermissions.canAccessLibrary(
      controller.effectiveEmployee,
    );
    if (!showContent && !showLibrary) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          if (showContent)
            MainButton(
              width: 180,
              height: 45,
              borderSize: 35,
              fontColor: Colors.white,
              backgroundColor: AppColors.primary,
              widget: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'managecontent'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.navigate_next, color: Colors.white),
                ],
              ),
              onPressed: () => Get.toNamed('/employeeContent'),
            ),
          _employeeLibraryNavButton(width: 160),
        ],
      ),
    );
  });
}

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final c = Get.find<HomeController>();
      await c.restoreEmployeeDashboardTaskFiltersFromPrefs();
      c.update();
    });
  }

  @override
  Widget build(BuildContext context) => const _EmployeeDashboardBody();
}

class _EmployeeDashboardBody extends StatelessWidget {
  const _EmployeeDashboardBody();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        final isMobile = Responsive.isMobile(context);
        return Scaffold(
          backgroundColor: context.appTheme.pageBackground,
          appBar:
              isMobile ? EmployeeMobileAppBar(controller: controller) : null,
          body: Responsive(
            mobile: _buildMobile(context),
            desktop: _buildDesktop(context),
          ),
        );
      },
    );
  }

  Widget _buildDesktop(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Obx(
          () => Row(
            children: [
              SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(10),
                  width: Get.width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PreferredSize(
                        preferredSize: Size(Get.width, 60),
                        child: Obx(
                          () => HeaderWidget(
                            employee: true,
                            name: controller.currentEmployee.value?.name ?? '',
                            role: controller.currentEmployee.value?.role ?? '',
                            departments:
                                controller.currentEmployee.value?.departments ??
                                const [],
                            avatarUrl:
                                controller.currentEmployee.value?.image ??
                                kDefaultAvatarUrl,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildAssignedTasksSectionActions(controller),
                      ),
                      _employeeDashboardAttendanceSection(context, controller),

                      _buildAssignedTasksSectionTitle(context),
                      const SizedBox(height: 10),
                      _buildAssignedTaskPerStatusStats(controller),

                      SizedBox(height: 15),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: TaskListFiltersBar(
                          taskType: taskTypeCodeForNormalizedDepartment(
                                StorageKeys.normalizeDepartment(
                                  controller.employeeDashboardDepartmentFilterArg ??
                                      '',
                                ),
                              ) ??
                              '1',
                          employeeDashboard: true,
                          searchHint: 'employee.search_tasks_hint'.tr,
                        ),
                      ),
                      SizedBox(height: 15),
                      Text(
                        'tasks.summary.sent_tasks'.tr,
                        style: TextStyle(
                          color: context.appTheme.secondaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TasksGridPage(),
                      AppVersionLabel(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        textStyle: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: context.appTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobile(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Obx(
          () => Row(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    controller.fetchTasks();
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      padding: EdgeInsets.all(10),
                      width: Get.width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildAssignedTasksSectionActions(controller),
                          ),
                          _employeeDashboardAttendanceSection(context, controller),

                          _buildAssignedTasksSectionTitle(context),
                          const SizedBox(height: 10),
                          _buildAssignedTaskPerStatusStats(controller),

                          SizedBox(height: 15),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: TaskListFiltersBar(
                              taskType: taskTypeCodeForNormalizedDepartment(
                                    StorageKeys.normalizeDepartment(
                                      controller.employeeDashboardDepartmentFilterArg ??
                                          '',
                                    ),
                                  ) ??
                                  '1',
                              employeeDashboard: true,
                              searchHint: 'employee.search_tasks_hint'.tr,
                            ),
                          ),
                          SizedBox(height: 15),
                          Text(
                            'tasks.summary.sent_tasks'.tr,
                            style: TextStyle(
                              color: context.appTheme.secondaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(
                            width: Get.width,
                            // height: 620,
                            child: TasksListPage(),
                          ),
                          AppVersionLabel(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            textStyle: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: context.appTheme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// One stat card per visible canonical task status (no merged buckets).
  Widget _buildAssignedTaskPerStatusStats(HomeController controller) {
    return Obx(() {
      controller.activeDepartmentFilter.value;
      final empId = controller.currentEmployee.value?.id?.trim();
      final tasks =
          empId == null || empId.isEmpty
              ? <TaskModel>[]
              : controller.tasksSearched
                  .where((a) => a.assignedTo.trim() == empId)
                  .toList();
      final entries = employeeDashboardAssignedTaskStatEntriesOrdered(
        assignedTasks: tasks,
        departmentFilterArg: controller.employeeDashboardDepartmentFilterArg,
      );
      if (entries.isEmpty) {
        return const SizedBox.shrink();
      }
      final ctx = Get.context;
      if (ctx == null) {
        return const SizedBox.shrink();
      }
      final isDesktop = Responsive.isDesktop(ctx);
      final cardWidth = (isDesktop ? 120.0 : 100.0).clamp(72.0, 140.0);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in entries)
              _buildStatBox(
                ctx,
                e.value.toString(),
                FunHelper.trStored(
                  e.key,
                  kind: StoredValueKind.taskStatus,
                ),
                TaskStatusVisuals.iconTintFor(e.key),
                width: cardWidth,
              ),
          ],
        ),
      );
    });
  }

  Widget _buildStatBox(
    BuildContext context,
    String value,
    String label,
    Color color, {
    double? width,
  }) {
    final theme = context.appTheme;
    final isDesktop = Responsive.isDesktop(context);
    final boxWidth =
        width ?? (isDesktop ? Get.width / 4 - 78 : Get.width / 4 - 30);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      width: boxWidth,
      height: 150,
      margin: EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.secondaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TasksGridPage extends StatelessWidget {
  static const _crossAxisCount = 3;
  static const _spacing = 12.0;
  static const _aspectRatio = 1.35;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Obx(() {
          final tasks =
              controller.tasksSearched
                  .where(
                    (a) => a.assignedTo == controller.currentEmployee.value?.id,
                  )
                  .toList();
          if (tasks.isEmpty) {
            return const SizedBox.shrink();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth =
                  (constraints.maxWidth - _spacing * (_crossAxisCount - 1)) /
                  _crossAxisCount;
              final cellHeight = cellWidth / _aspectRatio;
              final rows = <Widget>[];

              for (var i = 0; i < tasks.length; i += _crossAxisCount) {
                final rowTasks = tasks.skip(i).take(_crossAxisCount).toList();
                rows.add(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var col = 0; col < _crossAxisCount; col++) ...[
                        if (col > 0) const SizedBox(width: _spacing),
                        SizedBox(
                          width: cellWidth,
                          height: cellHeight,
                          child:
                              col < rowTasks.length
                                  ? EmployeeTaskCard(
                                    key: ValueKey(
                                      rowTasks[col].id ?? 'task-${i + col}',
                                    ),
                                    task: rowTasks[col],
                                    onTap:
                                        () => _openEmployeeDashboardTaskDetails(
                                          context,
                                          rowTasks[col],
                                        ),
                                  )
                                  : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                );
                if (i + _crossAxisCount < tasks.length) {
                  rows.add(const SizedBox(height: _spacing));
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              );
            },
          );
        });
      },
    );
  }
}

class TasksListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: GetBuilder<HomeController>(
        builder: (controller) {
          return Obx(() {
            final tasks =
                controller.tasksSearched
                    .where(
                      (a) =>
                          a.assignedTo == controller.currentEmployee.value?.id,
                    )
                    .toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < tasks.length; index++)
                  EmployeeTaskCard(
                    key: ValueKey(tasks[index].id ?? 'task-$index'),
                    task: tasks[index],
                    onTap:
                        () => _openEmployeeDashboardTaskDetails(
                          context,
                          tasks[index],
                        ),
                  ),
              ],
            );
          });
        },
      ),
    );
  }
}
