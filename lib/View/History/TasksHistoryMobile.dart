import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/app_filter_dropdown.dart';
import 'package:point/View/Tasks/DetailsDialogs/DContentWriteDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DDesignDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DMontageDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPhotographyDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DAdministrativeDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';
import 'package:point/View/Tasks/TaskCard.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Mobile-only task history screen: same layout as TasksMobile but uses
/// tasksHistory, filterTasksHistory(), and statusListEnded for filters.
class TasksHistoryMobile extends StatelessWidget {
  static const List<String> _departmentRouteSlugs = <String>[
    StorageKeys.departmentPromotion,
    StorageKeys.departmentDesign,
    StorageKeys.departmentPhotography,
    StorageKeys.departmentContentWriting,
    StorageKeys.departmentMontage,
    StorageKeys.departmentPublishing,
    StorageKeys.departmentProgramming,
    StorageKeys.departmentAdministration,
  ];

  final int selectedIndex;
  final ValueChanged<int> onDepartmentChanged;

  const TasksHistoryMobile({
    super.key,
    required this.selectedIndex,
    required this.onDepartmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Obx(() {
          final List<TaskModel> tasks =
              controller.tasksHistory
                  .where((a) => a.type == selectedIndex.toString())
                  .toList();
          final bottomPadding = MediaQuery.of(context).padding.bottom + 32.0;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(context),
                      const SizedBox(height: 10),
                      _buildStats(context, controller, tasks),
                      const SizedBox(height: 15),
                      _buildFilters(context, controller),
                      const SizedBox(height: 15),
                      Text(
                        'tasks.summary.sent_tasks'.tr,
                        style: TextStyle(
                          color: resolveAppTheme().secondaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final cardHeight =
                      MediaQuery.of(context).size.width / 1.35 + 24;
                  return SizedBox(
                    height: cardHeight.clamp(280.0, 400.0),
                    child: TaskCard(
                      task: tasks[index],
                      onTap:
                          () => _openTaskDetails(
                            context,
                            selectedIndex,
                            tasks[index],
                          ),
                    ),
                  );
                }, childCount: tasks.length),
              ),
              SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
            ],
          );
        });
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final safeIndex = selectedIndex < 0
        ? 0
        : (selectedIndex >= _departmentRouteSlugs.length
            ? _departmentRouteSlugs.length - 1
            : selectedIndex);
    return Row(
      children: [
        Text(
          StorageKeys.semanticDepartmentLabelKey(
            _departmentRouteSlugs[safeIndex],
          ).tr,
          style: TextStyle(
            color: resolveAppTheme().secondaryText,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Expanded(
          child: DynamicDropdown<String>(
            items:
                StorageKeys.departments
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          StorageKeys.semanticDepartmentLabelKey(v).tr,
                        ),
                      ),
                    )
                    .toList(),
            value: StorageKeys.departments[safeIndex],
            label: 'history.select_department'.tr,
            borderRadius: 5,
            height: 42,
            onChanged: (value) {
              if (value != null) {
                final idx = StorageKeys.departments.indexOf(value);
                if (idx >= 0) onDepartmentChanged(idx);
              }
            },
            validator: (v) => v == null ? ' ' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStats(
    BuildContext context,
    HomeController controller,
    List<TaskModel> tasks,
  ) {
    final boxWidth = (Get.width / 5 - 30).clamp(88.0, double.infinity);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatBox(
            tasks.length.toString(),
            'employee.dashboard.total_tasks'.tr,
            Colors.blue,
            width: boxWidth,
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(
    String value,
    String label,
    Color color, {
    double? width,
  }) {
    final boxWidth = width ?? (Get.width / 5 - 30);
    return Container(
      decoration: BoxDecoration(
              color: resolveAppTheme().cardSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      width: boxWidth,
      height: 150,
      margin: const EdgeInsets.all(10),
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
          const SizedBox(height: 25),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: resolveAppTheme().secondaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, HomeController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileFilterSearchRow(
            searchBar: MobileFilterSearchBar(
              controller: controller.searchController,
              hintText: 'tasks.search_hint_extended'.tr,
              borderRadius: 5,
              onChanged: controller.filterTasksHistory,
            ),
            onClearFilters: () {
              controller.searchController.clear();
              controller.selectedPriority.value = '';
              controller.selectedStatus.value = '';
              controller.selectedExecutor.value = '';
              controller.filterTasksHistory();
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDropdown<String>(
                width: 150,
                hint: 'tasks.filter_priority'.tr,
                value:
                    controller.selectedPriority.value.isEmpty
                        ? null
                        : controller.selectedPriority.value,
                items:
                    StorageKeys.priority
                        .map(
                          (e) => DropdownMenuItem(value: e, child: Text(e.tr)),
                        )
                        .toList(),
                onChanged: (value) {
                  controller.selectedPriority.value = value ?? '';
                  controller.filterTasksHistory();
                },
              ),
              const SizedBox(width: 10),
              _buildStatusEndedDropdown(controller, selectedIndex),
              const SizedBox(width: 10),
              _buildDropdown<String>(
                width: 150,
                hint: 'tasks.filter_assignee'.tr,
                value:
                    controller.selectedExecutor.value.isEmpty
                        ? null
                        : controller.selectedExecutor.value,
                items:
                    controller.employees
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id ?? e.name ?? '',
                            child: Text(
                              (e.name ?? '').split(' ').take(2).join(' '),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  controller.selectedExecutor.value = value ?? '';
                  controller.filterTasksHistory();
                },
              ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required double width,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return AppFilterDropdown<T>(
      width: width,
      hint: hint,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }

  /// Status dropdown for history: ended statuses (plus promotion finished).
  Widget _buildStatusEndedDropdown(
    HomeController controller,
    int tabIndex,
  ) {
    final endedItems =
        StorageKeys.endedStatusFilterDropdownValues(tabIndex.toString());
    return AppFilterDropdown<String>(
      hint: 'tasks.filter_status'.tr,
      width: 170,
      value:
          controller.selectedStatus.value.isEmpty ||
                  !endedItems.contains(controller.selectedStatus.value)
              ? null
              : controller.selectedStatus.value,
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(
            'filter_status_ended'.tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        ...endedItems.map(
          (e) => DropdownMenuItem(
            value: e,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(e.tr),
            ),
          ),
        ),
      ],
      onChanged: (value) {
        controller.selectedStatus.value = value ?? '';
        controller.filterTasksHistory();
      },
    );
  }

  void _openTaskDetails(
    BuildContext context,
    int selectedIndex,
    TaskModel task,
  ) {
    switch (selectedIndex) {
      case 0:
        showCampaignDetailsDialog(context, task: task);
        break;
      case 1:
        showDesignDetailsDialog(context, task: task);
        break;
      case 2:
        showDPhotographyDialog(context, task: task);
        break;
      case 3:
        showContentWriteDialog(context, task: task);
        break;
      case 4:
        showMontageDialog(context, task: task);
        break;
      case 5:
        showPublishDialog(context, task: task);
        break;
      case 6:
        showProgrammingDialog(context, task: task);
        break;
      case 7:
        showAdministrativeTaskDetailsDialog(context, task: task);
        break;
      default:
    }
  }
}
