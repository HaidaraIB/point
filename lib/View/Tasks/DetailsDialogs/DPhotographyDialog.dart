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

void showDPhotographyDialog(BuildContext context, {required TaskModel task}) {
  Responsive.isMobile(context)
      ? showTaskDetailsMobile(context, task: task)
      : showDialog(
        context: context,
        builder:
            (context) => GenericTaskDetailsDialog(
              task: task,
              dialogWidthFraction: 0.9,
              typeSpecificSection: PhotographyDetailsSection(task: task),
            ),
      );
}

/// Type-specific info section for Photography task details (web).
class PhotographyDetailsSection extends StatelessWidget {
  final TaskModel task;

  const PhotographyDetailsSection({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final clientName =
        Get.find<HomeController>().clients
            .firstWhereOrNull((emp) => emp.id == task.clientName)
            ?.name ??
        task.clientName;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final cellWidth = TaskDetailsDialogHelpers.gridCellWidth(maxW);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  TaskDetailsDialogHelpers.infoBox(
                    'العميل',
                    clientName,
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'الهدف ',
                    task.photoGrapghyModel!.shootingtype.tr,
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'نوع التصوير',
                    task.photoGrapghyModel!.shootinglocation.toString().tr,
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'عدد الصور او الفديو',
                    '${task.photoGrapghyModel!.designCount ?? '-'}',
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'المنصة',
                    task.photoGrapghyModel!.platform.isEmpty
                        ? '-'
                        : task.photoGrapghyModel!.platform
                            .map((e) => e.toString().tr)
                            .join('، '),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'المدة',
                    '${task.photoGrapghyModel!.duration ?? '-'}',
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'الاولويه',
                    task.priority.tr,
                    width: cellWidth,
                    height: 110,
                    child: TaskDetailsDialogHelpers.buildTag(
                      task.priority,
                      tr: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(minHeight: 110),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                runSpacing: 8,
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
      },
    );
  }
}
