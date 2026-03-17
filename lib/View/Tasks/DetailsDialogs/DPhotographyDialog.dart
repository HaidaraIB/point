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
          builder: (context) => GenericTaskDetailsDialog(
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const datesWidth = 380.0;
        const gap = 10.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                height: 110,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TaskDetailsDialogHelpers.infoBox(
                        'العميل',
                        Get.find<HomeController>().clients
                                .firstWhereOrNull(
                                  (emp) => emp.id == task.clientName,
                                )
                                ?.name ??
                            '',
                        height: 110,
                      ),
                    ),
                    _divider(),
                    Expanded(
                      child: TaskDetailsDialogHelpers.infoBox(
                        'الهدف ',
                        task.photoGrapghyModel!.shootingtype.tr,
                        height: 110,
                      ),
                    ),
                    _divider(),
                    Expanded(
                      child: TaskDetailsDialogHelpers.infoBox(
                        'نوع التصوير',
                        task.photoGrapghyModel!.shootinglocation.toString().tr,
                        height: 110,
                      ),
                    ),
                    _divider(),
                    Expanded(
                      child: TaskDetailsDialogHelpers.infoBox(
                        'عدد الصور او الفديو',
                        task.photoGrapghyModel!.designCount.toString().tr,
                        height: 110,
                      ),
                    ),
                    _divider(),
                    Expanded(
                      child: TaskDetailsDialogHelpers.infoBox(
                        'الاولويه',
                        task.priority.tr,
                        height: 110,
                        child: TaskDetailsDialogHelpers.buildTag(task.priority, tr: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: gap),
            Container(
              height: 110,
              width: datesWidth,
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
      },
    );
  }

  Widget _divider() {
    return const SizedBox(
      height: 35,
      child: VerticalDivider(color: Colors.grey, thickness: 1),
    );
  }
}
