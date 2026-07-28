import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Shared/app_filter_dropdown.dart';
import 'package:point/View/Shared/app_multi_filter.dart';

/// Publish-style multi-select filters for ongoing Tasks / Employee Dashboard.
class TaskListFiltersBar extends StatefulWidget {
  const TaskListFiltersBar({
    super.key,
    required this.taskType,
    this.employeeDashboard = false,
    this.searchHint,
  });

  /// Department type code (`selectedIndex.toString()`), or employee type code.
  final String taskType;
  final bool employeeDashboard;
  final String? searchHint;

  @override
  State<TaskListFiltersBar> createState() => _TaskListFiltersBarState();
}

class _TaskListFiltersBarState extends State<TaskListFiltersBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !Get.isRegistered<HomeController>()) return;
      final c = Get.find<HomeController>();
      unawaited(
        widget.employeeDashboard
            ? c.restoreEmployeeDashboardTaskFiltersFromPrefs()
            : c.restoreTaskFiltersFromPrefs(taskType: widget.taskType),
      );
    });
  }

  @override
  void didUpdateWidget(covariant TaskListFiltersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskType != widget.taskType && !widget.employeeDashboard) {
      Get.find<HomeController>().syncTaskFiltersForType(widget.taskType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    return Obx(() {
      // Touch observables so GetX always registers a dependency.
      final revision = controller.taskFiltersRevision.value;
      final statusCount = controller.selectedTaskStatuses.length;
      final priorityCount = controller.selectedTaskPriorities.length;
      final executorCount = controller.selectedTaskExecutors.length;
      final employeeCount = controller.employees.length;
      final _ = revision + statusCount + priorityCount + executorCount + employeeCount;

      final statuses = controller.selectedTaskStatuses.toList();
      final priorities = controller.selectedTaskPriorities.toList();
      final executors = controller.selectedTaskExecutors.toList();

      final statusItems = widget.employeeDashboard
          ? StorageKeys
              .employeeDashboardTaskStatusFilterDropdownValuesForDepartment(
              controller.employeeDashboardDepartmentFilterArg,
            )
          : StorageKeys.ongoingStatusFilterDropdownValues(widget.taskType);

      final activeTags = <Widget>[];
      appendAppActiveFilterTags(
        out: activeTags,
        dimension: 'tasks.filter_status'.tr,
        selected: statuses,
        itemLabel: (s) => s.tr,
        onRemove: (value) {
          final next = List<String>.from(statuses)..remove(value);
          controller.setTaskFilterList(controller.selectedTaskStatuses, next);
        },
      );
      appendAppActiveFilterTags(
        out: activeTags,
        dimension: 'tasks.filter_priority'.tr,
        selected: priorities,
        itemLabel: (s) => s.tr,
        onRemove: (value) {
          final next = List<String>.from(priorities)..remove(value);
          controller.setTaskFilterList(
            controller.selectedTaskPriorities,
            next,
          );
        },
      );
      appendAppActiveFilterTags(
        out: activeTags,
        dimension: 'tasks.filter_assignee'.tr,
        selected: executors,
        itemLabel: controller.taskExecutorFilterLabel,
        onRemove: (value) {
          final next = List<String>.from(executors)..remove(value);
          controller.setTaskFilterList(
            controller.selectedTaskExecutors,
            next,
          );
        },
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileFilterSearchRow(
            searchBar: MobileFilterSearchBar(
              controller: controller.searchController,
              hintText: widget.searchHint ?? 'tasks.search_hint_extended'.tr,
              onChanged: () {
                controller.filterTasks();
                controller.schedulePersistTaskFilters();
              },
              onSubmitted: (_) {
                controller.filterTasks();
                controller.schedulePersistTaskFilters();
              },
            ),
            onClearFilters: () {
              unawaited(
                controller.clearTaskFilters(taskType: widget.taskType),
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppMultiFilterTrigger(
                hint: 'tasks.filter_status'.tr,
                items: statusItems,
                selected: statuses,
                itemLabel: (s) => s.tr,
                onChanged: (v) => controller.setTaskFilterList(
                  controller.selectedTaskStatuses,
                  v,
                ),
              ),
              AppMultiFilterTrigger(
                hint: 'tasks.filter_priority'.tr,
                items: StorageKeys.priority,
                selected: priorities,
                itemLabel: (s) => s.tr,
                onChanged: (v) => controller.setTaskFilterList(
                  controller.selectedTaskPriorities,
                  v,
                ),
              ),
              AppMultiFilterTrigger(
                hint: 'tasks.filter_assignee'.tr,
                items: controller.taskExecutorFilterOptions(),
                selected: executors,
                itemLabel: controller.taskExecutorFilterLabel,
                onChanged: (v) => controller.setTaskFilterList(
                  controller.selectedTaskExecutors,
                  v,
                ),
              ),
            ],
          ),
          if (activeTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: activeTags),
          ],
        ],
      );
    });
  }
}
