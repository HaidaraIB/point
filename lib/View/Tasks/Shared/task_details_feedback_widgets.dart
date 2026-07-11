import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/attachment_download.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Tasks/Shared/task_attachment_gallery.dart';

/// Shared management/rejection banners and deadline-extension panel for
/// [GenericTaskDetailsDialog] (web) and [TaskDetailsMobilePage] (mobile).
class TaskDetailsFeedbackWidgets {
  TaskDetailsFeedbackWidgets._();

  static Widget feedbackBanners(BuildContext context, TaskModel t) {
    final colorScheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    if (t.managementEditRequestMessage.trim().isNotEmpty ||
        t.managementEditRequestFileUrls.isNotEmpty) {
      children.add(
        _bannerBox(
          context,
          colorScheme,
          title: 'tasks.management_edit_request_banner'.tr,
          body: t.managementEditRequestMessage.trim(),
          fileUrls: t.managementEditRequestFileUrls,
        ),
      );
    }

    if (FunHelper.canonicalStoredStatus(t.status) ==
            StorageKeys.status_rejected &&
        (t.rejectionMessage.trim().isNotEmpty ||
            t.rejectionFileUrls.isNotEmpty)) {
      children.add(
        _bannerBox(
          context,
          colorScheme,
          title: 'tasks.rejection_feedback_banner'.tr,
          body: t.rejectionMessage.trim(),
          fileUrls: t.rejectionFileUrls,
          toneError: true,
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }

  /// Compact alerts on employee dashboard cards (web + mobile layouts).
  static Widget compactEmployeeAlerts(BuildContext context, TaskModel t) {
    final colorScheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    if (t.managementEditRequestMessage.trim().isNotEmpty ||
        t.managementEditRequestFileUrls.isNotEmpty) {
      children.add(
        _compactBanner(
          colorScheme,
          title: 'tasks.management_edit_request_banner'.tr,
          body: t.managementEditRequestMessage.trim(),
          error: false,
        ),
      );
    }
    if (FunHelper.canonicalStoredStatus(t.status) ==
            StorageKeys.status_rejected &&
        (t.rejectionMessage.trim().isNotEmpty ||
            t.rejectionFileUrls.isNotEmpty)) {
      children.add(
        _compactBanner(
          colorScheme,
          title: 'tasks.rejection_feedback_banner'.tr,
          body: t.rejectionMessage.trim(),
          error: true,
        ),
      );
    }
    final ext = t.deadlineExtensionStatus.trim();
    if (ext == TaskModel.kDeadlineExtensionPending) {
      children.add(
        _compactBanner(
          colorScheme,
          title: 'tasks.deadline_extension_pending_banner'.tr,
          body: '',
          error: false,
        ),
      );
    } else if (ext == TaskModel.kDeadlineExtensionDenied) {
      children.add(
        _compactBanner(
          colorScheme,
          title: 'tasks.deadline_extension_denied_banner'.tr,
          body: t.deadlineExtensionDeniedNote.trim(),
          error: true,
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            children[i],
          ],
        ],
      ),
    );
  }

  static Widget _compactBanner(
    ColorScheme colorScheme, {
    required String title,
    required String body,
    required bool error,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: error ? Colors.red.shade50 : colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: error ? Colors.red.shade200 : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: error ? Colors.red.shade900 : colorScheme.primary,
            ),
          ),
          if (body.isNotEmpty)
            LinkifiedText(
              body,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                color: error ? Colors.red.shade900 : colorScheme.onSurface,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              selectable: false,
            ),
        ],
      ),
    );
  }

  static Widget deadlineExtensionPanel(BuildContext context, TaskModel t) {
    final role = Get.find<HomeController>().currentEmployee.value?.role ?? '';
    final mgr = role == 'admin' || role == 'supervisor';
    final st = t.deadlineExtensionStatus.trim();
    if (st == TaskModel.kDeadlineExtensionPending && mgr) {
      final req = t.deadlineExtensionRequestedTo;
      final reqLabel =
          req != null ? (FunHelper.formatdate(req) ?? req.toIso8601String()) : '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'tasks.deadline_extension_pending_banner'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.amber.shade900,
                ),
              ),
              if (reqLabel.isNotEmpty)
                Text(
                  '${'tasks.deadline_extension_new_date'.tr}: $reqLabel',
                  style: TextStyle(fontSize: 13),
                ),
              if (t.deadlineExtensionReason.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SelectableText(t.deadlineExtensionReason.trim()),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: req == null
                        ? null
                        : () async {
                            final hc = Get.find<HomeController>();
                            await hc.updateTask(
                              t.copyWith(
                                toDate: req,
                                deadlineExtensionStatus: '',
                                deadlineExtensionReason: '',
                                deadlineExtensionRequestedAt: '',
                                deadlineExtensionRequestedBy: '',
                                deadlineExtensionDeniedNote: '',
                                clearDeadlineExtensionRequestedTo: true,
                              ),
                            );
                          },
                    icon: const Icon(Icons.check),
                    label: Text('tasks.deadline_extension_approve'.tr),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        showDenyDeadlineExtensionDialog(context, t),
                    icon: const Icon(Icons.close),
                    label: Text('tasks.deadline_extension_deny'.tr),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (st == TaskModel.kDeadlineExtensionPending && !mgr) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'tasks.deadline_extension_pending_banner'.tr,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.amber.shade900,
          ),
        ),
      );
    }
    if (st == TaskModel.kDeadlineExtensionDenied && role == 'employee') {
      final note = t.deadlineExtensionDeniedNote.trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          note.isEmpty
              ? 'tasks.deadline_extension_denied_banner'.tr
              : '${'tasks.deadline_extension_denied_banner'.tr} $note',
          style: TextStyle(color: Colors.red.shade800, fontSize: 13),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  static Future<void> showDenyDeadlineExtensionDialog(
    BuildContext context,
    TaskModel t,
  ) async {
    final noteController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('tasks.deadline_extension_deny'.tr),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'tasks.deadline_extension_deny_note'.tr,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocaleKeys.commonCancel.tr),
          ),
          FilledButton(
            onPressed: () async {
              final hc = Get.find<HomeController>();
              await hc.updateTask(
                t.copyWith(
                  deadlineExtensionStatus: TaskModel.kDeadlineExtensionDenied,
                  deadlineExtensionDeniedNote: noteController.text.trim(),
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('tasks.deadline_extension_deny'.tr),
          ),
        ],
      ),
    );
    noteController.dispose();
  }

  static Widget _bannerBox(
    BuildContext context,
    ColorScheme colorScheme, {
    required String title,
    required String body,
    List<String> fileUrls = const [],
    bool toneError = false,
  }) {
    final border = toneError ? Colors.red.shade200 : colorScheme.outlineVariant;
    final bg =
        toneError ? Colors.red.shade50 : colorScheme.surfaceContainerHighest;
    final imageUrls =
        fileUrls.where((u) => isImageMediaUrl(u.toString())).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: toneError ? Colors.red.shade900 : colorScheme.primary,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            LinkifiedText(
              body,
              style: TextStyle(fontSize: 13, height: 1.35),
              selectable: true,
            ),
          ],
          if (fileUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < fileUrls.length; i++)
                  _attachmentActionChips(
                    context,
                    fileUrls[i],
                    imageUrls: imageUrls,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _attachmentActionChips(
    BuildContext context,
    String rawUrl, {
    required List<String> imageUrls,
  }) {
    final url = rawUrl.toString();
    final isImg = isImageMediaUrl(url);
    final initial = imageUrls.indexOf(url);
    return Wrap(
      spacing: 4,
      children: [
        ActionChip(
          avatar: const Icon(Icons.open_in_new, size: 18),
          label: Text('tasks.open_attachment'.tr),
          onPressed: () => openUrlPreferInAppMedia(url),
        ),
        ActionChip(
          avatar: const Icon(Icons.download_outlined, size: 18),
          label: Text('tasks.download'.tr),
          onPressed: () => launchAttachmentDownload(url),
        ),
        if (isImg && imageUrls.isNotEmpty)
          ActionChip(
            avatar: const Icon(Icons.collections, size: 18),
            label: Text('tasks.attachment_gallery'.tr),
            onPressed: () => openTaskAttachmentGallery(
              imageUrls: imageUrls,
              initialIndex: initial >= 0 ? initial : 0,
            ),
          ),
      ],
    );
  }

}
