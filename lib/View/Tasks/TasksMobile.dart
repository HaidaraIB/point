import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/home_task_filters.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Tasks/DetailsDialogs/DContentWriteDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DDesignDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DMontageDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPhotographyDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DAdministrativeDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';
import 'package:point/View/Tasks/Dialogs/ContentWriteDialog.dart';
import 'package:point/View/Tasks/Dialogs/DesignDialog.dart';
import 'package:point/View/Tasks/Dialogs/MontageDialog.dart';
import 'package:point/View/Tasks/Dialogs/PhotographyDialog.dart';
import 'package:point/View/Tasks/Dialogs/AdministrativeDialog.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';
import 'package:point/View/Tasks/ProgrammingUpdates/programming_department_tabs.dart';
import 'package:point/View/Tasks/ProgrammingUpdates/programming_suggestions_panel.dart';
import 'package:point/View/Tasks/Dialogs/PromotionDialog.dart';
import 'package:point/View/Tasks/Dialogs/PublishDialog.dart';
import 'package:point/View/Shared/task_status_visuals.dart';
import 'package:point/View/Tasks/TaskCard.dart';
import 'package:point/View/Shared/task_list_filters_bar.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Mobile-only tasks screen with a single scroll so the last item is fully visible.
class TasksMobile extends StatelessWidget {
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

  const TasksMobile({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    if (selectedIndex == 6) {
      return _ProgrammingTasksMobileLayout(selectedIndex: selectedIndex);
    }
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Obx(() {
          final List<TaskModel> tasks = controller.tasksSearched
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
                      _buildHeader(context, controller),
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
              _tasksSliverList(context, tasks),
              SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
            ],
          );
        });
      },
    );
  }

  /// Programming department: tabs for tasks / pending / converted updates.
  Widget buildProgrammingShell(
    BuildContext context,
    HomeController controller,
    List<TaskModel> tasks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(context, controller),
            ],
          ),
        ),
        Expanded(
          child: ProgrammingDepartmentTabs(
            initialTabIndex: programmingUpdatesTabFromRoute(),
            tasksTab: buildProgrammingTasksTab(context, controller, tasks),
          ),
        ),
      ],
    );
  }

  Widget buildProgrammingTasksTab(
    BuildContext context,
    HomeController controller,
    List<TaskModel> tasks,
  ) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 16.0;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const ProgrammingSuggestionsCard(),
                const SizedBox(height: 20),
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
        _tasksSliverList(context, tasks),
        SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
      ],
    );
  }

  Widget _tasksSliverList(BuildContext context, List<TaskModel> tasks) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final cardHeight = MediaQuery.of(context).size.width / 1.35 + 24;
        return SizedBox(
          height: cardHeight.clamp(280.0, 400.0),
          child: TaskCard(
            task: tasks[index],
            onTap: () => _openTaskDetails(context, selectedIndex, tasks[index]),
          ),
        );
      }, childCount: tasks.length),
    );
  }

  Widget _buildHeader(BuildContext context, HomeController controller) {
    final safeIndex = selectedIndex < 0
        ? 0
        : (selectedIndex >= _departmentRouteSlugs.length
              ? _departmentRouteSlugs.length - 1
              : selectedIndex);
    final labelKey = StorageKeys.semanticDepartmentLabelKey(
      _departmentRouteSlugs[safeIndex],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              labelKey.tr,
              style: TextStyle(
                color: resolveAppTheme().secondaryText,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: MainButton(
              width: 178,
              height: 45,
              borderSize: 35,
              fontColor: Colors.white,
              backgroundColor: AppColors.primary,
              widget: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'addnewtask'.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.white,
                  ),
                ],
              ),
              onPressed: () {
                controller.uploadedFilesPaths.clear();
                switch (selectedIndex) {
                  case 0:
                    showPromotionDialog(context);
                    break;
                  case 1:
                    designDialog(context);
                    break;
                  case 2:
                    photographyDialog(context);
                    break;
                  case 3:
                    contentWriteDialog(context);
                    break;
                  case 4:
                    montageDialog(context);
                    break;
                  case 5:
                    publishDialog(context);
                    break;
                  case 6:
                    programmingDialog(context);
                    break;
                  case 7:
                    administrationDialog(context);
                    break;
                  default:
                }
              },
            ),
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
    final perStatus = taskManagementOngoingStatEntriesOrdered(
      tasks: tasks,
      taskType: selectedIndex.toString(),
    );
    final statRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatBox(
          tasks.length.toString(),
          'employee.dashboard.total_tasks'.tr,
          Colors.blue,
          width: boxWidth,
        ),
        for (final e in perStatus)
          _buildStatBox(
            e.value.toString(),
            FunHelper.trStored(e.key, kind: StoredValueKind.taskStatus),
            TaskStatusVisuals.iconTintFor(e.key),
            width: boxWidth,
          ),
      ],
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: statRow,
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
            height: 52,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: resolveAppTheme().secondaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
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
      child: TaskListFiltersBar(taskType: selectedIndex.toString()),
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

class _ProgrammingTasksMobileLayout extends StatelessWidget {
  final int selectedIndex;

  const _ProgrammingTasksMobileLayout({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final view = TasksMobile(selectedIndex: selectedIndex);
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Obx(() {
          final tasks = controller.tasksSearched
              .where((a) => a.type == selectedIndex.toString())
              .toList();
          return view.buildProgrammingShell(context, controller, tasks);
        });
      },
    );
  }
}
