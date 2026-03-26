import 'dart:developer';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/DetailsDialogs/DContentWriteDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DDesignDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DMontageDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPhotographyDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';
import 'package:point/View/Tasks/TaskCard.dart';
import 'package:point/View/History/TasksHistoryMobile.dart';

class TasksHistory extends StatefulWidget {
  @override
  State<TasksHistory> createState() => _TasksHistoryState();
}

class _TasksHistoryState extends State<TasksHistory> {
  int subselected = 0;
  late final TextEditingController catController;

  @override
  void initState() {
    super.initState();
    catController = TextEditingController();
  }

  @override
  void dispose() {
    catController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      selectedTab: 8,
      subSelected: subselected,
      body: GetBuilder<HomeController>(
        builder: (controller) {
          return Responsive(
            mobile: TasksHistoryMobile(
              selectedIndex: subselected,
              onDepartmentChanged: (int newIndex) {
                setState(() {
                  subselected = newIndex;
                  catController.text = StorageKeys.departments[newIndex];
                });
              },
            ),
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
                                    'cat${(subselected + 1).toString()}'.tr,
                                    style: TextStyle(
                                      color: AppColors.fontColorGrey,
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
                                                  child: Text('$v'.tr),
                                                ),
                                              )
                                              .toList(),
                                      value:
                                          catController.text.isEmpty
                                              ? null
                                              : catController.text,
                                      label: 'history.select_department'.tr,
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                      height: 42,
                                      fillColor: Colors.white,
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            catController.text =
                                                value.toString();
                                            subselected = StorageKeys
                                                .departments
                                                .indexOf(value.toString());
                                          });
                                          log(
                                            StorageKeys.departments
                                                .indexOf(value.toString())
                                                .toString(),
                                          );
                                        } else {
                                          setState(() {
                                            catController.clear();
                                            subselected = 0;
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
                                              a.type == subselected.toString(),
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
                              SizedBox(
                                height: 62,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: (Get.width * 0.7 / 3) - 25,
                                          child: InputText(
                                            prefixIcon: Icon(
                                              CupertinoIcons.search,
                                              color: Colors.grey,
                                            ),
                                            hintText:
                                                'tasks.search_hint_extended'.tr,
                                            height: 42,
                                            fillColor: Colors.white,
                                            controller:
                                                controller.searchController,

                                            onchange: (value) {
                                              controller.filterTasksHistory();
                                              return null;
                                            },

                                            borderRadius: 5,
                                            borderColor: Colors.grey.shade300,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        InkWell(
                                          onTap: () {
                                            controller.searchController.clear();
                                            controller.selectedPriority.value =
                                                '';
                                            controller.selectedStatus.value =
                                                '';
                                            controller.selectedExecutor.value =
                                                '';
                                            controller.filterTasksHistory();
                                          },
                                          child: SvgPicture.asset(
                                            'assets/svgs/icon_menu.svg',
                                            height: 42,
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Container(
                                          width: 150,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              hint: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                child: Text(
                                                  'tasks.filter_priority'.tr,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        AppColors
                                                            .primaryfontColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              value:
                                                  controller
                                                          .selectedPriority
                                                          .value
                                                          .isEmpty
                                                      ? null
                                                      : controller
                                                          .selectedPriority
                                                          .value,
                                              items:
                                                  StorageKeys.priority
                                                      .map(
                                                        (e) => DropdownMenuItem(
                                                          value: e,
                                                          child: Text(e.tr),
                                                        ),
                                                      )
                                                      .toList(),
                                              onChanged: (value) {
                                                controller
                                                    .selectedPriority
                                                    .value = value ?? '';
                                                controller.filterTasksHistory();
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // 🔹 الحالة (فقط الحالات المنتهية في سجل المهام)
                                        Container(
                                          width: 170,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              hint: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                child: Text(
                                                  'tasks.filter_status'.tr,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        AppColors
                                                            .primaryfontColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              value:
                                                  controller
                                                              .selectedStatus
                                                              .value
                                                              .isEmpty ||
                                                          !StorageKeys
                                                              .statusListEnded
                                                              .contains(
                                                                controller
                                                                    .selectedStatus
                                                                    .value,
                                                              )
                                                      ? null
                                                      : controller
                                                          .selectedStatus
                                                          .value,
                                              items: [
                                                DropdownMenuItem(
                                                  value: '',
                                                  child: Text(
                                                    'filter_status_ended'.tr,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                ...StorageKeys.statusListEnded.map(
                                                  (e) => DropdownMenuItem(
                                                    value: e,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right: 8,
                                                          ),
                                                      child: Text(e.tr),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              onChanged: (value) {
                                                controller
                                                    .selectedStatus
                                                    .value = value ?? '';
                                                controller.filterTasksHistory();
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // 🔹 الملف
                                        SizedBox(
                                          width: 150,
                                          height: 40,

                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                hint: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                  child: Text(
                                                    'tasks.filter_assignee'.tr,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color:
                                                          AppColors
                                                              .primaryfontColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                value:
                                                    controller
                                                            .selectedExecutor
                                                            .value
                                                            .isEmpty
                                                        ? null
                                                        : controller
                                                            .selectedExecutor
                                                            .value,
                                                items:
                                                    controller.employees
                                                        .map(
                                                          (
                                                            e,
                                                          ) => DropdownMenuItem(
                                                            value:
                                                                e.id ??
                                                                e.name ??
                                                                '',
                                                            child: Text(
                                                              (e.name ?? '')
                                                                  .split(' ')
                                                                  .take(2)
                                                                  .join(' '),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                onChanged: (value) {
                                                  controller
                                                      .selectedExecutor
                                                      .value = value ?? '';
                                                  controller
                                                      .filterTasksHistory();
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 15),
                              Text(
                                'tasks.summary.sent_tasks'.tr,
                                style: TextStyle(
                                  color: AppColors.fontColorGrey,
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
                                  selectedIndex: subselected,
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
        color: Colors.white,
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
                  color: Colors.grey,
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
                        showMoantageDialog(context, task: tasks[index]);
                        break;
                      case 5:
                        showPublishDialog(context, task: tasks[index]);
                        break;
                      case 6:
                        showProgrammingDialog(context, task: tasks[index]);
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
