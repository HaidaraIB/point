import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
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
      final match = RegExp(r'^c(\d+)$').firstMatch(v);
      if (match != null) {
        final legacyIndex = int.tryParse(match.group(1) ?? '');
        if (legacyIndex != null &&
            legacyIndex > 0 &&
            legacyIndex <= StorageKeys.departmentSlugs.length) {
          return StorageKeys.departmentSlugs[legacyIndex - 1];
        }
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
      if (v == 'priority' || v == 'priortity') return 'priortity'.tr;
      return FunHelper.trStored(v, kind: StoredValueKind.priority);
    }

    String displayPromoStatus(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return '-';
      if (v == 'status') return 'status'.tr;
      return FunHelper.trStored(v, kind: StoredValueKind.taskStatus);
    }

    String listOrDash(
      dynamic list, {
      StoredValueKind kind = StoredValueKind.generic,
    }) {
      final ar = (Get.locale?.languageCode ?? 'ar') == 'ar';
      return FunHelper.joinStoredListForDisplay(
        list,
        kind: kind,
        localeIsArabic: ar,
      );
    }

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
                    'tasks.form.client_label'.tr,
                    clientName,
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.task_title'.tr,
                    displayPromoName(promo.name),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.campaign_name'.tr,
                    displayCampaignName(promo.campaignName),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.task_type'.tr,
                    displayPromoType(promo.type),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.objective'.tr,
                    promo.target.trim().isEmpty
                        ? '-'
                        : FunHelper.trStored(promo.target),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'platform'.tr,
                    listOrDash(
                      promo.platforms,
                      kind: StoredValueKind.platform,
                    ),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.marketing_tags'.tr,
                    promo.tags ?? '-',
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
                    'task_details.campaign_priority'.tr,
                    displayPromoPriority(promo.priority),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.campaign_status'.tr,
                    displayPromoStatus(promo.status),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.task_executor'.tr,
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
                    'task_details.interests'.tr,
                    listOrDash(promo.interests),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.cities'.tr,
                    listOrDash(promo.cities),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.countries'.tr,
                    listOrDash(promo.countries),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.specializations'.tr,
                    listOrDash(promo.specializations),
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.age_ranges'.tr,
                    promo.ageRanges ?? '-',
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.duration'.tr,
                    promo.duration ?? '-',
                    width: cellWidth,
                    height: 110,
                  ),
                  TaskDetailsDialogHelpers.infoBox(
                    'task_details.campaign_description'.tr,
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      TaskDetailsDialogHelpers.infoBox(
                        'task_details.date_start_campaign'.tr,
                        dateOrDash(promo.startDate),
                        width: cellWidth,
                        height: 110,
                      ),
                      TaskDetailsDialogHelpers.infoBox(
                        'task_details.date_end_campaign'.tr,
                        dateOrDash(promo.endDate),
                        width: cellWidth,
                        height: 110,
                      ),
                      TaskDetailsDialogHelpers.infoBox(
                        'task_details.created_at'.tr,
                        dateOrDash(promo.createdAt),
                        width: cellWidth,
                        height: 110,
                      ),
                      TaskDetailsDialogHelpers.infoBox(
                        'task_details.files_link'.tr,
                        promo.attachementurl ?? '-',
                        width: cellWidth,
                        height: 110,
                      ),
                      TaskDetailsDialogHelpers.infoBox(
                        'notes'.tr,
                        promo.notes ?? '-',
                        width: cellWidth,
                        height: 110,
                      ),
                      TaskDetailsDialogHelpers.infoBox(
                        'task_details.custom_json'.tr,
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
