import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/DetailsDialogs/GenericTaskDetailsDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:point/View/Tasks/Mobile/TaskDetailsMobile.dart';

void showCampaignDetailsDialog(
  BuildContext context, {
  required TaskModel task,
}) {
  Responsive.isMobile(context)
      ? showTaskDetailsMobile(context, task: task)
      : showDialog(
          context: context,
          builder: (context) => GenericTaskDetailsDialog(
            task: task,
            dialogWidthFraction: 0.9,
            typeSpecificSection: PromotionDetailsSection(task: task),
          ),
        );
}

/// Type-specific info section for Promotion/Campaign task details (web).
class PromotionDetailsSection extends StatelessWidget {
  final TaskModel task;

  const PromotionDetailsSection({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final infoBoxWidth = (Get.width * 0.9 - 550) / 5;
    final sectionWidth = Get.width * 0.9 - 450;

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
                'الهدف ',
                task.promotionModel!.target.tr,
                width: infoBoxWidth,
                height: 110,
              ),
              _divider(),
              TaskDetailsDialogHelpers.infoBox(
                'المنصة',
                task.promotionModel!.platforms.toString().tr,
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
                'العلامة والتصنيف',
                task.promotionModel!.tags.toString().tr,
                width: infoBoxWidth,
                height: 110,
                child: MainButton(
                  width: (Get.width * 0.9 - 550) / 5,
                  height: 25,
                  borderColor: AppColors.primaryfontColor,
                  backgroundcolor: Colors.white,
                  title: 'اضافة علامة',
                  fontcolor: AppColors.primaryfontColor,
                  fontsize: 10,
                ),
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
