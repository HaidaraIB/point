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

void showMoantageDialog(BuildContext context, {required TaskModel task}) {
  Responsive.isMobile(context)
      ? showTaskDetailsMobile(context, task: task)
      : showDialog(
        context: context,
        builder:
            (context) => GenericTaskDetailsDialog(
              task: task,
              dialogWidthFraction: 0.8,
              typeSpecificSection: MontageDetailsSection(task: task),
            ),
      );
}

/// Type-specific info section for Montage task details (web).
class MontageDetailsSection extends StatelessWidget {
  final TaskModel task;

  const MontageDetailsSection({super.key, required this.task});

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
                    'tasks.form.client_label'.tr,
                    clientName,
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.category'.tr,
                    FunHelper.trStored(task.monatageModel!.category),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'platform'.tr,
                    task.monatageModel!.platform.isEmpty
                        ? '-'
                        : FunHelper.formatStoredPlatforms(
                            task.monatageModel!.platform,
                          ),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.duration'.tr,
                    '${task.monatageModel!.duration ?? '-'}',
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.size'.tr,
                    FunHelper.trStored(task.monatageModel!.dimentioans),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.attachment_link'.tr,
                    task.monatageModel!.attachementurl ?? '-',
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.task_priority'.tr,
                    FunHelper.trStored(
                      task.priority,
                      kind: StoredValueKind.priority,
                    ),
                    width: cellWidth,
                    height: 110,
                    child: TaskDetailsDialogHelpers.buildTag(
                      FunHelper.canonicalStoredPriority(task.priority),
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
                    'task_details.date_start_task'.tr,
                    FunHelper.formatdate(task.fromDate),
                    CupertinoIcons.calendar,
                  ),
                  TaskDetailsDialogHelpers.infoBoxDates(
                    'task_details.date_end_task'.tr,
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
