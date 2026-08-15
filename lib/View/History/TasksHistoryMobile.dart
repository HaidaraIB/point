import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/task_history_filters_bar.dart';
import 'package:point/View/Tasks/TaskCard.dart';
import 'package:point/View/Tasks/open_task_details.dart';
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
          final List<TaskModel> tasks = controller.tasksHistory
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
                      onTap: () => openTaskDetails(context, tasks[index]),
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
            items: StorageKeys.departments
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(StorageKeys.semanticDepartmentLabelKey(v).tr),
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
      child: TaskHistoryFiltersBar(taskType: selectedIndex.toString()),
    );
  }
}
