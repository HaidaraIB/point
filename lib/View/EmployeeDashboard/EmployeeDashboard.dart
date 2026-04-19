import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/View/EmployeeDashboard/employee_mobile_app_bar.dart';
import 'package:point/View/EmployeeDashboard/Shared/EmployeeTaskCard.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/app_version_label.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/DetailsDialogs/DContentWriteDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DDesignDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DMontageDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPhotographyDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final c = Get.find<HomeController>();
      await c.restoreEmployeeDashboardTaskFiltersFromPrefs();
      c.update();
    });
  }

  @override
  Widget build(BuildContext context) => const _EmployeeDashboardBody();
}

class _EmployeeDashboardBody extends StatelessWidget {
  const _EmployeeDashboardBody();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        final isMobile = Responsive.isMobile(context);
        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar:
              isMobile ? EmployeeMobileAppBar(controller: controller) : null,
          body: Responsive(mobile: _buildMobile(), desktop: _buildDesktop()),
        );
      },
    );
  }

  Widget _buildDesktop() {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Obx(
          () => Row(
            children: [
              SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(10),
                  width: Get.width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PreferredSize(
                        preferredSize: Size(Get.width, 60),
                        child: Obx(
                          () => HeaderWidget(
                            employee: true,
                            name: controller.currentEmployee.value?.name ?? '',
                            role: controller.currentEmployee.value?.role ?? '',
                            department:
                                controller.currentEmployee.value?.department,
                            avatarUrl:
                                controller.currentEmployee.value?.image ??
                                kDefaultAvatarUrl,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      Row(
                        children: [
                          Text(
                            'employee.dashboard.tasks_assigned_to_you'.tr,
                            style: TextStyle(
                              color: AppColors.fontColorGrey,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          if (StorageKeys.matchesDepartment(
                                controller.currentEmployee.value?.department,
                                StorageKeys.departmentPromotion,
                              ) ||
                              StorageKeys.matchesDepartment(
                                controller.currentEmployee.value?.department,
                                StorageKeys.departmentPublishing,
                              ))
                            MainButton(
                              width: 180,
                              height: 45,
                              borderSize: 35,
                              fontColor: Colors.white,
                              backgroundColor: AppColors.primary,
                              widget: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'managecontent'.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  Icon(
                                    Icons.navigate_next,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                              onPressed: () {
                                Get.toNamed('/employeeContent');
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
                                      a.assignedTo ==
                                      controller.currentEmployee.value?.id,
                                )
                                .toList();
                        final isDesktop = Responsive.isDesktop(Get.context!);
                        final cardWidth =
                            isDesktop
                                ? (Get.width - 100) / 4
                                : (Get.width / 4 - 16).clamp(72.0, 140.0);
                        var statNotStarted = 0;
                        var statInProgress = 0;
                        var statSendForReview = 0;
                        var statApproved = 0;
                        for (final a in tasks) {
                          final bucket =
                              StorageKeys.employeeDashboardFourCardStatBucket(
                                canonicalStatus: FunHelper.canonicalStoredStatus(
                                  a.status,
                                ),
                                taskType: a.type,
                              );
                          if (bucket == null) continue;
                          switch (bucket) {
                            case StorageKeys.employeeDashFourCardNotStarted:
                              statNotStarted++;
                              break;
                            case StorageKeys.employeeDashFourCardInProgress:
                              statInProgress++;
                              break;
                            case StorageKeys.employeeDashFourCardSendForReview:
                              statSendForReview++;
                              break;
                            default:
                              statApproved++;
                          }
                        }
                        final statRow = Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatBox(
                              statNotStarted.toString(),
                              FunHelper.translateAppKey(
                                'employee.dashboard.stat_not_started',
                              ),
                              Colors.grey.shade700,
                              width: cardWidth,
                            ),
                            _buildStatBox(
                              statInProgress.toString(),
                              FunHelper.translateAppKey(
                                'employee.dashboard.stat_in_progress',
                              ),
                              Colors.amber.shade800,
                              width: cardWidth,
                            ),
                            _buildStatBox(
                              statSendForReview.toString(),
                              FunHelper.translateAppKey(
                                'employee.dashboard.stat_send_for_review',
                              ),
                              Colors.blue,
                              width: cardWidth,
                            ),
                            _buildStatBox(
                              statApproved.toString(),
                              FunHelper.translateAppKey(
                                'employee.dashboard.stat_approved',
                              ),
                              Colors.green,
                              width: cardWidth,
                            ),
                          ],
                        );
                        return isDesktop
                            ? statRow
                            : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: statRow,
                            );
                      }),

                      SizedBox(height: 15),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: InputText(
                                prefixIcon: Icon(
                                  CupertinoIcons.search,
                                  color: Colors.grey,
                                ),
                                hintText: 'employee.search_tasks_hint'.tr,
                                height: 42,
                                fillColor: Colors.white,
                                controller: controller.searchController,

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
                                unawaited(
                                  controller.clearEmployeeDashboardTaskFilters(),
                                );
                              },
                              child: SvgPicture.asset(
                                'assets/svgs/icon_menu.svg',
                                height: 42,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 150,
                              height: 40,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    hint: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        'tasks.filter_priority'.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.primaryfontColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    value:
                                        controller.selectedPriority.value.isEmpty
                                            ? null
                                            : controller.selectedPriority.value,
                                    items:
                                        StorageKeys.priority
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(
                                                  e.tr,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) async {
                                      controller.selectedPriority.value =
                                          value ?? '';
                                      controller.filterTasks();
                                      await controller
                                          .persistEmployeeDashboardTaskFilters();
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // 🔹 الحالة
                            SizedBox(
                              width: 150,
                              height: 40,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    hint: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        'tasks.filter_status'.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.primaryfontColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    value:
                                        controller.selectedStatus.value.isEmpty
                                            ? null
                                            : controller.selectedStatus.value,
                                    items:
                                        StorageKeys
                                            .employeeDashboardTaskStatusFilterDropdownValuesForDepartment(
                                              controller
                                                  .currentEmployee
                                                  .value
                                                  ?.department,
                                            )
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(
                                                  e.tr,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) async {
                                      controller.selectedStatus.value =
                                          value ?? '';
                                      controller.filterTasks();
                                      await controller
                                          .persistEmployeeDashboardTaskFilters();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                        width: Get.width,
                        height: 620,
                        child: TasksGridPage(),
                      ),
                      AppVersionLabel(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        textStyle: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: Colors.grey.shade600,
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
    );
  }

  Widget _buildMobile() {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Obx(
          () => Row(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    controller.fetchTasks();
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      padding: EdgeInsets.all(10),
                      width: Get.width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Text(
                                'employee.dashboard.tasks_assigned_to_you'.tr,
                                style: TextStyle(
                                  color: AppColors.fontColorGrey,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Spacer(),
                              if (StorageKeys.matchesDepartment(
                                controller.currentEmployee.value?.department,
                                StorageKeys.departmentPromotion,
                              ) ||
                              StorageKeys.matchesDepartment(
                                controller.currentEmployee.value?.department,
                                StorageKeys.departmentPublishing,
                              ))
                                MainButton(
                                  width: 180,
                                  height: 45,
                                  borderSize: 35,
                                  fontColor: Colors.white,
                                  backgroundColor: AppColors.primary,
                                  widget: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'managecontent'.tr,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      Icon(
                                        Icons.navigate_next,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                  onPressed: () {
                                    Get.toNamed('/employeeContent');
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
                                          a.assignedTo ==
                                          controller.currentEmployee.value?.id,
                                    )
                                    .toList();
                            var statNotStarted = 0;
                            var statInProgress = 0;
                            var statSendForReview = 0;
                            var statApproved = 0;
                            for (final a in tasks) {
                              final bucket =
                                  StorageKeys
                                      .employeeDashboardFourCardStatBucket(
                                        canonicalStatus:
                                            FunHelper.canonicalStoredStatus(
                                              a.status,
                                            ),
                                        taskType: a.type,
                                      );
                              if (bucket == null) continue;
                              switch (bucket) {
                                case StorageKeys.employeeDashFourCardNotStarted:
                                  statNotStarted++;
                                  break;
                                case StorageKeys.employeeDashFourCardInProgress:
                                  statInProgress++;
                                  break;
                                case StorageKeys
                                    .employeeDashFourCardSendForReview:
                                  statSendForReview++;
                                  break;
                                default:
                                  statApproved++;
                              }
                            }
                            // [_buildStatBox] uses margin 10 on all sides → +20 horizontal per card.
                            // Use parent width (not [Get.width]) so rows match padded constraints.
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                var mw = constraints.maxWidth;
                                if (!mw.isFinite || mw <= 0) {
                                  mw = MediaQuery.sizeOf(context).width - 20;
                                }
                                final innerW = ((mw - 40) / 2).clamp(48.0, 400.0);
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        _buildStatBox(
                                          statNotStarted.toString(),
                                          FunHelper.translateAppKey(
                                            'employee.dashboard.stat_not_started',
                                          ),
                                          Colors.grey.shade700,
                                          width: innerW,
                                        ),
                                        _buildStatBox(
                                          statInProgress.toString(),
                                          FunHelper.translateAppKey(
                                            'employee.dashboard.stat_in_progress',
                                          ),
                                          Colors.amber.shade800,
                                          width: innerW,
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        _buildStatBox(
                                          statSendForReview.toString(),
                                          FunHelper.translateAppKey(
                                            'employee.dashboard.stat_send_for_review',
                                          ),
                                          Colors.blue,
                                          width: innerW,
                                        ),
                                        _buildStatBox(
                                          statApproved.toString(),
                                          FunHelper.translateAppKey(
                                            'employee.dashboard.stat_approved',
                                          ),
                                          Colors.green,
                                          width: innerW,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          }),

                          SizedBox(height: 15),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: (Get.width * 0.7) - 25,
                                      child: InputText(
                                        prefixIcon: Icon(
                                          CupertinoIcons.search,
                                          color: Colors.grey,
                                        ),
                                        hintText: 'employee.search_tasks_hint'.tr,
                                        height: 42,
                                        fillColor: Colors.white,
                                        controller: controller.searchController,

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
                                        unawaited(
                                          controller
                                              .clearEmployeeDashboardTaskFilters(),
                                        );
                                      },
                                      child: SvgPicture.asset(
                                        'assets/svgs/icon_menu.svg',
                                        height: 42,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                // 🔹 الحالة
                                Row(
                                  children: [
                                    Container(
                                      width: 150,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          hint: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              'tasks.filter_priority'.tr,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.primaryfontColor,
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
                                                      child: Text(
                                                        e.tr,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged: (value) async {
                                            controller.selectedPriority.value =
                                                value ?? '';
                                            controller.filterTasks();
                                            await controller
                                                .persistEmployeeDashboardTaskFilters();
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    Container(
                                      width: 150,
                                      height: 40,

                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          hint: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              'tasks.filter_status'.tr,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.primaryfontColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          value:
                                              controller
                                                      .selectedStatus
                                                      .value
                                                      .isEmpty
                                                  ? null
                                                  : controller.selectedStatus.value,
                                          items:
                                              StorageKeys
                                                  .employeeDashboardTaskStatusFilterDropdownValuesForDepartment(
                                                    controller
                                                        .currentEmployee
                                                        .value
                                                        ?.department,
                                                  )
                                                  .map(
                                                    (e) => DropdownMenuItem(
                                                      value: e,
                                                      child: Text(
                                                        e.tr,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged: (value) async {
                                            controller.selectedStatus.value =
                                                value ?? '';
                                            controller.filterTasks();
                                            await controller
                                                .persistEmployeeDashboardTaskFilters();
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                            width: Get.width,
                            // height: 620,
                            child: TasksListPage(),
                          ),
                          AppVersionLabel(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            textStyle: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
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
        width ?? (isDesktop ? Get.width / 4 - 78 : Get.width / 4 - 30);
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
          SizedBox(height: 16),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  height: 1.2,
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
  @override
  Widget build(BuildContext context) {
    return Container(
      child: GetBuilder<HomeController>(
        builder: (controller) {
          return Obx(() {
            final tasks =
                controller.tasksSearched
                    .where(
                      (a) =>
                          a.assignedTo == controller.currentEmployee.value?.id,
                    )
                    .toList();
            return GridView.builder(
              itemCount: tasks.length,

              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemBuilder: (context, index) {
                return EmployeeTaskCard(
                  task: tasks[index],
                  onTap: () {
                    switch (tasks[index].type) {
                      case '0':
                        showCampaignDetailsDialog(context, task: tasks[index]);
                        break;
                      case '1':
                        showDesignDetailsDialog(context, task: tasks[index]);
                        break;
                      case '2':
                        showDPhotographyDialog(context, task: tasks[index]);
                        break;
                      case '3':
                        showContentWriteDialog(context, task: tasks[index]);
                        break;
                      case '4':
                        showMontageDialog(context, task: tasks[index]);
                        break;
                      case '5':
                        showPublishDialog(context, task: tasks[index]);
                        break;
                      case '6':
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

class TasksListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: GetBuilder<HomeController>(
        builder: (controller) {
          return Obx(() {
            final tasks =
                controller.tasksSearched
                    .where(
                      (a) =>
                          a.assignedTo == controller.currentEmployee.value?.id,
                    )
                    .toList();
            return ListView.builder(
              itemCount: tasks.length,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),

              itemBuilder: (context, index) {
                return EmployeeTaskCard(
                  task: tasks[index],
                  onTap: () {
                    switch (tasks[index].type) {
                      case '0':
                        showCampaignDetailsDialog(context, task: tasks[index]);
                        break;
                      case '1':
                        showDesignDetailsDialog(context, task: tasks[index]);
                        break;
                      case '2':
                        showDPhotographyDialog(context, task: tasks[index]);
                        break;
                      case '3':
                        showContentWriteDialog(context, task: tasks[index]);
                        break;
                      case '4':
                        showMontageDialog(context, task: tasks[index]);
                        break;
                      case '5':
                        showPublishDialog(context, task: tasks[index]);
                        break;
                      case '6':
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
