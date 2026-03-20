import 'dart:convert';

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

void showCampaignDetailsDialog(
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
    final promo = task.promotionModel!;
    final clientName =
        Get.find<HomeController>().clients
            .firstWhereOrNull((emp) => emp.id == task.clientName)
            ?.name ??
        task.clientName;

    String normalizeDepartmentId(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return '-';
      // Sometimes data is stored like `c2` instead of `cat2`.
      final match = RegExp(r'^c(\d+)$').firstMatch(v);
      if (match != null) {
        return 'cat${match.group(1)}';
      }
      return v;
    }

    String displayPromoName(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return '-';
      // In some records it is stored as the translation key `name`.
      return v.tr;
    }

    String displayCampaignName(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return '-';
      // AppTranslations uses `campainname` (typo) not `campaignName`.
      if (v == 'campaignName') return 'campainname'.tr;
      return v.tr;
    }

    String displayPromoType(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return '-';
      if (v == 'type') return 'promotion'.tr;
      return v.tr;
    }

    String displayPromoPriority(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return '-';
      // If stored as placeholder `priority`, translate to the dropdown label.
      if (v == 'priority' || v == 'priortity') return 'priortity'.tr;
      return v.tr;
    }

    String displayPromoStatus(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return '-';
      if (v == 'status') return 'status'.tr;
      return v.tr;
    }

    final taskPriorityForTag =
        task.priority.trim() == 'priority' ? 'priortity' : task.priority;

    String listOrDash(List? list) =>
        (list == null || list.isEmpty)
            ? '-'
            : list.map((e) => e.toString().tr).join('، ');

    String dateOrDash(DateTime? d) =>
        d == null ? '-' : (FunHelper.formatdate(d) ?? '-');

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final cellWidth = TaskDetailsDialogHelpers.gridCellWidth(maxW);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1) معلومات أساسية
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
                    'اسم المهمة',
                    displayPromoName(promo.name),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'اسم الحملة',
                    displayCampaignName(promo.campaignName),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'نوع المهمة',
                    displayPromoType(promo.type),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'الهدف',
                    promo.target.trim().isEmpty ? '-' : promo.target.tr,
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'المنصة',
                    listOrDash(promo.platforms),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'العلامات',
                    promo.tags ?? '-',
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'أولوية المهمة',
                    task.priority,
                    width: cellWidth,
                    height: 110,
                    child: TaskDetailsDialogHelpers.buildTag(
                      taskPriorityForTag,
                      tr: true,
                    ),
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'أولوية الحملة',
                    displayPromoPriority(promo.priority),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'حالة الحملة',
                    displayPromoStatus(promo.status),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'منفذ المهمة',
                    normalizeDepartmentId(promo.executorId).tr,
                    width: cellWidth,
                    height: 110,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 2) الجمهور
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
                    'الاهتمامات',
                    listOrDash(promo.interests),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'المدن',
                    listOrDash(promo.cities),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'الدول',
                    listOrDash(promo.countries),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'مجالات الاختصاص',
                    listOrDash(promo.specializations),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'الفئات العمرية',
                    promo.ageRanges ?? '-',
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'المدة',
                    promo.duration ?? '-',
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'وصف الحملة',
                    promo.description ?? '-',
                    width: cellWidth,
                    height: 110,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3) التواريخ + التفاصيل
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    runSpacing: 8,
                    children: [
                      TaskDetailsDialogHelpers.infoBoxDates(
                        'تاريخ البداية (المهمة)',
                        FunHelper.formatdate(task.fromDate),
                        CupertinoIcons.calendar,
                      ),
                      TaskDetailsDialogHelpers.infoBoxDates(
                        'تاريخ النهاية (المهمة)',
                        FunHelper.formatdate(task.toDate),
                        CupertinoIcons.calendar,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      TaskDetailsDialogHelpers.infoBox(
                        'تاريخ البداية (الحملة)',
                        dateOrDash(promo.startDate),
                        width: cellWidth,
                        height: 110,
                      ),
                      TaskDetailsDialogHelpers.infoBox(
                        'تاريخ النهاية (الحملة)',
                        dateOrDash(promo.endDate),
                        width: cellWidth,
                        height: 110,
                      ),
                      TaskDetailsDialogHelpers.infoBox(
                        'تاريخ الإنشاء',
                        dateOrDash(promo.createdAt),
                        width: cellWidth,
                        height: 110,
                      ),
                      TaskDetailsDialogHelpers.infoBox(
                        'رابط الملفات',
                        promo.attachementurl ?? '-',
                        width: cellWidth,
                        height: 110,
                      ),
                      TaskDetailsDialogHelpers.infoBox(
                        'الملاحظات',
                        promo.notes ?? '-',
                        width: cellWidth,
                        height: 110,
                      ),
                      TaskDetailsDialogHelpers.infoBox(
                        'تفاصيل إضافية (بيانات JSON)',
                        promo.customDetails == null
                            ? '-'
                            : jsonEncode(promo.customDetails),
                        width: cellWidth,
                        height: 110,
                      ),
                    ],
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
