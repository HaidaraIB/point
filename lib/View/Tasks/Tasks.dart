import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/home_task_filters.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/app_filter_dropdown.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/task_status_visuals.dart';
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
import 'package:point/View/Tasks/ProgrammingUpdates/add_programming_update_dialog.dart';
import 'package:point/View/Tasks/ProgrammingUpdates/programming_department_tabs.dart';
import 'package:point/View/Tasks/Dialogs/PromotionDialog.dart';
import 'package:point/View/Tasks/Dialogs/PublishDialog.dart';
import 'package:point/View/Tasks/TaskCard.dart';
import 'package:point/View/Tasks/TasksMobile.dart';
import 'package:point/Utils/app_theme_extension.dart';

class Tasks extends StatelessWidget {
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

  int _resolveSelectedIndex() {
    final params = Get.parameters;

    final departmentSlug = params['department']?.toLowerCase();
    if (departmentSlug != null && departmentSlug.isNotEmpty) {
      final slugIndex = _departmentRouteSlugs.indexOf(departmentSlug);
      if (slugIndex >= 0) return slugIndex;
    }

    final id = int.tryParse(params['id'] ?? '');
    if (id != null && id >= 0 && id < _departmentRouteSlugs.length) {
      return id;
    }

    return 0;
  }

  String _departmentTranslationKey(int selectedIndex) =>
      StorageKeys.semanticDepartmentLabelKey(
        _departmentRouteSlugs[selectedIndex],
      );

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _resolveSelectedIndex();
    return ResponsiveScaffold(
      selectedTab: 40,
      subSelected: selectedIndex,
      body: GetBuilder<HomeController>(
        builder: (controller) {
          return Responsive(
            mobile: TasksMobile(selectedIndex: selectedIndex),
            desktop: GetBuilder<HomeController>(
              builder: (controller) {
                return Obx(
                  () => Row(
                    children: [
                      SingleChildScrollView(
                        child: Container(
                          padding: EdgeInsets.all(10),
                          width:
                              Responsive.isDesktop(context)
                                  ? Get.width - 270
                                  : Get.width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 20),

                              Row(
                                children: [
                                  Text(
                                    _departmentTranslationKey(selectedIndex).tr,
                                    style: TextStyle(
                                      color: resolveAppTheme().secondaryText,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(),
                                  if (selectedIndex == 6) ...[
                                    MainButton(
                                      width: 150,
                                      height: 45,
                                      borderSize: 35,
                                      fontColor: Colors.white,
                                      backgroundColor: AppColors.primary,
                                      widget: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'programming.updates.add'.tr,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.update,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                      onPressed: () {
                                        controller.uploadedFilesPaths.clear();
                                        showAddProgrammingUpdateDialog(context);
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  MainButton(
                                    width: 178,
                                    height: 45,
                                    borderSize: 35,
                                    fontColor: Colors.white,
                                    backgroundColor: AppColors.primary,
                                    widget: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'addnewtask'.tr,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Icon(
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
                                ],
                              ),
                              SizedBox(height: 10),
                              if (selectedIndex == 6)
                                SizedBox(
                                  height: MediaQuery.of(context).size.height -
                                      180,
                                  child: ProgrammingDepartmentTabs(
                                    initialTabIndex:
                                        programmingUpdatesTabFromRoute(),
                                    tasksTab: SingleChildScrollView(
                                      child: _buildProgrammingTasksDesktopBody(
                                        context,
                                        controller,
                                        selectedIndex,
                                      ),
                                    ),
                                  ),
                                )
                              else ...[
                              Obx(() {
                                final tasks =
                                    controller.tasksSearched
                                        .where(
                                          (a) =>
                                              a.type ==
                                              selectedIndex.toString(),
                                        )
                                        .toList();
                                final isDesktop = Responsive.isDesktop(
                                  Get.context!,
                                );
                                final boxWidth =
                                    isDesktop
                                        ? null
                                        : (Get.width / 5 - 30).clamp(
                                          88.0,
                                          double.infinity,
                                        );
                                final perStatus =
                                    taskManagementOngoingStatEntriesOrdered(
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
                                        FunHelper.trStored(
                                          e.key,
                                          kind: StoredValueKind.taskStatus,
                                        ),
                                        TaskStatusVisuals.iconTintFor(e.key),
                                        width: boxWidth,
                                      ),
                                  ],
                                );
                                // تمرير أفقي على كل الأحجام: صناديق الإحصاءات كثيرة وقد تتجاوز عرض الشاشة.
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: statRow,
                                );
                              }),

                              SizedBox(height: 15),
                              _buildDesktopFilters(
                                context,
                                controller,
                                selectedIndex,
                              ),
                              SizedBox(height: 15),
                              Text(
                                'tasks.summary.sent_tasks'.tr,
                                style: TextStyle(
                                  color: resolveAppTheme().secondaryText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(
                                width:
                                    Responsive.isDesktop(context)
                                        ? Get.width - 300
                                        : Get.width,
                                height: 620,
                                child: TasksGridPage(
                                  selectedIndex: selectedIndex,
                                ),
                              ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgrammingTasksDesktopBody(
    BuildContext context,
    HomeController controller,
    int selectedIndex,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(() {
          final tasks = controller.tasksSearched
              .where((a) => a.type == selectedIndex.toString())
              .toList();
          final isDesktop = Responsive.isDesktop(Get.context!);
          final boxWidth = isDesktop
              ? null
              : (Get.width / 5 - 30).clamp(88.0, double.infinity);
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
                  FunHelper.trStored(
                    e.key,
                    kind: StoredValueKind.taskStatus,
                  ),
                  TaskStatusVisuals.iconTintFor(e.key),
                  width: boxWidth,
                ),
            ],
          );
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: statRow,
          );
        }),
        const SizedBox(height: 15),
        _buildDesktopFilters(context, controller, selectedIndex),
        const SizedBox(height: 15),
        Text(
          'tasks.summary.sent_tasks'.tr,
          style: TextStyle(
            color: resolveAppTheme().secondaryText,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
          width: Responsive.isDesktop(context) ? Get.width - 300 : Get.width,
          height: 620,
          child: TasksGridPage(selectedIndex: selectedIndex),
        ),
      ],
    );
  }

  Widget _buildDesktopFilters(
    BuildContext context,
    HomeController controller,
    int selectedIndex,
  ) {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: (Get.width * 0.7 / 3) - 25,
                child: InputText(
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    color: context.appTheme.mutedText,
                  ),
                  hintText: 'tasks.search_hint_extended'.tr,
                  height: 42,
                  controller: controller.searchController,
                  onchange: (value) {
                    controller.filterTasks();
                    return null;
                  },
                  borderRadius: 5,
                ),
              ),
              const SizedBox(width: 10),
              FilterResetButton(
                onPressed: () {
                  controller.searchController.clear();
                  controller.selectedPriority.value = '';
                  controller.selectedStatus.value = '';
                  controller.selectedExecutor.value = '';
                  controller.filterTasks();
                },
              ),
              const SizedBox(width: 24),
              _desktopPriorityDropdown(controller),
              const SizedBox(width: 10),
              _desktopStatusDropdown(controller, selectedIndex),
              const SizedBox(width: 10),
              _desktopExecutorDropdown(controller),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopPriorityDropdown(HomeController controller) {
    return AppFilterDropdown<String>(
      hint: 'tasks.filter_priority'.tr,
      value: controller.selectedPriority.value.isEmpty
          ? null
          : controller.selectedPriority.value,
      items: StorageKeys.priority
          .map((e) => DropdownMenuItem(value: e, child: Text(e.tr)))
          .toList(),
      onChanged: (value) {
        controller.selectedPriority.value = value ?? '';
        controller.filterTasks();
      },
    );
  }

  Widget _desktopStatusDropdown(
    HomeController controller,
    int selectedIndex,
  ) {
    final ongoingStatusItems = StorageKeys.ongoingStatusFilterDropdownValues(
      selectedIndex.toString(),
    );
    return AppFilterDropdown<String>(
      hint: 'tasks.filter_status'.tr,
      width: 170,
      value:
          controller.selectedStatus.value.isEmpty ||
                  !ongoingStatusItems.contains(controller.selectedStatus.value)
              ? null
              : controller.selectedStatus.value,
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(
            'filter_status_ongoing'.tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        ...ongoingStatusItems.map(
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
        controller.filterTasks();
      },
    );
  }

  Widget _desktopExecutorDropdown(HomeController controller) {
    return AppFilterDropdown<String>(
      hint: 'tasks.filter_assignee'.tr,
      value: controller.selectedExecutor.value.isEmpty
          ? null
          : controller.selectedExecutor.value,
      items: controller.employees
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
        controller.filterTasks();
      },
    );
  }

  Widget _buildStatBox(
    String value,
    String label,
    Color color, {
    double? width,
  }) {
    final isDesktop = Responsive.isDesktop(Get.context!);
    final boxWidth =
        width ?? (isDesktop ? Get.width / 5 - 78 : Get.width / 5 - 30);
    return Container(
      decoration: BoxDecoration(
              color: resolveAppTheme().cardSurface,
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
          SizedBox(height: 25),
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
}

class TasksGridPage extends StatelessWidget {
  final int selectedIndex;
  TasksGridPage({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: GetBuilder<HomeController>(
        builder: (controller) {
          return Obx(() {
            final tasks =
                controller.tasksSearched
                    .where((a) => a.type == selectedIndex.toString())
                    .toList();
            return GridView.builder(
              itemCount: tasks.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Responsive.isDesktop(Get.context!) ? 3 : 1,

                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemBuilder: (context, index) {
                return TaskCard(
                  task: tasks[index],
                  onTap: () {
                    switch (selectedIndex) {
                      case 0:
                        showCampaignDetailsDialog(context, task: tasks[index]);
                        break;
                      case 1:
                        showDesignDetailsDialog(context, task: tasks[index]);
                        break;
                      case 2:
                        showDPhotographyDialog(context, task: tasks[index]);
                        break;
                      case 3:
                        showContentWriteDialog(context, task: tasks[index]);
                        break;
                      case 4:
                        showMontageDialog(context, task: tasks[index]);
                        break;
                      case 5:
                        showPublishDialog(context, task: tasks[index]);
                        break;
                      case 6:
                        showProgrammingDialog(context, task: tasks[index]);
                        break;
                      case 7:
                        showAdministrativeTaskDetailsDialog(
                          context,
                          task: tasks[index],
                        );
                        break;
                      default:
                    }
                  },
                );
              },
            );
          });
        },
      ),
    );
  }
}
