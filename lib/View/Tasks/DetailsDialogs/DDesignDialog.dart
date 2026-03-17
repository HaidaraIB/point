import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/DetailsDialogs/GenericTaskDetailsDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:point/View/Tasks/Mobile/TaskDetailsMobile.dart';

void showDesignDetailsDialog(BuildContext context, {required TaskModel task}) {
  Responsive.isMobile(context)
      ? showTaskDetailsMobile(context, task: task)
      : showDialog(
          context: context,
          builder: (context) => GenericTaskDetailsDialog(
            task: task,
            dialogWidthFraction: 0.7,
            typeSpecificSection: DesignDetailsSection(task: task),
          ),
        );
}

/// Type-specific info section for Design task details (web).
class DesignDetailsSection extends StatelessWidget {
  final TaskModel task;

  const DesignDetailsSection({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final infoBoxWidth = (Get.width * 0.7 - 550) / 6;
    final sectionWidth = Get.width * 0.7 - 450;

    return Row(
      children: [
        Container(
          height: 110,
          width: sectionWidth,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TaskDetailsDialogHelpers.infoBox(
                'العميل',
                Get.find<HomeController>().clients
                        .firstWhereOrNull(
                          (emp) => emp.id == task.clientName,
                        )
                        ?.name ??
                    '',
                width: infoBoxWidth,
                height: 110,
              ),
              _divider(),
              TaskDetailsDialogHelpers.infoBox(
                'نوع التصميم',
                task.designDetails!.taskType.tr,
                width: infoBoxWidth,
                height: 110,
              ),
              _divider(),
              TaskDetailsDialogHelpers.infoBox(
                'المنصة',
                task.designDetails!.platform.toString().tr,
                width: infoBoxWidth,
                height: 110,
              ),
              _divider(),
              TaskDetailsDialogHelpers.infoBox(
                'الاولويه',
                task.priority.tr,
                width: infoBoxWidth,
                height: 110,
                child: TaskDetailsDialogHelpers.buildTag(task.priority, tr: true),
              ),
              SizedBox(height: 25, child: _divider()),
              TaskDetailsDialogHelpers.infoBox(
                'عدد التصاميم',
                '${task.designDetails!.designCount}',
                width: infoBoxWidth,
                height: 110,
              ),
              _divider(),
              TaskDetailsDialogHelpers.infoBox(
                'القياسات',
                task.designDetails!.designsDimensions ?? '',
                width: infoBoxWidth,
                height: 110,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 110,
          width: 380,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TaskDetailsDialogHelpers.infoBoxDates(
                'تاريخ البداية',
                FunHelper.formatdate(task.fromDate),
                CupertinoIcons.calendar,
              ),
              TaskDetailsDialogHelpers.infoBoxDates(
                'تاريخ النهاية',
                FunHelper.formatdate(task.toDate),
                CupertinoIcons.calendar,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return const SizedBox(
      height: 35,
      child: VerticalDivider(color: Colors.grey, thickness: 1),
    );
  }
}
