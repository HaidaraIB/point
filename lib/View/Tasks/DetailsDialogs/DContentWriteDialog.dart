import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/TaskTimelineWidget.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/DetailsDialogs/GenericTaskDetailsDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:point/View/Tasks/Mobile/TaskDetailsMobile.dart';
import 'package:url_launcher/url_launcher.dart';

void showContentWriteDialog(BuildContext context, {required TaskModel task}) {
  Responsive.isMobile(context)
      ? showTaskDetailsMobile(context, task: task)
      : showDialog(
          context: context,
          builder: (context) => GenericTaskDetailsDialog(
            task: task,
            dialogWidthFraction: 0.7,
            typeSpecificSection: ContentWriteDetailsSection(task: task),
          ),
        );
}

/// Type-specific info section for ContentWrite task details (web).
class ContentWriteDetailsSection extends StatelessWidget {
  final TaskModel task;

  const ContentWriteDetailsSection({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final infoBoxWidth = (Get.width * 0.7 - 550) / 5;
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
                'نوع المحتوى',
                task.contentWriteModel!.contenttype.tr,
                width: infoBoxWidth,
                height: 110,
              ),
              _divider(),
              TaskDetailsDialogHelpers.infoBox(
                'المنصة',
                task.contentWriteModel!.platform.toString().tr,
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
                'عدد الصور',
                task.contentWriteModel!.designCount?.tr ?? '',
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

/// Full-screen scaffold used in some contexts.
class test extends StatelessWidget {
  final TaskModel task;
  test({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 35),
                PreferredSize(
                  preferredSize: Size(Get.width, 60),
                  child: Obx(
                    () => HeaderWidget(
                      employee: true,
                      name: controller.currentemployee.value?.name ?? '',
                      role: controller.currentemployee.value?.role ?? '',
                      avatarUrl:
                          controller.currentemployee.value?.image ?? kDefaultAvatarUrl,
                      notificationCount: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 35),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 23),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: Get.width * 0.9,
                        child: Text(
                          maxLines: 1,
                          task.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: Get.width * 0.9,
                        child: Text(
                          maxLines: 2,
                          task.description,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 23),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoBoxm(
                        'العميل',
                        Get.find<HomeController>().clients
                                .firstWhereOrNull(
                                  (emp) => emp.id == task.clientName,
                                )
                                ?.name ??
                            '',
                      ),
                      _infoBoxm(
                        'نوع المحتوى',
                        task.contentWriteModel!.contenttype.tr,
                      ),
                      _infoBoxm(
                        'عدد الصور',
                        task.contentWriteModel!.designCount?.tr ?? '',
                      ),
                      _infoBoxm(
                        'المنصة',
                        task.contentWriteModel!.platform.toString().tr,
                      ),
                      _infoBoxm(
                        'الاولويه',
                        task.priority.tr,
                        child: TaskDetailsDialogHelpers.buildTag(task.priority, tr: true),
                      ),
                      _infoBoxm(
                        'العلامة والتصنيف',
                        '',
                        child: MainButton(
                          width: (Get.width * 0.4),
                          height: 25,
                          borderColor: AppColors.primaryfontColor,
                          backgroundcolor: Colors.white,
                          title: 'كتابة محتوى',
                          fontcolor: AppColors.primaryfontColor,
                          fontsize: 10,
                        ),
                      ),
                      _infoBoxm(
                        'تاريخ البداية',
                        FunHelper.formatdate(task.fromDate) ?? '',
                      ),
                      _infoBoxm(
                        'تاريخ النهاية',
                        FunHelper.formatdate(task.toDate) ?? '',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 23),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المرفقات'),
                      const SizedBox(height: 10),
                      Container(
                        width: Get.width,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Wrap(
                          spacing: 16,
                          children: [
                            for (var att in task.files)
                              TaskDetailsDialogHelpers.attachmentCard(
                                FunHelper.getFileNameFromUrl(att),
                                '',
                                onDownload: () async {
                                  if (await canLaunchUrl(Uri.parse(att))) {
                                    await launchUrl(
                                      Uri.parse(att),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else {
                                    throw 'لا يمكن فتح الرابط $att';
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 23),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الملاحظات'),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        width: Get.width,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var note in task.notes)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note.note,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryfontColor,
                                    ),
                                  ),
                                  Text(
                                    note.byWho,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TaskTimelineWidget(events: task.timelineEvents),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoBoxm(String title, String value, {Widget? child}) {
    return Container(
      width: (Get.width * 0.9),
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            '$title:',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(width: 5),
          child ??
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.primaryfontColor,
                ),
              ),
        ],
      ),
    );
  }
}
