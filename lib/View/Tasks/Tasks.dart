import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/home_task_filters.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/task_list_filters_bar.dart';
import 'package:point/View/Shared/task_status_visuals.dart';
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
import 'package:point/View/Tasks/TaskCard.dart';
import 'package:point/View/Tasks/TasksMobile.dart';
import 'package:point/View/Tasks/open_task_details.dart';
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
                          width: Responsive.isDesktop(context)
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
                                ProgrammingDepartmentTabs(
                                  initialTabIndex:
                                      programmingUpdatesTabFromRoute(),
                                  expandContent: false,
                                  tasksTab: _buildProgrammingTasksDesktopBody(
                                    context,
                                    controller,
                                    selectedIndex,
                                  ),
                                )
                              else ...[
                                Obx(() {
                                  final tasks = controller.tasksSearched
                                      .where(
                                        (a) =>
                                            a.type == selectedIndex.toString(),
                                      )
                                      .toList();
                                  final isDesktop = Responsive.isDesktop(
                                    Get.context!,
                                  );
                                  final boxWidth = isDesktop
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
                                  width: Responsive.isDesktop(context)
                                      ? Get.width - 300
                                      : Get.width,
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
        const ProgrammingSuggestionsCard(),
        const SizedBox(height: 20),
        Text(
          'programming.tab.tasks'.tr,
          style: TextStyle(
            color: resolveAppTheme().secondaryText,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TaskListFiltersBar(taskType: selectedIndex.toString()),
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
    final defaultScrollBehavior = ScrollConfiguration.of(context);
    return Container(
      child: GetBuilder<HomeController>(
        builder: (controller) {
          return Obx(() {
            final tasks = controller.tasksSearched
                .where((a) => a.type == selectedIndex.toString())
                .toList();
            return ScrollConfiguration(
              // الشبكة غير قابلة للتمرير، لذا لا داعي لشريط تمرير ثابت
              behavior: defaultScrollBehavior.copyWith(scrollbars: false),
              child: GridView.builder(
                itemCount: tasks.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: Responsive.isDesktop(Get.context!) ? 3 : 1,

                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  return ScrollConfiguration(
                    // إبقاء أشرطة التمرير الافتراضية داخل البطاقات
                    behavior: defaultScrollBehavior,
                    child: TaskCard(
                      task: tasks[index],
                      onTap: () {
                        openTaskDetails(context, tasks[index]);
                      },
                    ),
                  );
                },
              ),
            );
          });
        },
      ),
    );
  }
}
