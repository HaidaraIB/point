import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
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
import 'package:point/View/Tasks/Dialogs/PhotoGraphyDialog.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';
import 'package:point/View/Tasks/Dialogs/PromotionDialog.dart';
import 'package:point/View/Tasks/Dialogs/PublishDialog.dart';
import 'package:point/View/Tasks/TaskCard.dart';

/// Mobile-only tasks screen with a single scroll so the last item is fully visible.
class TasksMobile extends StatelessWidget {
  final int selectedIndex;

  const TasksMobile({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Obx(() {
          final List<TaskModel> tasks =
              controller.tasksSearched
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
                delegate: SliverChildBuilderDelegate((context, index) {
                  // TaskCard uses LayoutBuilder and needs bounded height
                  // (GridView on desktop provides it; SliverList does not).
                  final cardHeight =
                      MediaQuery.of(context).size.width / 1.35 + 24;
                  return SizedBox(
                    height: cardHeight.clamp(280.0, 400.0),
                    child: TaskCard(
                      task: tasks[index],
                      onTap:
                          () => _openTaskDetails(
                            context,
                            selectedIndex,
                            tasks[index],
                          ),
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

  Widget _buildHeader(BuildContext context, HomeController controller) {
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
        MainButton(
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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
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
                photoGraphyDialog(context);
                break;
              case 3:
                contentWriteDiloag(context);
                break;
              case 4:
                montageDiloag(context);
                break;
              case 5:
                publishDilaog(context);
                break;
              case 6:
                programmingDiloag(context);
                break;
              default:
            }
          },
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
              .where((a) => a.status == StorageKeys.status_processing)
              .length
              .toString(),
          'status_processing'.tr,
          Colors.amber,
          width: boxWidth,
        ),
        _buildStatBox(
          tasks
              .where((a) => a.status == StorageKeys.status_under_revision)
              .length
              .toString(),
          'status_under_revision'.tr,
          Colors.blue,
          width: boxWidth,
        ),
        _buildStatBox(
          tasks
              .where((a) => a.status == StorageKeys.status_approved)
              .length
              .toString(),
          'employee.dashboard.completed'.tr,
          Colors.green,
          width: boxWidth,
        ),
        _buildStatBox(
          tasks
              .where((a) => a.status == StorageKeys.status_rejected)
              .length
              .toString(),
          'employee.dashboard.cancelled'.tr,
          Colors.red,
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
                  prefixIcon: Icon(CupertinoIcons.search, color: Colors.grey),
                  hintText: 'tasks.search_hint_extended'.tr,
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
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  controller.searchController.clear();
                  controller.selectedPriority.value = '';
                  controller.selectedStatus.value = '';
                  controller.selectedExecutor.value = '';
                  controller.filterTasks();
                },
                child: SvgPicture.asset('assets/svgs/icon_menu.svg', height: 42),
              ),
              const SizedBox(width: 24),
              _buildDropdown<String>(
                width: 150,
                hint: 'tasks.filter_priority'.tr,
                value:
                    controller.selectedPriority.value.isEmpty
                        ? null
                        : controller.selectedPriority.value,
                items:
                    StorageKeys.priority
                        .map(
                          (e) => DropdownMenuItem(value: e, child: Text(e.tr)),
                        )
                        .toList(),
                onChanged: (value) {
                  controller.selectedPriority.value = value ?? '';
                  controller.filterTasks();
                },
              ),
              const SizedBox(width: 10),
              _buildStatusDropdown(controller),
              const SizedBox(width: 10),
              _buildDropdown<String>(
                width: 150,
                hint: 'tasks.filter_assignee'.tr,
                value:
                    controller.selectedExecutor.value.isEmpty
                        ? null
                        : controller.selectedExecutor.value,
                items:
                    controller.employees
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

  Widget _buildStatusDropdown(HomeController controller) {
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
            hint: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
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
                controller.selectedStatus.value.isEmpty ||
                        !StorageKeys.statusListOngoing.contains(
                          controller.selectedStatus.value,
                        )
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
              ...StorageKeys.statusListOngoing.map(
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
