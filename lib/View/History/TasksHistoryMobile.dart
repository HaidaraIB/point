import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Tasks/DetailsDialogs/DContentWriteDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DDesignDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DMontageDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPhotographyDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';
import 'package:point/View/Tasks/TaskCard.dart';

/// Mobile-only task history screen: same layout as TasksMobile but uses
/// tasksHistory, filterTasksHistory(), and statusListEnded for filters.
class TasksHistoryMobile extends StatelessWidget {
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
                        'المهام المرسلة'.tr,
                        style: const TextStyle(
                          color: AppColors.fontColorGrey,
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
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cardHeight =
                        MediaQuery.of(context).size.width / 1.35 + 24;
                    return SizedBox(
                      height: cardHeight.clamp(280.0, 400.0),
                      child: TaskCard(
                        task: tasks[index],
                        ontap: () => _openTaskDetails(
                          context,
                          selectedIndex,
                          tasks[index],
                        ),
                      ),
                    );
                  },
                  childCount: tasks.length,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottomPadding),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          'cat${selectedIndex + 1}'.tr,
          style: const TextStyle(
            color: AppColors.fontColorGrey,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: (Get.width * 0.7 / 2) - 25,
          child: DynamicDropdown<String>(
            items: StorageKeys.departments
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text('$v'.tr),
                  ),
                )
                .toList(),
            value: StorageKeys.departments.length > selectedIndex
                ? StorageKeys.departments[selectedIndex]
                : null,
            label: 'اختر القسم '.tr,
            borderRadius: 5,
            borderColor: Colors.grey.shade300,
            height: 42,
            fillColor: Colors.white,
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
            'اجمالي المهام'.tr,
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
        color: Colors.white,
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
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
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

  Widget _buildFilters(BuildContext context, HomeController controller) {
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
                  prefixicon: Icon(CupertinoIcons.search, color: Colors.grey),
                  hintText: 'ابحث عن مهمة، عنوان، موظف...',
                  height: 42,
                  fillColor: Colors.white,
                  controller: controller.searchController,
                  onchange: (value) {
                    controller.filterTasksHistory();
                    return null;
                  },
                  borderRadius: 5,
                  borderColor: Colors.grey.shade300,
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  controller.searchController.clear();
                  controller.selectedPriority.value = '';
                  controller.selectedStatus.value = '';
                  controller.selectedExecutor.value = '';
                  controller.filterTasksHistory();
                },
                child: SvgPicture.asset('assets/svgs/Menu.svg', height: 42),
              ),
              const SizedBox(width: 24),
              _buildDropdown<String>(
                width: 150,
                hint: 'الأولوية',
                value: controller.selectedPriority.value.isEmpty
                    ? null
                    : controller.selectedPriority.value,
                items: StorageKeys.priority
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.tr)))
                    .toList(),
                onChanged: (value) {
                  controller.selectedPriority.value = value ?? '';
                  controller.filterTasksHistory();
                },
              ),
              const SizedBox(width: 10),
              _buildStatusEndedDropdown(controller),
              const SizedBox(width: 10),
              _buildDropdown<String>(
                width: 150,
                hint: 'المنفذ',
                value: controller.selectedExecutor.value.isEmpty
                    ? null
                    : controller.selectedExecutor.value,
                items: controller.employees
                    .map((e) => DropdownMenuItem(
                          value: e.id ?? e.name ?? '',
                          child: Text(
                              (e.name ?? '').split(' ').take(2).join(' ')),
                        ))
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
    );
  }

  Widget _buildDropdown<T>({
    required double width,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: width,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                hint,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primaryfontColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            value: value,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  /// Status dropdown for history: only ended statuses (statusListEnded).
  Widget _buildStatusEndedDropdown(HomeController controller) {
    return SizedBox(
      width: 170,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            hint: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'الحالة',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primaryfontColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            value: controller.selectedStatus.value.isEmpty ||
                    !StorageKeys.statusListEnded
                        .contains(controller.selectedStatus.value)
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
              ...StorageKeys.statusListEnded.map(
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
          ),
        ),
      ),
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
        showMoantageDialog(context, task: task);
        break;
      case 5:
        showPublishDialog(context, task: task);
        break;
      case 6:
        showProgrammingDialog(context, task: task);
        break;
      default:
    }
  }
}
