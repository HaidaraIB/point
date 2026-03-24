import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/View/Chats/MChatPage.dart';
import 'package:point/View/EmployeeDashboard/Shared/EmployeeTaskCard.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/DetailsDialogs/DContentWriteDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DDesignDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DMontageDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPhotographyDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';

class EmployeeDashBord extends StatelessWidget {
  // final subselected = Get.parameters;
  final LanguageController _languageController = Get.find<LanguageController>();
  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        final isMobile = Responsive.isMobile(context);
        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: isMobile ? _buildMobileAppBar(controller) : null,
          body: Responsive(mobile: _buildMobile(), desktop: _buildDesktop()),
        );
      },
    );
  }

  PreferredSizeWidget _buildMobileAppBar(HomeController controller) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 10,
      title: Row(
        children: [
          IconButton(
            tooltip: 'header.notifications'.tr,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, color: AppColors.primary),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Obx(
                    () => HeaderCountBadge(
                      count:
                          controller.notifications
                              .where(
                                (n) =>
                                    n.data?['type'] != 'message' &&
                                    n.data?['type'] != 'chat' &&
                                    n.isRead == false,
                              )
                              .length,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              _showEmployeeNotificationsDialog(Get.context!, controller);
            },
          ),
          PopupMenuButton<String>(
            tooltip: AppLocaleKeys.appLanguage.tr,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.language, color: AppColors.primary),
            onSelected: (value) => _languageController.changeLanguage(value),
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'ar',
                    child: Text(AppLocaleKeys.appLanguageArabic.tr),
                  ),
                  PopupMenuItem(
                    value: 'en',
                    child: Text(AppLocaleKeys.appLanguageEnglish.tr),
                  ),
                ],
          ),
          IconButton(
            tooltip: 'header.chat'.tr,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Obx(
                    () => HeaderCountBadge(
                      count: controller.totalUnreadMessages.value,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () => Get.to(() => ChatsListScreen(onMinimize: () {})),
          ),
          const Spacer(),
          PopupMenuButton<int>(
            tooltip: 'tasks.options_tooltip'.tr,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
            elevation: 4,
            onSelected: (value) async {
              if (value == 0) {
                final shouldLogout = await _confirmEmployeeLogoutDialog(Get.context!);
                if (!shouldLogout) return;
                controller.clearEmployeeSession();
                await FirestoreServices().signOut();
                FunHelper.removelogindata();
                Get.offAllNamed('/auth/login');
              } else if (value == 1) {
                Get.toNamed('/auth/resetPassword');
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 1,
                    child: Row(
                      children: [
                        Text(
                          'resetpassword'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.lock_reset, color: AppColors.primary),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 0,
                    child: Row(
                      children: [
                        Text(
                          'logout'.tr,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.logout, color: Colors.red),
                      ],
                    ),
                  ),
                ],
            child: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(
                controller.currentemployee.value?.image ?? kDefaultAvatarUrl,
              ),
            ),
          ),
        ],
      ),
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
                            name: controller.currentemployee.value?.name ?? '',
                            role: controller.currentemployee.value?.role ?? '',
                            avatarUrl:
                                controller.currentemployee.value?.image ??
                                kDefaultAvatarUrl,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      Row(
                        children: [
                          // Text(
                          //   'cat${(int.parse(subselected['id'].toString()) + 1).toString()}'
                          //       .tr,
                          //   style: TextStyle(
                          //     color: AppColors.fontColorGrey,
                          //     fontSize: 15,
                          //     fontWeight: FontWeight.bold,
                          //   ),
                          // ),
                          Text(
                            'employee.dashboard.tasks_assigned_to_you'.tr,
                            style: TextStyle(
                              color: AppColors.fontColorGrey,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          PopupMenuButton<String>(
                            tooltip: AppLocaleKeys.appLanguage.tr,
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.language,
                              color: AppColors.primary,
                            ),
                            onSelected:
                                (value) =>
                                    _languageController.changeLanguage(value),
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 'ar',
                                    child: Text(
                                      AppLocaleKeys.appLanguageArabic.tr,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'en',
                                    child: Text(
                                      AppLocaleKeys.appLanguageEnglish.tr,
                                    ),
                                  ),
                                ],
                          ),
                          Spacer(),
                          if (controller.currentemployee.value?.department ==
                                  'cat1' ||
                              controller.currentemployee.value?.department ==
                                  'cat6')
                            MainButton(
                              width: 180,
                              height: 45,
                              bordersize: 35,
                              fontcolor: Colors.white,
                              backgroundcolor: AppColors.primary,
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
                              onpress: () {
                                Get.toNamed('/content');
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
                                      controller.currentemployee.value?.id,
                                )
                                .toList();
                        final isDesktop =
                            Responsive.isDesktop(Get.context!);
                        final boxWidth = isDesktop
                            ? null
                            : (Get.width / 5 - 30).clamp(88.0, double.infinity);
                        final statRow = Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        StorageKeys.status_under_revision,
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
                                        a.status == StorageKeys.status_approved,
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
                                        a.status == StorageKeys.status_rejected,
                                  )
                                  .length
                                  .toString(),
                              'employee.dashboard.cancelled'.tr,
                              Colors.red,
                              width: boxWidth,
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
                            SizedBox(
                              width: (Get.width * 0.7 / 3) - 25,
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
                                controller.searchController.clear();
                                controller.selectedPriority.value = '';
                                controller.selectedStatus.value = '';
                                controller.filterTasks();
                              },
                              child: SvgPicture.asset(
                                'assets/svgs/Menu.svg',
                                height: 42,
                              ),
                            ),
                            Spacer(),
                            Container(
                              width: 150,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  hint: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      'tasks.filter_priority'.tr,
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
                                              child: Text(e.tr),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    controller.selectedPriority.value =
                                        value ?? '';
                                    controller.filterTasks();
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // 🔹 الحالة
                            Container(
                              width: 150,
                              height: 40,

                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  hint: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      'tasks.filter_status'.tr,
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
                                      StorageKeys.statusList
                                          .map(
                                            (e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(e.tr),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    controller.selectedStatus.value =
                                        value ?? '';
                                    controller.filterTasks();
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            const SizedBox(width: 10),
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
              SingleChildScrollView(
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
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            tooltip: AppLocaleKeys.appLanguage.tr,
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.language,
                              color: AppColors.primary,
                            ),
                            onSelected:
                                (value) =>
                                    _languageController.changeLanguage(value),
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 'ar',
                                    child: Text(
                                      AppLocaleKeys.appLanguageArabic.tr,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'en',
                                    child: Text(
                                      AppLocaleKeys.appLanguageEnglish.tr,
                                    ),
                                  ),
                                ],
                          ),
                          Spacer(),
                          if (controller.currentemployee.value?.department ==
                                  'cat1' ||
                              controller.currentemployee.value?.department ==
                                  'cat6')
                            MainButton(
                              width: 180,
                              height: 45,
                              bordersize: 35,
                              fontcolor: Colors.white,
                              backgroundcolor: AppColors.primary,
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
                              onpress: () {
                                Get.toNamed('/content');
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
                                      controller.currentemployee.value?.id,
                                )
                                .toList();
                        return Column(
                          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatBox(
                              tasks.length.toString(),
                              'employee.dashboard.total_tasks'.tr,
                              Colors.blue,
                              width: Get.width - 30,
                            ),
                            Row(
                              children: [
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
                                  width: Get.width / 2 - 30,
                                ),
                                _buildStatBox(
                                  tasks
                                      .where(
                                        (a) =>
                                            a.status ==
                                            StorageKeys.status_under_revision,
                                      )
                                      .length
                                      .toString(),
                                  'status_under_revision'.tr,
                                  Colors.blue,
                                  width: Get.width / 2 - 30,
                                ),
                              ],
                            ),

                            Row(
                              children: [
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
                                  width: Get.width / 2 - 30,
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
                                  width: Get.width / 2 - 30,
                                ),
                              ],
                            ),
                          ],
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
                                    controller.searchController.clear();
                                    controller.selectedPriority.value = '';
                                    controller.selectedStatus.value = '';
                                    controller.filterTasks();
                                  },
                                  child: SvgPicture.asset(
                                    'assets/svgs/Menu.svg',
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
                                      hint: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          'tasks.filter_priority'.tr,
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
                                                  child: Text(e.tr),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (value) {
                                        controller.selectedPriority.value =
                                            value ?? '';
                                        controller.filterTasks();
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
                                      hint: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          'tasks.filter_status'.tr,
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
                                          StorageKeys.statusList
                                              .map(
                                                (e) => DropdownMenuItem(
                                                  value: e,
                                                  child: Text(e.tr),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (value) {
                                        controller.selectedStatus.value =
                                            value ?? '';
                                        controller.filterTasks();
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

  Widget _buildStatBox(
    String value,
    String label,
    Color color, {
    double? width,
  }) {
    final isDesktop = Responsive.isDesktop(Get.context!);
    final boxWidth = width ?? (isDesktop ? Get.width / 5 - 78 : Get.width / 5 - 30);
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
                          a.assignedTo == controller.currentemployee.value?.id,
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
                        showMoantageDialog(context, task: tasks[index]);
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
                          a.assignedTo == controller.currentemployee.value?.id,
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
                        showMoantageDialog(context, task: tasks[index]);
                        break;
                      case '5':
                        showPublishDialog(context, task: tasks[index]);
                        break;
                      case '6':
                        programmingDiloag(context);
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

Future<bool> _confirmEmployeeLogoutDialog(BuildContext context) async {
  final isArabic = Get.locale?.languageCode == 'ar';
  final result = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text('logout'.tr),
          content: Text(
            isArabic
                ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
                : 'Are you sure you want to log out?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('cancel'.tr),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'logout'.tr,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
  );
  return result ?? false;
}

bool _isAppInboxNotification(NotificationModel n) {
  return n.data?['type'] != 'message' && n.data?['type'] != 'chat';
}

Future<void> _markVisibleAppNotificationsRead(HomeController controller) async {
  final ids =
      controller.notifications
          .where(
            (n) =>
                _isAppInboxNotification(n) &&
                n.isRead == false &&
                n.id != null &&
                n.id!.isNotEmpty,
          )
          .map((n) => n.id!)
          .toSet()
          .toList();
  if (ids.isEmpty) return;
  await FirestoreServices.markInAppNotificationsAsRead(ids);
}

void _showEmployeeNotificationsDialog(
  BuildContext context,
  HomeController controller,
) {
  _markVisibleAppNotificationsRead(controller);
  showDialog(
    context: context,
    builder:
        (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'header.notifications'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                      fontSize: 18,
                    ),
                  ),
                ),
                Flexible(
                  child: Obx(() {
                    final filtered =
                        controller.notifications
                            .where((n) => _isAppInboxNotification(n))
                            .toList();
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (context, index) {
                        final n = filtered[index];
                        final bgColors = [
                          Colors.pink.shade100,
                          Colors.green.shade100,
                          Colors.purple.shade100,
                          Colors.teal.shade100,
                        ];
                        final randomColor = bgColors[index % bgColors.length];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: randomColor,
                            child: Text(
                              n.title.toString().isNotEmpty
                                  ? n.title.toString()[0]
                                  : 'N',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title ?? '',
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                n.body ?? '',
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          subtitle: Text(
                            n.createdAt != null
                                ? FunHelper.formatdateTime(n.createdAt!).toString()
                                : '',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
  );
}
