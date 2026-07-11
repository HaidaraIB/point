import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/AdministrationTaskModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/DetailsDialogs/GenericTaskDetailsDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:point/View/Tasks/Mobile/TaskDetailsMobile.dart';
import 'package:point/Utils/app_theme_extension.dart';

void showAdministrativeTaskDetailsDialog(
  BuildContext context, {
  required TaskModel task,
}) {
  Responsive.isMobile(context)
      ? showTaskDetailsMobile(context, task: task)
      : showDialog(
        context: context,
        builder:
            (context) => GenericTaskDetailsDialog(
              task: task,
              dialogWidthFraction: 0.7,
              typeSpecificSection: AdministrationDetailsSection(task: task),
            ),
      );
}

/// Type-specific section for administration tasks (web).
class AdministrationDetailsSection extends StatelessWidget {
  final TaskModel task;

  const AdministrationDetailsSection({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final clientName =
        Get.find<HomeController>().clients
            .firstWhereOrNull((emp) => emp.id == task.clientName)
            ?.name ??
        task.clientName;

    final extra = task.administrationModel?.extra ?? const {};
    final aboutRaw = extra[AdministrationTaskModel.kAboutTaskKey];
    final aboutText = aboutRaw?.toString().trim() ?? '';

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
              color: context.appTheme.cardSurface,
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
                  ...extra.entries
                      .where((e) => e.key != AdministrationTaskModel.kAboutTaskKey)
                      .map(
                        (e) => TaskDetailsDialogHelpers.infoBox(
                          e.key,
                          e.value?.toString() ?? '',
                          width: cellWidth,
                          height: 110,
                        ),
                      ),
                ],
              ),
            ),
            if (aboutText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
              color: context.appTheme.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'task_details.about_task'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      aboutText,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTheme.mutedText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(minHeight: 110),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
              color: context.appTheme.cardSurface,
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
