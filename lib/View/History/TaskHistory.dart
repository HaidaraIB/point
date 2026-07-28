import 'package:point/Utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/task_history_filters_bar.dart';
import 'package:point/View/Tasks/DetailsDialogs/DContentWriteDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DDesignDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DMontageDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPhotographyDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DAdministrativeDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';
import 'package:point/View/Tasks/TaskCard.dart';
import 'package:point/View/History/TasksHistoryMobile.dart';
import 'package:point/Utils/app_theme_extension.dart';

class TasksHistory extends StatefulWidget {
  @override
  State<TasksHistory> createState() => _TasksHistoryState();
}

class _TasksHistoryState extends State<TasksHistory> {
  int selectedDepartmentIndex = 0;
  late final TextEditingController departmentController;

  @override
  void initState() {
    super.initState();
    departmentController = TextEditingController();
  }

  @override
  void dispose() {
    departmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      selectedTab: 8,
      subSelected: selectedDepartmentIndex,
      body: GetBuilder<HomeController>(
        builder: (controller) {
          return Responsive(
            mobile: TasksHistoryMobile(
              selectedIndex: selectedDepartmentIndex,
              onDepartmentChanged: (int newIndex) {
                setState(() {
                  selectedDepartmentIndex = newIndex;
                  departmentController.text = StorageKeys.departments[newIndex];
                });
              },
            ),
            desktop: GetBuilder<HomeController>(
              builder: (controller) {
                return Row(
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
                                    StorageKeys.semanticDepartmentLabelKey(
                                      StorageKeys.departments[selectedDepartmentIndex],
                                    ).tr,
                                    style: TextStyle(
                                      color: context.appTheme.secondaryText,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(),
                                  SizedBox(
                                    width: (Get.width * 0.7 / 2) - 25,
                                    child: DynamicDropdown(
                                      items:
                                          StorageKeys.departments
                                              .map(
                                                (v) => DropdownMenuItem(
                                                  value: v,
                                                  child: Text(
                                                    StorageKeys
                                                        .semanticDepartmentLabelKey(
                                                          v,
                                                        )
                                                        .tr,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      value:
                                          departmentController.text.isEmpty
                                              ? null
                                              : departmentController.text,
                                      label: 'history.select_department'.tr,
                                      borderRadius: 5,
                                      height: 42,
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            departmentController.text =
                                                value.toString();
                                            selectedDepartmentIndex = StorageKeys
                                                .departments
                                                .indexOf(value.toString());
                                          });
                                          appLog(
                                            StorageKeys.departments
                                                .indexOf(value.toString())
                                                .toString(),
                                          );
                                        } else {
                                          setState(() {
                                            departmentController.clear();
                                            selectedDepartmentIndex = 0;
                                          });
                                        }
                                      },
                                      validator: (v) {
                                        if (v == null) return ' ';
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Obx(() {
                                var tasks =
                                    controller.tasksHistory
                                        .where(
                                          (a) =>
                                              a.type ==
                                              selectedDepartmentIndex.toString(),
                                        )
                                        .toList();
                                return Row(
                                  children: [
                                    _buildStatBox(
                                      tasks.length.toString(),
                                      'employee.dashboard.total_tasks'.tr,
                                      Colors.blue,
                                    ),
                                  ],
                                );
                              }),

                              SizedBox(height: 15),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: TaskHistoryFiltersBar(
                                  taskType:
                                      selectedDepartmentIndex.toString(),
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
                                width:
                                    Responsive.isDesktop(context)
                                        ? Get.width - 300
                                        : Get.width,
                                height: 620,
                                child: TasksGridPage(
                                  selectedIndex: selectedDepartmentIndex,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatBox(String value, String label, Color color) {
    final isDesktop = Responsive.isDesktop(Get.context!);
    final boxWidth = isDesktop ? Get.width / 5 - 78 : Get.width / 5 - 30;
    return Container(
      decoration: BoxDecoration(
              color: context.appTheme.cardSurface,
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
            height: 48,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.appTheme.secondaryText,
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
                controller.tasksHistory
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
