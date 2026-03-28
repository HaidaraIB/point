import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/DetailsDialogs/DContentWriteDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DDesignDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DMontageDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPhotographyDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';
import 'package:point/View/Tasks/Dialogs/ContentWriteDialog.dart';
import 'package:point/View/Tasks/Dialogs/DesignDialog.dart';
import 'package:point/View/Tasks/Dialogs/MontageDialog.dart';
import 'package:point/View/Tasks/Dialogs/PhotographyDialog.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';
import 'package:point/View/Tasks/Dialogs/PromotionDialog.dart';
import 'package:point/View/Tasks/Dialogs/PublishDialog.dart';
import 'package:point/View/Tasks/TaskCard.dart';
import 'package:point/View/Tasks/TasksMobile.dart';

class Tasks extends StatelessWidget {
  static const List<String> _departmentRouteSlugs = <String>[
    StorageKeys.departmentPromotion,
    StorageKeys.departmentDesign,
    StorageKeys.departmentPhotography,
    StorageKeys.departmentContentWriting,
    StorageKeys.departmentMontage,
    StorageKeys.departmentPublishing,
    StorageKeys.departmentProgramming,
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
                                      color: AppColors.fontColorGrey,
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
                                        default:
                                      }
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
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
                                final statRow = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildStatBox(
                                      tasks.length.toString(),
                                      'employee.dashboard.total_tasks'.tr,
                                      Colors.blue,
                                      width: boxWidth,
                                    ),
                                    _buildStatBox(
                                      tasks
                                          .where(
                                            (a) =>
                                                a.status ==
                                                StorageKeys.status_processing,
                                          )
                                          .length
                                          .toString(),
                                      'status_processing'.tr,
                                      Colors.amber,
                                      width: boxWidth,
                                    ),
                                    _buildStatBox(
                                      tasks
                                          .where(
                                            (a) =>
                                                a.status ==
                                                StorageKeys
                                                    .status_under_revision,
                                          )
                                          .length
                                          .toString(),
                                      'status_under_revision'.tr,
                                      Colors.blue,
                                      width: boxWidth,
                                    ),
                                    _buildStatBox(
                                      tasks
                                          .where(
                                            (a) =>
                                                a.status ==
                                                StorageKeys
                                                    .status_awaiting_manager,
                                          )
                                          .length
                                          .toString(),
                                      'status_awaiting_manager'.tr,
                                      Colors.indigo,
                                      width: boxWidth,
                                    ),
                                    _buildStatBox(
                                      tasks
                                          .where(
                                            (a) =>
                                                a.status ==
                                                StorageKeys.status_approved,
                                          )
                                          .length
                                          .toString(),
                                      'employee.dashboard.completed'.tr,
                                      Colors.green,
                                      width: boxWidth,
                                    ),
                                    _buildStatBox(
                                      tasks
                                          .where(
                                            (a) =>
                                                a.status ==
                                                StorageKeys.status_rejected,
                                          )
                                          .length
                                          .toString(),
                                      'employee.dashboard.cancelled'.tr,
                                      Colors.red,
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
                                              controller.filterTasks();
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
                                            controller.filterTasks();
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
                                                controller.filterTasks();
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // 🔹 الحالة (فقط المهام الجارية)
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
                                                              .statusListOngoing
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
                                                    'filter_status_ongoing'.tr,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                ...StorageKeys.statusListOngoing
                                                    .map(
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
                                                controller.filterTasks();
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
                                                  controller.filterTasks();
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
                                  selectedIndex: selectedIndex,
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
