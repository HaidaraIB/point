import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/TaskTimelineWidget.dart';
import 'package:point/View/Tasks/Dialogs/ContentWriteDialog.dart';
import 'package:point/View/Tasks/Dialogs/DesignDialog.dart';
import 'package:point/View/Tasks/Dialogs/MontageDialog.dart';
import 'package:point/View/Tasks/Dialogs/PhotoGraphyDialog.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';
import 'package:point/View/Tasks/Dialogs/PromotionDialog.dart';
import 'package:point/View/Tasks/Dialogs/PublishDialog.dart';

/// Mobile-only full-screen task details. Used when opening any task type on mobile.
class TaskDetailsMobilePage extends StatelessWidget {
  final TaskModel task;

  const TaskDetailsMobilePage({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'تفاصيل المهمة'.tr,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryfontColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: Row(
                  children: [
                    _chip(task.status, _statusColor(task.status), _statusBg(task.status)),
                    const SizedBox(width: 8),
                    _chip(task.priority, _priorityColor(task.priority), _priorityBg(task.priority)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التقدم'.tr,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: task.progress ?? 0,
                      backgroundColor: Colors.grey.shade200,
                      color: AppColors.primary,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${((task.progress ?? 0) * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: NetworkImage(
                        task.assignedImageUrl.isEmpty
                            ? '${StorageKeys.supabaseStorageBaseUrl}/Avatar.png'
                            : task.assignedImageUrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _assigneeName(context),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                FunHelper.formatdate(task.fromDate) ?? '',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          Text(
                            _stillTime(task.toDate),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _stillTime(task.toDate) == 'الوقت منتهي' ? Colors.red : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: _fieldRow(
                  context,
                  'نص الإجراء',
                  task.actionText.isNotEmpty ? task.actionText : '-',
                ),
              ),
              const SizedBox(height: 12),
              _buildTypeDetailsCard(context),
              if (task.timelineEvents.isNotEmpty) ...[
                const SizedBox(height: 16),
                TaskTimelineWidget(events: task.timelineEvents),
              ],
              const SizedBox(height: 24),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _chip(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toString().tr,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _fieldRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primaryfontColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeDetailsCard(BuildContext context) {
    String listOrDash(List? list) =>
        (list == null || list.isEmpty)
            ? '-'
            : list.map((e) => e.toString().tr).join('، ');
    String dateOrDash(DateTime? d) =>
        d == null ? '-' : (FunHelper.formatdate(d) ?? '-');

    final List<Widget> fields = [];

    switch (task.type) {
      // 0: Promotion/Campaign
      case '0':
        final promo = task.promotionModel;
        String normalizeDepartmentId(String? value) {
          final v = value?.trim() ?? '';
          if (v.isEmpty) return '-';
          final match = RegExp(r'^c(\d+)$').firstMatch(v);
          if (match != null) {
            return 'cat${match.group(1)}';
          }
          return v;
        }

        String displayPromoName(String? value) {
          final v = value?.trim() ?? '';
          if (v.isEmpty) return '-';
          return v.tr;
        }

        String displayCampaignName(String? value) {
          final v = value?.trim() ?? '';
          if (v.isEmpty) return '-';
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
          return v.tr;
        }

        String displayPromoStatus(String? value) {
          final v = value?.trim() ?? '';
          if (v.isEmpty) return '-';
          if (v == 'status') return 'status'.tr;
          return v.tr;
        }

        String displayTarget(String? value) {
          final v = value?.trim() ?? '';
          if (v.isEmpty) return '-';
          return v.tr;
        }

        fields.add(
          _fieldRow(context, 'اسم المهمة', displayPromoName(promo?.name)),
        );
        fields.add(_fieldRow(context, 'الهدف', displayTarget(promo?.target)));
        fields.add(
          _fieldRow(
            context,
            'اسم الحملة',
            displayCampaignName(promo?.campaignName),
          ),
        );
        fields.add(
          _fieldRow(context, 'نوع المهمة', displayPromoType(promo?.type)),
        );
        fields.add(
          _fieldRow(
            context,
            'أولوية المهمة',
            displayPromoPriority(promo?.priority),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'حالة المهمة',
            displayPromoStatus(promo?.status),
          ),
        );
        fields.add(_fieldRow(context, 'وصف المهمة', promo?.description ?? '-'));
        fields.add(
          _fieldRow(
            context,
            'منفذ المهمة',
            normalizeDepartmentId(promo?.executorId).tr,
          ),
        );
        fields.add(_fieldRow(context, 'تاريخ البداية', dateOrDash(promo?.startDate)));
        fields.add(_fieldRow(context, 'تاريخ النهاية', dateOrDash(promo?.endDate)));
        fields.add(_fieldRow(context, 'المدة', promo?.duration ?? '-'));
        fields.add(_fieldRow(context, 'العلامات', promo?.tags ?? '-'));
        fields.add(
          _fieldRow(context, 'المنصة', listOrDash(promo?.platforms)),
        );
        fields.add(_fieldRow(context, 'الاهتمامات', listOrDash(promo?.interests)));
        fields.add(_fieldRow(context, 'المدن', listOrDash(promo?.cities)));
        fields.add(_fieldRow(context, 'الدول', listOrDash(promo?.countries)));
        fields.add(
          _fieldRow(
            context,
            'مجالات الاختصاص',
            listOrDash(promo?.specializations),
          ),
        );
        fields.add(_fieldRow(context, 'الفئات العمرية', promo?.ageRanges ?? '-'));
        fields.add(
          _fieldRow(
            context,
            'تفاصيل إضافية (بيانات JSON)',
            promo?.customDetails == null ? '-' : jsonEncode(promo!.customDetails),
          ),
        );
        fields.add(_fieldRow(context, 'الملاحظات', promo?.notes ?? '-'));
        fields.add(_fieldRow(context, 'رابط الملفات', promo?.attachementurl ?? '-'));
        fields.add(
          _fieldRow(
            context,
            'تاريخ الإنشاء',
            promo == null ? '-' : dateOrDash(promo.createdAt),
          ),
        );
        break;

      // 1: Design
      case '1':
        final m = task.designDetails;
        fields.add(_fieldRow(context, 'نوع المهمة', m?.taskType.tr ?? '-'));
        fields.add(_fieldRow(context, 'نوع التصميم', m?.designType.tr ?? '-'));
        fields.add(
          _fieldRow(
            context,
            'المنصة',
            listOrDash(m?.platform.cast<String>().toList()),
          ),
        );
        fields.add(_fieldRow(context, 'عدد التصاميم', m?.designCount ?? '-'));
        fields.add(
          _fieldRow(context, 'القياسات', m?.designsDimensions ?? '-'),
        );
        break;

      // 2: Photography
      case '2':
        final m = task.photoGrapghyModel;
        fields.add(_fieldRow(context, 'الهدف', m?.shootingtype.tr ?? '-'));
        fields.add(
          _fieldRow(
            context,
            'المنصة',
            listOrDash(m?.platform.cast<String>().toList()),
          ),
        );
        fields.add(_fieldRow(context, 'نوع التصوير', m?.shootinglocation.tr ?? '-'));
        fields.add(_fieldRow(context, 'عدد الصور او الفيديو', m?.designCount ?? '-'));
        fields.add(_fieldRow(context, 'المدة', m?.duration ?? '-'));
        break;

      // 3: ContentWrite
      case '3':
        final m = task.contentWriteModel;
        fields.add(_fieldRow(context, 'نوع المحتوى', m?.contenttype.tr ?? '-'));
        fields.add(
          _fieldRow(
            context,
            'المنصة',
            listOrDash(m?.platform.cast<String>().toList()),
          ),
        );
        fields.add(_fieldRow(context, 'عدد الصور', m?.designCount ?? '-'));
        fields.add(_fieldRow(context, 'القياسات', m?.designsDimensions ?? '-'));
        break;

      // 4: Montage
      case '4':
        final m = task.monatageModel;
        fields.add(_fieldRow(context, 'التصنيف', m?.category.tr ?? '-'));
        fields.add(
          _fieldRow(
            context,
            'المنصة',
            listOrDash(m?.platform.cast<String>().toList()),
          ),
        );
        fields.add(_fieldRow(context, 'المقاسات', m?.dimentioans ?? '-'));
        fields.add(_fieldRow(context, 'رابط المرفق', m?.attachementurl ?? '-'));
        fields.add(_fieldRow(context, 'المدة', m?.duration ?? '-'));
        break;

      // 5: Publish
      case '5':
        final m = task.publishModel;
        fields.add(_fieldRow(context, 'رابط المحتوى', m?.contenturl ?? '-'));
        fields.add(
          _fieldRow(
            context,
            'المنصة',
            listOrDash(m?.platform.cast<String>().toList()),
          ),
        );
        fields.add(_fieldRow(context, 'التصنيف', m?.category ?? '-'));
        fields.add(_fieldRow(context, 'رابط الملفات', m?.fileurl ?? '-'));
        fields.add(_fieldRow(context, 'القياسات', m?.designsDimensions ?? '-'));
        break;

      // 6: Programming
      case '6':
        final m = task.programmingModel;
        fields.add(_fieldRow(context, 'رابط المحتوى', m?.contenturl ?? '-'));
        fields.add(_fieldRow(context, 'التصنيف', m?.category ?? '-'));
        fields.add(_fieldRow(context, 'رابط الملفات', m?.fileurl ?? '-'));
        fields.add(_fieldRow(context, 'القياسات', m?.designsDimensions ?? '-'));
        break;

      default:
        fields.add(_fieldRow(context, 'تفاصيل القسم', '-'));
    }

    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل القسم'.tr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          ...fields,
        ],
      ),
    );
  }

  String _assigneeName(BuildContext context) {
    final controller = Get.find<HomeController>();
    final emp = controller.employees.firstWhereOrNull(
          (e) => e.id == task.assignedTo,
        );
    return emp?.name ?? task.clientName;
  }

  String _stillTime(DateTime endDate) {
    final diff = endDate.difference(DateTime.now());
    if (diff.isNegative) return 'الوقت منتهي';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final parts = <String>[];
    if (d > 0) parts.add('$d يوم');
    if (h > 0) parts.add('$h ساعة');
    if (m > 0) parts.add('$m دقيقة');
    return parts.join(' ').trim().isEmpty ? 'الآن' : parts.join(' ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case StorageKeys.status_under_revision:
        return Colors.blue;
      case StorageKeys.status_approved:
        return Colors.green;
      case StorageKeys.status_rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case StorageKeys.status_under_revision:
        return Colors.blue.shade50;
      case StorageKeys.status_approved:
        return Colors.green.shade50;
      case StorageKeys.status_rejected:
        return Colors.red.shade50;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'normal':
        return Colors.blue;
      case 'imp':
        return Colors.orange;
      case 'veryimp':
        return Colors.red;
      case 'veryveryimp':
        return Colors.red.shade900;
      default:
        return Colors.green;
    }
  }

  Color _priorityBg(String priority) {
    switch (priority) {
      case 'normal':
        return Colors.blue.shade50;
      case 'imp':
        return Colors.orange.shade50;
      case 'veryimp':
        return Colors.red.shade50;
      case 'veryveryimp':
        return Colors.red.shade100;
      default:
        return Colors.green.shade50;
    }
  }

  Widget _buildActions(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          label: const Text('إغلاق'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openEditDialog(context, task),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('طلب تعديل'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  FunHelper.showConfirmDailog(
                    context,
                    title: 'تأكيد الرفض',
                    message: 'هل أنت متأكد من رفض هذه المهمة؟',
                    confirmText: 'رفض',
                    confirmColor: Colors.red,
                    onTap: () async {
                      await controller.updateTask(
                        task.copyWith(status: StorageKeys.status_rejected),
                      );
                      Get.back();
                    },
                  );
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('رفض'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  FunHelper.showConfirmDailog(
                    context,
                    title: 'تأكيد القبول',
                    message: 'هل أنت متأكد من قبول هذه المهمة؟',
                    confirmText: 'قبول',
                    confirmColor: Colors.green,
                    onTap: () async {
                      await controller.updateTask(
                        task.copyWith(status: StorageKeys.status_approved),
                      );
                      Get.back();
                    },
                  );
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('قبول'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            FunHelper.showConfirmDailog(
              context,
              title: 'تأكيد الحذف',
              message: 'هل أنت متأكد من حذف هذه المهمة؟',
              confirmText: 'حذف',
              confirmColor: Colors.red,
              onTap: () async {
                await controller.deleteTask(task.id!);
                Get.back();
              },
            );
          },
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('حذف'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  void _openEditDialog(BuildContext context, TaskModel task) {
    Get.find<HomeController>().uploadedFilesPaths.clear();
    switch (task.type) {
      case '0':
        showPromotionDialog(context, model: task);
        break;
      case '1':
        designDialog(context, model: task);
        break;
      case '2':
        photoGraphyDialog(context, model: task);
        break;
      case '3':
        contentWriteDiloag(context, model: task);
        break;
      case '4':
        montageDiloag(context, model: task);
        break;
      case '5':
        publishDilaog(context, model: task);
        break;
      case '6':
        programmingDiloag(context, model: task);
        break;
      default:
        break;
    }
  }
}

/// Call this from any showXDetailsDialog when Responsive.isMobile(context).
/// Desktop/tablet keep using showDialog; only mobile uses this screen.
void showTaskDetailsMobile(BuildContext context, {required TaskModel task}) {
  Get.to(() => TaskDetailsMobilePage(task: task));
}
