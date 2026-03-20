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
                    'العميل',
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
                        throw 'لا يمكن فتح الرابط ${task.publishModel!.contenturl}';
                      }
                    },
                    child: TaskDetailsDialogHelpers.infoBox(
                      'رابط المحتوى',
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
                        throw 'لا يمكن فتح الرابط $url';
                      }
                    },
                    child: TaskDetailsDialogHelpers.infoBox(
                      'رابط الملفات',
                      task.publishModel!.fileurl ?? '-',
                      width: cellWidth,
                      height: 110,
                    ),
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'المنصة',
                    task.publishModel!.platform.isEmpty
                        ? '-'
                        : task.publishModel!.platform
                            .map((e) => e.toString().tr)
                            .join('، '),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'القياسات',
                    task.publishModel!.designsDimensions ?? '-',
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
                  TaskDetailsDialogHelpers.infoBox(
                    'العلامة والتصنيف',
                    task.publishModel!.category.tr,
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
