import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/AdministrationTaskModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/attachment_download.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Shared/TaskTimelineWidget.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:point/View/Tasks/Dialogs/ContentWriteDialog.dart';
import 'package:point/View/Tasks/Dialogs/DesignDialog.dart';
import 'package:point/View/Tasks/Dialogs/MontageDialog.dart';
import 'package:point/View/Tasks/Dialogs/PhotographyDialog.dart';
import 'package:point/View/Tasks/Dialogs/AdministrativeDialog.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';
import 'package:point/View/Tasks/Dialogs/PromotionDialog.dart';
import 'package:point/View/Tasks/Dialogs/PublishDialog.dart';
import 'package:point/View/Tasks/Shared/deadline_extension_request_dialog.dart';
import 'package:point/View/Tasks/Shared/task_details_feedback_widgets.dart';
import 'package:point/View/Tasks/Shared/task_note_body.dart';
import 'package:point/View/Tasks/Shared/task_voice_details_tile.dart';
import 'package:point/View/Tasks/Shared/task_attachment_gallery.dart';
import 'package:point/View/Tasks/Shared/edit_final_deliverable_dialog.dart';
import 'package:point/View/Tasks/Shared/open_task_final_work.dart';
import 'package:point/View/Tasks/Shared/reject_task_dialog.dart';
import 'package:point/View/Tasks/Shared/request_task_modification_dialog.dart';
import 'package:point/View/Shared/task_status_visuals.dart';
import 'package:point/View/Shared/app_user_avatar.dart';
import 'package:point/Utils/app_theme_extension.dart';

bool _taskInManagementReviewMobile(TaskModel task) {
  final s = FunHelper.canonicalStoredStatus(task.status);
  if (task.type == '0') {
    return s == StorageKeys.status_promotion_ad_platform_review ||
        s == StorageKeys.status_awaiting_manager;
  }
  return s == StorageKeys.status_under_revision ||
      s == StorageKeys.status_awaiting_manager;
}

bool _employeeMayEditFinalDeliverableInDetails(TaskModel t, String role) {
  if (role != 'employee') return false;
  if (t.type == '0') return false;
  return FunHelper.canonicalStoredStatus(t.status) ==
      StorageKeys.status_approved;
}

BoxDecoration _taskDetailsInsetPanelDecoration(BuildContext context) =>
    BoxDecoration(
      color: context.appTheme.panelTint,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.appTheme.border),
    );

Color _taskDetailsTintedBg(
  BuildContext context,
  Color accent, {
  required Color lightBg,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? accent.withValues(alpha: 0.18) : lightBg;
}

/// Mobile-only full-screen task details. Used when opening any task type on mobile.
class TaskDetailsMobilePage extends StatelessWidget {
  final TaskModel task;

  const TaskDetailsMobilePage({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: context.appTheme.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'tasks.dialog_title'.tr,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.appTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.appTheme.mutedText,
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
                    TaskStatusVisuals.statusChip(
                      rawStatus: task.status,
                      fg: _statusColor(
                        FunHelper.canonicalStoredStatus(task.status),
                      ),
                      bg: _statusBg(
                        context,
                        FunHelper.canonicalStoredStatus(task.status),
                      ),
                      iconSize: 14,
                      fontSize: 12,
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
                        context,
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
                        color: context.appTheme.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: task.progress ?? 0,
                      backgroundColor: context.appTheme.border,
                      color: context.appTheme.accentText,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${((task.progress ?? 0) * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTheme.mutedText,
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
                    AppUserAvatar(
                      url: task.assignedImageUrl.isEmpty
                          ? '${StorageKeys.supabaseStorageBaseUrl}/Avatar.png'
                          : task.assignedImageUrl,
                      radius: 22,
                      displayName: _assigneeName(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _assigneeName(context),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: context.appTheme.mutedText,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                FunHelper.formatdate(task.fromDate) ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.appTheme.mutedText,
                                ),
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
                                      : context.appTheme.mutedText,
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
              Obx(() {
                final live =
                    Get.find<HomeController>().tasks.firstWhereOrNull(
                      (x) => x.id == task.id,
                    ) ??
                    task;
                if (!_shouldShowFinalDeliverableCard(live)) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    _buildFinalDeliverableCard(context, live),
                  ],
                );
              }),
              const SizedBox(height: 12),
              Obx(() {
                final live =
                    Get.find<HomeController>().tasks.firstWhereOrNull(
                      (x) => x.id == task.id,
                    ) ??
                    task;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TaskDetailsFeedbackWidgets.feedbackBanners(context, live),
                    TaskDetailsFeedbackWidgets.deadlineExtensionPanel(
                      context,
                      live,
                    ),
                  ],
                );
              }),
              const SizedBox(height: 12),
              Obx(() {
                final live =
                    Get.find<HomeController>().tasks.firstWhereOrNull(
                      (x) => x.id == task.id,
                    ) ??
                    task;
                return _buildNotesAndAttachmentsCard(context, live);
              }),
              Obx(() {
                final live =
                    Get.find<HomeController>().tasks.firstWhereOrNull(
                      (x) => x.id == task.id,
                    ) ??
                    task;
                if (live.timelineEvents.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    TaskTimelineWidget(
                      events: live.timelineEvents,
                      notes: live.notes,
                    ),
                  ],
                );
              }),
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
        color: context.appTheme.cardSurface,
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

  Widget _fieldRow(BuildContext context, String label, String value) {
    final displayValue = TaskDetailsDialogHelpers.displayOrDash(value);
    final isPlaceholder = displayValue == '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.appTheme.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          LinkifiedText(
            displayValue,
            style: TextStyle(
              fontSize: 13,
              color: isPlaceholder
                  ? context.appTheme.mutedText
                  : context.appTheme.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _clientDisplayName(BuildContext context) {
    final controller = Get.find<HomeController>();
    final client = controller.clients.firstWhereOrNull(
      (c) => c.id == task.clientName,
    );
    return client?.name ?? task.clientName;
  }

  void _appendTaskDateRows(BuildContext context, List<Widget> fields) {
    fields.add(
      _fieldRow(
        context,
        'task_details.date_start_task'.tr,
        FunHelper.formatdate(task.fromDate) ?? '-',
      ),
    );
    fields.add(
      _fieldRow(
        context,
        'task_details.date_end_task'.tr,
        FunHelper.formatdate(task.toDate) ?? '-',
      ),
    );
  }

  Future<void> _launchAttachmentUrl(String rawUrl) async {
    await openUrlPreferInAppMedia(rawUrl);
  }

  Widget _mobileAttachmentTile(
    BuildContext context,
    String att,
    List<String> imageUrls,
  ) {
    final url = att.toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 72,
          width: double.infinity,
          child: TaskDetailsDialogHelpers.attachmentThumbnail(
            url,
            onOpen: () => _launchAttachmentUrl(url),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'tasks.open_attachment'.tr,
              iconSize: 20,
              onPressed: () => _launchAttachmentUrl(url),
              icon: const Icon(Icons.open_in_new),
            ),
            IconButton(
              tooltip: 'tasks.download'.tr,
              iconSize: 20,
              onPressed: () => launchAttachmentDownload(url),
              icon: const Icon(Icons.download_outlined),
            ),
            if (isImageMediaUrl(url))
              IconButton(
                tooltip: 'tasks.attachment_gallery'.tr,
                iconSize: 20,
                onPressed: () {
                  final i = imageUrls.indexOf(url);
                  openTaskAttachmentGallery(
                    imageUrls: imageUrls,
                    initialIndex: i >= 0 ? i : 0,
                  );
                },
                icon: const Icon(Icons.collections_outlined),
              ),
          ],
        ),
      ],
    );
  }

  Widget _linkFieldRow(BuildContext context, String label, String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value == '-') {
      return _fieldRow(context, label, '-');
    }
    final looksUrl = isLikelyUrlValue(value);
    if (!looksUrl) {
      return _fieldRow(context, label, value);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.appTheme.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _launchAttachmentUrl(value),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: context.appTheme.accentText,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasFinalDeliverable(TaskModel t) {
    return t.finalDeliverableText.trim().isNotEmpty ||
        t.finalDeliverableFileUrls.isNotEmpty ||
        t.finalDeliverableType.trim().isNotEmpty;
  }

  bool _canManageFinalDeliverable() {
    final r = Get.find<HomeController>().currentEmployee.value?.role ?? '';
    return r == 'admin' || r == 'supervisor';
  }

  bool _shouldShowFinalDeliverableCard(TaskModel t) {
    return _hasFinalDeliverable(t) || _canManageFinalDeliverable();
  }

  Widget _buildFinalDeliverableCard(BuildContext context, TaskModel t) {
    final textTheme = Theme.of(context).textTheme;
    final body = t.finalDeliverableText.trim();
    final urls = t.finalDeliverableFileUrls;
    final finalType = t.finalDeliverableType.trim();
    final screenW = MediaQuery.sizeOf(context).width;
    final contentW = (screenW - 64).clamp(240.0, 800.0);
    final crossCount = contentW < 340 ? 1 : (contentW < 560 ? 2 : 3);

    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.outbox_outlined,
                size: 18,
                color: context.appTheme.mutedText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'tasks.final_deliverable_section'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.appTheme.mutedText,
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final role =
                      Get.find<HomeController>().currentEmployee.value?.role ??
                      '';
                  final live =
                      Get.find<HomeController>().tasks.firstWhereOrNull(
                        (x) => x.id == task.id,
                      ) ??
                      t;
                  final showEdit =
                      _canManageFinalDeliverable() ||
                      _employeeMayEditFinalDeliverableInDetails(live, role);
                  if (!showEdit) return const SizedBox.shrink();
                  return IconButton(
                    tooltip: 'tasks.final_deliverable_edit'.tr,
                    icon: const Icon(Icons.edit_outlined, size: 22),
                    onPressed: () {
                      if (_canManageFinalDeliverable()) {
                        showEditFinalDeliverableDialog(
                          context: context,
                          task: live,
                        );
                      } else {
                        openTaskFinalWorkDialog(context: context, task: live);
                      }
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (finalType.isNotEmpty) ...[
            Text(
              'tasks.final_deliverable_type_label'.tr,
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: _taskDetailsInsetPanelDecoration(context),
              child: Text(
                finalType.tr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.appTheme.primaryText,
                ),
              ),
            ),
            if (body.isNotEmpty || urls.isNotEmpty) const SizedBox(height: 14),
          ],
          if (body.isEmpty && urls.isEmpty && _canManageFinalDeliverable()) ...[
            Text(
              'tasks.final_deliverable_empty_manager'.tr,
              style: TextStyle(
                fontSize: 13,
                color: context.appTheme.mutedText,
                height: 1.35,
              ),
            ),
          ] else if (body.isNotEmpty) ...[
            Text(
              'tasks.final_deliverable_text_label'.tr,
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: _taskDetailsInsetPanelDecoration(context),
              child: LinkifiedText(
                body,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.primaryText,
                ),
              ),
            ),
            if (urls.isNotEmpty) const SizedBox(height: 14),
          ],
          if (urls.isNotEmpty) ...[
            Text(
              'tasks.final_deliverable_files_label'.tr,
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 72),
              decoration: _taskDetailsInsetPanelDecoration(context),
              padding: const EdgeInsets.all(10),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: urls.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 118,
                ),
                itemBuilder: (context, index) {
                  final att = urls[index];
                  final imgs = urls
                      .where((u) => isImageMediaUrl(u.toString()))
                      .toList();
                  return _mobileAttachmentTile(context, att, imgs);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesAndAttachmentsCard(BuildContext context, TaskModel t) {
    final textTheme = Theme.of(context).textTheme;
    final screenW = MediaQuery.sizeOf(context).width;
    final contentW = (screenW - 64).clamp(240.0, 800.0);
    final crossCount = contentW < 340 ? 1 : (contentW < 560 ? 2 : 3);

    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file_outlined,
                size: 18,
                color: context.appTheme.mutedText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'content.dialog.notes_attachments_section'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.appTheme.mutedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('tasks.notes_section'.tr, style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: _taskDetailsInsetPanelDecoration(context),
            child: t.notes.isEmpty
                ? Center(
                    child: Text(
                      'content.dialog.no_notes'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTheme.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...t.notes.asMap().entries.map((entry) {
                        final isLatest = entry.key == t.notes.length - 1;
                        final note = entry.value;
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: isLatest
                              ? const EdgeInsets.all(10)
                              : EdgeInsets.zero,
                          decoration: isLatest
                              ? BoxDecoration(
                                  color: context.appTheme.panelTint,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                )
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isLatest) ...[
                                Text(
                                  'tasks.latest_comment'.tr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: context.appTheme.accentText,
                                  ),
                                ),
                                const SizedBox(height: 5),
                              ],
                              TaskNoteBody(note: note, compactVoice: false),
                              Text(
                                isLatest
                                    ? _buildNoteMeta(note.byWho, note.timestamp)
                                    : '${note.byWho} • ${_formatRelativeTime(note.timestamp)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isLatest ? 11 : 12,
                                  color: Colors.green,
                                  fontWeight: isLatest ? FontWeight.w600 : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Text('content.dialog.attachments'.tr, style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 100),
            decoration: _taskDetailsInsetPanelDecoration(context),
            padding: const EdgeInsets.all(10),
            child: t.files.isEmpty
                ? Center(
                    child: Text(
                      'content.dialog.no_attachments'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTheme.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: t.files.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 118,
                    ),
                    itemBuilder: (context, index) {
                      final att = t.files[index].toString();
                      final imgs = t.files
                          .map((e) => e.toString())
                          .where(isImageMediaUrl)
                          .toList();
                      return _mobileAttachmentTile(context, att, imgs);
                    },
                  ),
          ),
          TaskVoiceDetailsTile(task: t),
        ],
      ),
    );
  }

  Widget _buildTypeDetailsCard(BuildContext context) {
    final localeIsArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';

    String listOrDash(
      dynamic list, {
      StoredValueKind kind = StoredValueKind.generic,
    }) {
      return FunHelper.joinStoredListForDisplay(
        list,
        kind: kind,
        localeIsArabic: localeIsArabic,
      );
    }

    String platformOrDash(dynamic platform) {
      final s = FunHelper.formatStoredPlatforms(platform);
      return s.isEmpty ? '-' : s;
    }

    String dateOrDash(DateTime? d) =>
        d == null ? '-' : (FunHelper.formatdate(d) ?? '-');

    final List<Widget> fields = [];

    fields.add(
      _fieldRow(
        context,
        'tasks.form.client_label'.tr,
        _clientDisplayName(context),
      ),
    );

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
          _fieldRow(context, 'startat'.tr, dateOrDash(promo?.startDate)),
        );
        fields.add(_fieldRow(context, 'endat'.tr, dateOrDash(promo?.endDate)));
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
          _fieldRow(context, 'platform'.tr, platformOrDash(promo?.platforms)),
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
            promo?.customDetails == null
                ? '-'
                : jsonEncode(promo!.customDetails),
          ),
        );
        fields.add(_fieldRow(context, 'notes'.tr, promo?.notes ?? '-'));
        fields.add(
          _linkFieldRow(
            context,
            'task_details.files_link'.tr,
            promo?.attachementurl,
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.created_at'.tr,
            promo == null ? '-' : dateOrDash(promo.createdAt),
          ),
        );
        _appendTaskDateRows(context, fields);
        break;

      // 1: Design
      case '1':
        final m = task.designDetails;
        fields.add(
          _fieldRow(
            context,
            'task_details.task_type'.tr,
            m == null ? '-' : FunHelper.trStored(m.taskType),
          ),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.design_type'.tr,
            m == null ? '-' : FunHelper.trStored(m.designType),
          ),
        );
        fields.add(
          _fieldRow(context, 'platform'.tr, platformOrDash(m?.platform)),
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
        _appendTaskDateRows(context, fields);
        break;

      // 2: Photography
      case '2':
        final m = task.photoGrapghyModel;
        fields.add(
          _fieldRow(
            context,
            'task_details.objective'.tr,
            m == null ? '-' : FunHelper.trStored(m.shootingtype),
          ),
        );
        fields.add(
          _fieldRow(context, 'platform'.tr, platformOrDash(m?.platform)),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.shooting_type'.tr,
            m == null ? '-' : FunHelper.trStored(m.shootinglocation.toString()),
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
          _fieldRow(context, 'task_details.duration'.tr, m?.duration ?? '-'),
        );
        _appendTaskDateRows(context, fields);
        break;

      // 3: ContentWrite
      case '3':
        final m = task.contentWriteModel;
        fields.add(
          _fieldRow(
            context,
            'task_details.content_type'.tr,
            m == null ? '-' : FunHelper.trStored(m.contenttype),
          ),
        );
        fields.add(
          _fieldRow(context, 'platform'.tr, platformOrDash(m?.platform)),
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
        _appendTaskDateRows(context, fields);
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
          _fieldRow(context, 'platform'.tr, platformOrDash(m?.platform)),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.size'.tr,
            m == null ? '-' : FunHelper.trStored(m.dimentioans),
          ),
        );
        fields.add(
          _linkFieldRow(
            context,
            'task_details.attachment_link'.tr,
            m?.attachementurl,
          ),
        );
        fields.add(
          _fieldRow(context, 'task_details.duration'.tr, m?.duration ?? '-'),
        );
        _appendTaskDateRows(context, fields);
        break;

      // 5: Publish
      case '5':
        final m = task.publishModel;
        fields.add(
          _linkFieldRow(context, 'task_details.content_link'.tr, m?.contenturl),
        );
        fields.add(
          _fieldRow(context, 'platform'.tr, platformOrDash(m?.platform)),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.category'.tr,
            m == null ? '-' : FunHelper.trStored(m.category),
          ),
        );
        fields.add(
          _linkFieldRow(context, 'task_details.files_link'.tr, m?.fileurl),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.dimensions'.tr,
            m?.designsDimensions ?? '-',
          ),
        );
        _appendTaskDateRows(context, fields);
        break;

      // 6: Programming
      case '6':
        final m = task.programmingModel;
        fields.add(
          _linkFieldRow(context, 'task_details.content_link'.tr, m?.contenturl),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.category'.tr,
            m == null ? '-' : FunHelper.trStored(m.category),
          ),
        );
        fields.add(
          _linkFieldRow(context, 'task_details.files_link'.tr, m?.fileurl),
        );
        fields.add(
          _fieldRow(
            context,
            'task_details.dimensions'.tr,
            m?.designsDimensions ?? '-',
          ),
        );
        if (m != null && m.aboutTask.trim().isNotEmpty) {
          fields.add(
            _fieldRow(context, 'task_details.about_task'.tr, m.aboutTask),
          );
        }
        _appendTaskDateRows(context, fields);
        break;

      // 7: Administration
      case '7':
        final adm = task.administrationModel;
        final ex = adm?.extra ?? const {};
        final aboutRaw = ex[AdministrationTaskModel.kAboutTaskKey];
        final aboutText = aboutRaw?.toString().trim() ?? '';
        if (aboutText.isNotEmpty) {
          fields.add(
            _fieldRow(context, 'task_details.about_task'.tr, aboutText),
          );
        }
        for (final e in ex.entries) {
          if (e.key == AdministrationTaskModel.kAboutTaskKey) continue;
          fields.add(_fieldRow(context, e.key, e.value?.toString() ?? '-'));
        }
        if (ex.isEmpty) {
          fields.add(
            _fieldRow(context, 'task_details.section_fallback'.tr, '-'),
          );
        }
        _appendTaskDateRows(context, fields);
        break;

      default:
        fields.add(_fieldRow(context, 'task_details.section_fallback'.tr, '-'));
        _appendTaskDateRows(context, fields);
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
              color: context.appTheme.mutedText,
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
      case StorageKeys.status_not_start_yet:
        return Colors.grey.shade700;
      case StorageKeys.status_processing:
        return Colors.amber.shade900;
      case StorageKeys.status_under_revision:
        return Colors.blue;
      case StorageKeys.status_in_edit:
        return Colors.purple.shade700;
      case StorageKeys.status_edit_requested:
        return Colors.deepOrange.shade700;
      case StorageKeys.status_ready_to_publish:
        return Colors.teal.shade700;
      case StorageKeys.status_awaiting_manager:
        return Colors.indigo.shade700;
      case StorageKeys.status_approved:
        return Colors.green;
      case StorageKeys.status_scheduled:
        return Colors.orange.shade800;
      case StorageKeys.status_task_completed:
      case StorageKeys.status_published:
        return Colors.lightGreen.shade800;
      case StorageKeys.status_rejected:
        return Colors.red;
      case StorageKeys.status_promotion_in_progress:
        return Colors.amber.shade900;
      case StorageKeys.status_promotion_ad_platform_review:
        return Colors.blue.shade800;
      case StorageKeys.status_promotion_running:
        return Colors.green.shade800;
      case StorageKeys.status_promotion_finished:
        return Colors.blueGrey.shade700;
      default:
        return Colors.grey;
    }
  }

  Color _statusBg(BuildContext context, String status) {
    final fg = _statusColor(status);
    final lightBg = switch (status) {
      StorageKeys.status_not_start_yet => Colors.grey.shade200,
      StorageKeys.status_processing => Colors.amber.shade50,
      StorageKeys.status_under_revision => Colors.blue.shade50,
      StorageKeys.status_in_edit => Colors.purple.shade50,
      StorageKeys.status_edit_requested => Colors.deepOrange.shade50,
      StorageKeys.status_ready_to_publish => Colors.teal.shade50,
      StorageKeys.status_awaiting_manager => Colors.indigo.shade50,
      StorageKeys.status_approved => Colors.green.shade50,
      StorageKeys.status_scheduled => Colors.orange.shade50,
      StorageKeys.status_task_completed ||
      StorageKeys.status_published => Colors.lightGreen.shade50,
      StorageKeys.status_rejected => Colors.red.shade50,
      StorageKeys.status_promotion_in_progress => Colors.amber.shade50,
      StorageKeys.status_promotion_ad_platform_review => Colors.blue.shade50,
      StorageKeys.status_promotion_running => Colors.green.shade50,
      StorageKeys.status_promotion_finished => Colors.blueGrey.shade100,
      _ => Colors.grey.shade200,
    };
    return _taskDetailsTintedBg(context, fg, lightBg: lightBg);
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

  Color _priorityBg(BuildContext context, String priority) {
    final fg = _priorityColor(priority);
    final lightBg = switch (priority) {
      'normal' => Colors.blue.shade50,
      'imp' => Colors.orange.shade50,
      'veryimp' => Colors.red.shade50,
      'veryveryimp' => Colors.red.shade100,
      _ => Colors.green.shade50,
    };
    return _taskDetailsTintedBg(context, fg, lightBg: lightBg);
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
    final role = controller.currentEmployee.value?.role ?? '';
    final canEditDirectly = role == 'admin' || role == 'supervisor';
    final isEmployee = role == 'employee';
    final canEscalate =
        role == 'supervisor' &&
        FunHelper.taskStatusAllowsSupervisorDirectOrEscalate(task.status);
    final hideAccept = FunHelper.supervisorShouldHideTaskAccept(
      role,
      task.status,
    );
    final employeeRejectedReadOnly =
        isEmployee &&
        FunHelper.canonicalStoredStatus(task.status) ==
            StorageKeys.status_rejected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          label: Text(AppLocaleKeys.appClose.tr),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (!employeeRejectedReadOnly) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _openEditDialog(context, task),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(canEditDirectly ? 'edit'.tr : 'tasks.request_edit'.tr),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (canEditDirectly && _taskInManagementReviewMobile(task)) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => showRequestTaskModificationDialog(
                context: context,
                task: task,
              ),
              icon: const Icon(Icons.edit_note_outlined, size: 18),
              label: Text('tasks.request_modification_menu'.tr),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepOrange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
        if (isEmployee &&
            task.assignedTo.trim() ==
                (controller.currentEmployee.value?.id ?? '').trim() &&
            StorageKeys.isTaskOngoing(task) &&
            task.deadlineExtensionStatus.trim() !=
                TaskModel.kDeadlineExtensionPending) ...[
          OutlinedButton.icon(
            onPressed: () => showDeadlineExtensionRequestDialog(
              context: context,
              task: task,
            ),
            icon: const Icon(Icons.event_repeat_outlined, size: 18),
            label: Text('tasks.deadline_extension_button'.tr),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (!isEmployee) ...[
          if (task.type != '0' && canEscalate) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showRejectTaskDialog(
                        context: context,
                        task: task,
                        onSuccess: () => Get.back(),
                      );
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text('tasks.reject'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      FunHelper.showConfirmDailog(
                        context,
                        title:
                            'tasks.confirm_supervisor_approve_direct_title'.tr,
                        message:
                            'tasks.confirm_supervisor_approve_direct_message'
                                .tr,
                        confirmText: 'tasks.supervisor_approve_direct'.tr,
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
                    label: Text('tasks.supervisor_approve_direct'.tr),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  FunHelper.showConfirmDailog(
                    context,
                    title: 'tasks.confirm_send_to_manager_title'.tr,
                    message: 'tasks.confirm_send_to_manager_message'.tr,
                    confirmText: 'tasks.supervisor_send_to_manager'.tr,
                    confirmColor: Colors.indigo,
                    onTap: () async {
                      await controller.updateTask(
                        task.copyWith(
                          status: StorageKeys.status_awaiting_manager,
                        ),
                      );
                      Get.back();
                    },
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo.shade800,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.forward_to_inbox_rounded,
                      size: 18,
                      color: Colors.indigo.shade800,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'tasks.supervisor_send_to_manager'.tr,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (hideAccept) ...[
            OutlinedButton.icon(
              onPressed: () {
                showRejectTaskDialog(
                  context: context,
                  task: task,
                  onSuccess: () => Get.back(),
                );
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text('tasks.reject'.tr),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showRejectTaskDialog(
                        context: context,
                        task: task,
                        onSuccess: () => Get.back(),
                      );
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text('tasks.reject'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                          final next = task.type == '0'
                              ? task.copyWithPromotionStatusAligned(
                                  StorageKeys.status_approved,
                                )
                              : task.copyWith(
                                  status: StorageKeys.status_approved,
                                );
                          await controller.updateTask(next);
                          Get.back();
                        },
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('tasks.accept'.tr),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
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
      case '7':
        administrationDialog(context, model: task);
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
