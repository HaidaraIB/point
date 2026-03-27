import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/TaskTimelineWidget.dart';
import 'package:point/View/Tasks/Dialogs/ContentWriteDialog.dart';
import 'package:point/View/Tasks/Dialogs/DesignDialog.dart';
import 'package:point/View/Tasks/Dialogs/MontageDialog.dart';
import 'package:point/View/Tasks/Dialogs/PhotographyDialog.dart';
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
          'tasks.dialog_title'.tr,
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
                    _chip(
                      FunHelper.trStored(
                        task.status,
                        kind: StoredValueKind.taskStatus,
                      ),
                      _statusColor(
                        FunHelper.canonicalStoredStatus(task.status),
                      ),
                      _statusBg(
                        FunHelper.canonicalStoredStatus(task.status),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      FunHelper.trStored(
                        task.priority,
                        kind: StoredValueKind.priority,
                      ),
                      _priorityColor(
                        FunHelper.canonicalStoredPriority(task.priority),
                      ),
                      _priorityBg(
                        FunHelper.canonicalStoredPriority(task.priority),
                      ),
                    ),
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
                      'tasks.progress_label'.tr,
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
                          Builder(
                            builder: (_) {
                              final t = _stillTime(task.toDate);
                              return Text(
                                t,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: t == 'tasks.deadline_expired'.tr
                                      ? Colors.red
                                      : Colors.grey.shade600,
                                ),
                              );
                            },
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
                  'tasks.action_text_label'.tr,
                  task.actionText.isNotEmpty ? task.actionText : '-',
                ),
              ),
              const SizedBox(height: 12),
              _buildTypeDetailsCard(context),
              const SizedBox(height: 12),
              _buildLatestCommentCard(context),
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
        text,
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
    String listOrDash(
      List? list, {
      StoredValueKind kind = StoredValueKind.generic,
    }) =>
        (list == null || list.isEmpty)
            ? '-'
            : list
                .map((e) => FunHelper.trStored(e.toString(), kind: kind))
                .join('، ');
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
          return FunHelper.trStored(v, kind: StoredValueKind.priority);
        }

        String displayPromoStatus(String? value) {
          final v = value?.trim() ?? '';
          if (v.isEmpty) return '-';
          if (v == 'status') return 'status'.tr;
          return FunHelper.trStored(v, kind: StoredValueKind.taskStatus);
        }

        String displayTarget(String? value) {
          final v = value?.trim() ?? '';
          if (v.isEmpty) return '-';
          return FunHelper.trStored(v);
        }

        fields.add(
          _fieldRow(
            context,
            'task_details.task_title'.tr,
            displayPromoName(promo?.name),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.objective'.tr,
            displayTarget(promo?.target),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.campaign_name'.tr,
            displayCampaignName(promo?.campaignName),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.task_type'.tr,
            displayPromoType(promo?.type),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.task_priority'.tr,
            displayPromoPriority(promo?.priority),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.task_status_field'.tr,
            displayPromoStatus(promo?.status),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.task_description'.tr,
            promo?.description ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.task_executor'.tr,
            normalizeDepartmentId(promo?.executorId).tr,
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'startat'.tr,
            dateOrDash(promo?.startDate),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'endat'.tr,
            dateOrDash(promo?.endDate),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.duration'.tr,
            promo?.duration ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.marketing_tags'.tr,
            promo?.tags ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'platform'.tr,
            listOrDash(
              promo?.platforms,
              kind: StoredValueKind.platform,
            ),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.interests'.tr,
            listOrDash(promo?.interests),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.cities'.tr,
            listOrDash(promo?.cities),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.countries'.tr,
            listOrDash(promo?.countries),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.specializations'.tr,
            listOrDash(promo?.specializations),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.age_ranges'.tr,
            promo?.ageRanges ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.custom_json'.tr,
            promo?.customDetails == null ? '-' : jsonEncode(promo!.customDetails),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'notes'.tr,
            promo?.notes ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.files_link'.tr,
            promo?.attachementurl ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.created_at'.tr,
            promo == null ? '-' : dateOrDash(promo.createdAt),
          ),
        );
        break;

      // 1: Design
      case '1':
        final m = task.designDetails;
        fields.add(
          _fieldRow(
            context,
            'task_details.task_type'.tr,
            m == null
                ? '-'
                : FunHelper.trStored(m.taskType),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.design_type'.tr,
            m == null
                ? '-'
                : FunHelper.trStored(m.designType),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'platform'.tr,
            listOrDash(
              m?.platform.cast<String>().toList(),
              kind: StoredValueKind.platform,
            ),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.design_count'.tr,
            m?.designCount ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.dimensions'.tr,
            m?.designsDimensions ?? '-',
          ),
        );
        break;

      // 2: Photography
      case '2':
        final m = task.photoGrapghyModel;
        fields.add(
          _fieldRow(
            context,
            'task_details.objective'.tr,
            m == null
                ? '-'
                : FunHelper.trStored(m.shootingtype),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'platform'.tr,
            listOrDash(
              m?.platform.cast<String>().toList(),
              kind: StoredValueKind.platform,
            ),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.shooting_type'.tr,
            m == null
                ? '-'
                : FunHelper.trStored(m.shootinglocation.toString()),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.photo_video_count'.tr,
            m?.designCount ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.duration'.tr,
            m?.duration ?? '-',
          ),
        );
        break;

      // 3: ContentWrite
      case '3':
        final m = task.contentWriteModel;
        fields.add(
          _fieldRow(
            context,
            'task_details.content_type'.tr,
            m == null
                ? '-'
                : FunHelper.trStored(m.contenttype),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'platform'.tr,
            listOrDash(
              m?.platform.cast<String>().toList(),
              kind: StoredValueKind.platform,
            ),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.photo_count'.tr,
            m?.designCount ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.dimensions'.tr,
            m?.designsDimensions ?? '-',
          ),
        );
        break;

      // 4: Montage
      case '4':
        final m = task.monatageModel;
        fields.add(
          _fieldRow(
            context,
            'task_details.category'.tr,
            m == null ? '-' : FunHelper.trStored(m.category),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'platform'.tr,
            listOrDash(
              m?.platform.cast<String>().toList(),
              kind: StoredValueKind.platform,
            ),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.size'.tr,
            m == null
                ? '-'
                : FunHelper.trStored(m.dimentioans),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.attachment_link'.tr,
            m?.attachementurl ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.duration'.tr,
            m?.duration ?? '-',
          ),
        );
        break;

      // 5: Publish
      case '5':
        final m = task.publishModel;
        fields.add(
          _fieldRow(
            context,
            'task_details.content_link'.tr,
            m?.contenturl ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'platform'.tr,
            listOrDash(
              m?.platform.cast<String>().toList(),
              kind: StoredValueKind.platform,
            ),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.category'.tr,
            m == null ? '-' : FunHelper.trStored(m.category),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.files_link'.tr,
            m?.fileurl ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.dimensions'.tr,
            m?.designsDimensions ?? '-',
          ),
        );
        break;

      // 6: Programming
      case '6':
        final m = task.programmingModel;
        fields.add(
          _fieldRow(
            context,
            'task_details.content_link'.tr,
            m?.contenturl ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.category'.tr,
            m == null ? '-' : FunHelper.trStored(m.category),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.files_link'.tr,
            m?.fileurl ?? '-',
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.dimensions'.tr,
            m?.designsDimensions ?? '-',
          ),
        );
        break;

      default:
        fields.add(
          _fieldRow(context, 'task_details.section_fallback'.tr, '-'),
        );
    }

    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tasks.section_details'.tr,
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

  Widget _buildLatestCommentCard(BuildContext context) {
    final latestNote = task.notes.isNotEmpty ? task.notes.last : null;
    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tasks.latest_comment'.tr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          if (latestNote == null)
            Text(
              'tasks.no_comments_yet'.tr,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            )
          else ...[
            SelectableText(
              latestNote.note,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primaryfontColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _buildNoteMeta(latestNote.byWho, latestNote.timestamp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
    if (diff.isNegative) return 'tasks.deadline_expired'.tr;
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final parts = <String>[];
    if (d > 0) parts.add('tasks.time_days'.trParams({'count': '$d'}));
    if (h > 0) parts.add('tasks.time_hours'.trParams({'count': '$h'}));
    if (m > 0) parts.add('tasks.time_minutes'.trParams({'count': '$m'}));
    return parts.join(' ').trim().isEmpty ? 'common.now'.tr : parts.join(' ');
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

  String _buildNoteMeta(String author, DateTime timestamp) {
    final safeAuthor = author.trim().isEmpty
        ? 'content.dialog.unknown'.tr
        : author.trim();
    return '$safeAuthor • ${_formatRelativeTime(timestamp)}';
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 60) return 'common.now'.tr;
    if (diff.inMinutes < 60) {
      return 'time.ago_minutes'.trParams({'count': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'time.ago_hours'.trParams({'count': '${diff.inHours}'});
    }
    if (diff.inDays < 30) {
      return 'time.ago_days'.trParams({'count': '${diff.inDays}'});
    }
    final months = (diff.inDays / 30).floor();
    if (months < 12) {
      return 'time.ago_months'.trParams({'count': '$months'});
    }
    final years = (months / 12).floor();
    return 'time.ago_years'.trParams({'count': '$years'});
  }

  Widget _buildActions(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          label: Text(AppLocaleKeys.appClose.tr),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openEditDialog(context, task),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text('tasks.request_edit'.tr),
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
                    title: 'tasks.confirm_reject_title'.tr,
                    message: 'tasks.confirm_reject_message'.tr,
                    confirmText: 'tasks.reject'.tr,
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
                label: Text('tasks.reject'.tr),
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
                    title: 'tasks.confirm_accept_title'.tr,
                    message: 'tasks.confirm_accept_message'.tr,
                    confirmText: 'tasks.accept'.tr,
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
                label: Text('tasks.accept'.tr),
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
              title: 'tasks.confirm_delete_title'.tr,
              message: 'tasks.confirm_delete_message'.tr,
              confirmText: 'delete'.tr,
              confirmColor: Colors.red,
              onTap: () async {
                await controller.deleteTask(task.id!);
                Get.back();
              },
            );
          },
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text('delete'.tr),
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
        photographyDialog(context, model: task);
        break;
      case '3':
        contentWriteDialog(context, model: task);
        break;
      case '4':
        montageDialog(context, model: task);
        break;
      case '5':
        publishDialog(context, model: task);
        break;
      case '6':
        programmingDialog(context, model: task);
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
