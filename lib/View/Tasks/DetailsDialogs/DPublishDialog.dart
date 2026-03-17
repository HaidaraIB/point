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

void showPublishDialog(BuildContext context, {required TaskModel task}) {
  Responsive.isMobile(context)
      ? showTaskDetailsMobile(context, task: task)
      : showDialog(
          context: context,
          builder: (context) => GenericTaskDetailsDialog(
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
    final infoBoxWidth = (Get.width * 0.8 - 550) / 6;
    final sectionWidth = Get.width * 0.8 - 450;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  width: infoBoxWidth,
                  height: 110,
                ),
              ),
              _divider(),
              InkWell(
                onTap: () async {
                  final url = task.publishModel!.fileurl;
                  if (url != null &&
                      await canLaunchUrl(Uri.parse(url))) {
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
                  task.publishModel!.fileurl ?? '',
                  width: infoBoxWidth,
                  height: 110,
                ),
              ),
              _divider(),
              TaskDetailsDialogHelpers.infoBox(
                'المنصة',
                task.publishModel!.platform.toString().tr,
                width: infoBoxWidth,
                height: 110,
              ),
              _divider(),
              TaskDetailsDialogHelpers.infoBox(
                'الاولويه',
                (task.priority).tr,
                width: infoBoxWidth,
                height: 110,
                child: TaskDetailsDialogHelpers.buildTag(
                  task.priority,
                  tr: true,
                ),
              ),
              SizedBox(
                height: 25,
                child: _divider(),
              ),
              TaskDetailsDialogHelpers.infoBox(
                'العلامة والتصنيف',
                task.publishModel!.category,
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

/// Full-screen scaffold used in some contexts (e.g. direct navigation).
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
                        child: _infoBoxm(
                          'رابط',
                          task.publishModel!.contenturl.tr,
                        ),
                      ),
                      _infoBoxm(
                        'المنصة',
                        task.publishModel!.platform.toString().tr,
                      ),
                      _infoBoxm(
                        'الاولويه',
                        (task.priority).tr,
                        child: TaskDetailsDialogHelpers.buildTag(
                          task.priority,
                          tr: true,
                        ),
                      ),
                      _infoBoxm(
                        'العلامة والتصنيف',
                        '',
                        child: MainButton(
                          width: (Get.width * 0.4),
                          height: 25,
                          borderColor: AppColors.primaryfontColor,
                          backgroundcolor: Colors.white,
                          title: 'النشر',
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
                        child: Text(task.description),
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
