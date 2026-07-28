import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Shared/app_filter_dropdown.dart';
import 'package:point/View/Shared/app_multi_filter.dart';

/// Publish-style multi-select filters for Task History (ended tasks).
class TaskHistoryFiltersBar extends StatefulWidget {
  const TaskHistoryFiltersBar({
    super.key,
    required this.taskType,
    this.searchHint,
  });

  final String taskType;
  final String? searchHint;

  @override
  State<TaskHistoryFiltersBar> createState() => _TaskHistoryFiltersBarState();
}

class _TaskHistoryFiltersBarState extends State<TaskHistoryFiltersBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !Get.isRegistered<HomeController>()) return;
      unawaited(Get.find<HomeController>().restoreHistoryFiltersFromPrefs());
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    return Obx(() {
      // Touch observables so GetX always registers a dependency.
      final revision = controller.historyFiltersRevision.value;
      final statusCount = controller.selectedHistoryStatuses.length;
      final priorityCount = controller.selectedHistoryPriorities.length;
      final executorCount = controller.selectedHistoryExecutors.length;
      final employeeCount = controller.employees.length;
      final _ = revision + statusCount + priorityCount + executorCount + employeeCount;

      final statuses = controller.selectedHistoryStatuses.toList();
      final priorities = controller.selectedHistoryPriorities.toList();
      final executors = controller.selectedHistoryExecutors.toList();
      final statusItems =
          StorageKeys.endedStatusFilterDropdownValues(widget.taskType);

      final activeTags = <Widget>[];
      appendAppActiveFilterTags(
        out: activeTags,
        dimension: 'tasks.filter_status'.tr,
        selected: statuses,
        itemLabel: (s) => s.tr,
        onRemove: (value) {
          final next = List<String>.from(statuses)..remove(value);
          controller.setHistoryFilterList(
            controller.selectedHistoryStatuses,
            next,
          );
        },
      );
      appendAppActiveFilterTags(
        out: activeTags,
        dimension: 'tasks.filter_priority'.tr,
        selected: priorities,
        itemLabel: (s) => s.tr,
        onRemove: (value) {
          final next = List<String>.from(priorities)..remove(value);
          controller.setHistoryFilterList(
            controller.selectedHistoryPriorities,
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
          controller.setHistoryFilterList(
            controller.selectedHistoryExecutors,
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
                controller.filterTasksHistory();
                controller.schedulePersistHistoryFilters();
              },
              onSubmitted: (_) {
                controller.filterTasksHistory();
                controller.schedulePersistHistoryFilters();
              },
            ),
            onClearFilters: () {
              unawaited(controller.clearHistoryFilters());
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
                onChanged: (v) => controller.setHistoryFilterList(
                  controller.selectedHistoryStatuses,
                  v,
                ),
              ),
              AppMultiFilterTrigger(
                hint: 'tasks.filter_priority'.tr,
                items: StorageKeys.priority,
                selected: priorities,
                itemLabel: (s) => s.tr,
                onChanged: (v) => controller.setHistoryFilterList(
                  controller.selectedHistoryPriorities,
                  v,
                ),
              ),
              AppMultiFilterTrigger(
                hint: 'tasks.filter_assignee'.tr,
                items: controller.taskExecutorFilterOptions(),
                selected: executors,
                itemLabel: controller.taskExecutorFilterLabel,
                onChanged: (v) => controller.setHistoryFilterList(
                  controller.selectedHistoryExecutors,
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
