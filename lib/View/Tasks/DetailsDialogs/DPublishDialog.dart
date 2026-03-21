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
import 'package:url_launcher/url_launcher.dart';

void showPublishDialog(BuildContext context, {required TaskModel task}) {
  Responsive.isMobile(context)
      ? showTaskDetailsMobile(context, task: task)
      : showDialog(
        context: context,
        builder:
            (context) => GenericTaskDetailsDialog(
              task: task,
              dialogWidthFraction: 0.8,
              typeSpecificSection: PublishDetailsSection(task: task),
            ),
      );
}

/// Type-specific info section for Publish task details (web).
class PublishDetailsSection extends StatelessWidget {
  final TaskModel task;

  const PublishDetailsSection({super.key, required this.task});

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
                  InkWell(
                    onTap: () async {
                      if (await canLaunchUrl(
                        Uri.parse(task.publishModel!.contenturl),
                      )) {
                        await launchUrl(
                          Uri.parse(task.publishModel!.contenturl),
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        FunHelper.showsnackbar(
                          'error'.tr,
                          'errors.cannot_open_link_param'.trParams({
                            'url': task.publishModel!.contenturl,
                          }),
                        );
                      }
                    },
                    child: TaskDetailsDialogHelpers.infoBox(
                      'task_details.content_link'.tr,
                      task.publishModel!.contenturl,
                      width: cellWidth,
                      height: 110,
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final url = task.publishModel!.fileurl;
                      if (url != null && await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        FunHelper.showsnackbar(
                          'error'.tr,
                          'errors.cannot_open_link_param'.trParams({
                            'url': url ?? '',
                          }),
                        );
                      }
                    },
                    child: TaskDetailsDialogHelpers.infoBox(
                      'task_details.files_link'.tr,
                      task.publishModel!.fileurl ?? '-',
                      width: cellWidth,
                      height: 110,
                    ),
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'platform'.tr,
                    task.publishModel!.platform.isEmpty
                        ? '-'
                        : FunHelper.formatStoredPlatforms(
                            task.publishModel!.platform,
                          ),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.dimensions'.tr,
                    task.publishModel!.designsDimensions ?? '-',
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
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.category'.tr,
                    FunHelper.trStored(task.publishModel!.category),
                    width: cellWidth,
                    height: 110,
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
