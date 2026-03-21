import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/View/Shared/TaskTimelineWidget.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Generic web dialog for task details. Renders common shell (header, notes,
/// attachments, timeline) and a type-specific middle section.
class GenericTaskDetailsDialog extends StatefulWidget {
  final TaskModel task;
  final Widget typeSpecificSection;

  /// Dialog width as fraction of screen width (e.g. 0.8 or 0.7).
  final double dialogWidthFraction;

  const GenericTaskDetailsDialog({
    super.key,
    required this.task,
    required this.typeSpecificSection,
    this.dialogWidthFraction = 0.8,
  });

  @override
  State<GenericTaskDetailsDialog> createState() =>
      _GenericTaskDetailsDialogState();
}

class _GenericTaskDetailsDialogState extends State<GenericTaskDetailsDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final viewSize = MediaQuery.sizeOf(context);
    final dialogWidth = (viewSize.width * widget.dialogWidthFraction).clamp(
      320.0,
      860.0,
    );
    final maxDialogHeight = (viewSize.height * 0.9).clamp(420.0, 900.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 96, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: colorScheme.surface,
      child: Container(
        clipBehavior: Clip.antiAlias,
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.surfaceContainerLowest, colorScheme.surface],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Scrollbar(
            controller: _scrollController,
            thickness: 10,
            radius: const Radius.circular(12),
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton.filledTonal(
                        icon: const Icon(Icons.close),
                        onPressed: () => Get.back(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, dialogWidth),
                        const SizedBox(height: 12),
                        _buildGeneralMetaRow(dialogWidth, colorScheme),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionShell(
                      context: context,
                      title: 'tasks.dialog_title'.tr,
                      icon: Icons.view_kanban_outlined,
                      child: widget.typeSpecificSection,
                    ),
                    const SizedBox(height: 16),
                    _buildSectionShell(
                      context: context,
                      title: 'content.dialog.notes_attachments_section'.tr,
                      icon: Icons.attach_file_outlined,
                      child: _buildNotesAndAttachmentsSection(
                        context,
                        textTheme,
                        dialogWidth,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTimelineShell(
                      context: context,
                      child: TaskTimelineWidget(
                        events: widget.task.timelineEvents,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double dialogWidth) {
    final assignedName =
        Get.find<HomeController>().employees
            .firstWhereOrNull((emp) => emp.id == widget.task.assignedTo)
            ?.name ??
        '';
    final hasDescription = widget.task.description.trim().isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasDescription) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'tasks.no_description'.tr,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: BoxConstraints(
              maxWidth: dialogWidth < 520 ? dialogWidth - 120 : 250,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage(
                    widget.task.assignedImageUrl.isEmpty
                        ? '${StorageKeys.supabaseStorageBaseUrl}/Avatar.png'
                        : widget.task.assignedImageUrl,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'content.dialog.executor'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        assignedName.isEmpty ? '-' : assignedName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralMetaRow(double dialogWidth, ColorScheme colorScheme) {
    final progressPercent = '${(((widget.task.progress ?? 0) * 100).toInt())}%';
    final actionTextValue =
        widget.task.actionText.isNotEmpty ? widget.task.actionText : '-';
    final statusValue =
        widget.task.status.isNotEmpty
            ? FunHelper.trStored(
                widget.task.status,
                kind: StoredValueKind.taskStatus,
              )
            : '-';
    final bool compact = dialogWidth < 720;
    final infoWidth = compact ? (dialogWidth - 80).clamp(180.0, 240.0) : 220.0;
    final actionWidth =
        compact ? (dialogWidth - 80).clamp(220.0, 500.0) : dialogWidth * 0.35;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildMetaTile(
          label: 'tasks.status_label'.tr,
          value: statusValue,
          icon: Icons.flag_outlined,
          width: infoWidth,
          colorScheme: colorScheme,
        ),
        _buildMetaTile(
          label: 'tasks.progress_label'.tr,
          value: progressPercent,
          icon: Icons.donut_small_outlined,
          width: infoWidth,
          colorScheme: colorScheme,
        ),
        _buildMetaTile(
          label: 'tasks.action_text_label'.tr,
          value: actionTextValue,
          icon: Icons.auto_fix_high_outlined,
          width: actionWidth,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildNotesAndAttachmentsSection(
    BuildContext context,
    TextTheme textTheme,
    double dialogWidth,
  ) {
    final bool stacked = dialogWidth < 720;
    final contentWidth =
        stacked
            ? (dialogWidth - 80).clamp(240.0, 760.0)
            : ((dialogWidth - 90) / 2).clamp(260.0, 700.0);

    final latestNote = widget.task.notes.isNotEmpty ? widget.task.notes.last : null;
    final notesSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('tasks.notes_section'.tr, style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 200),
          width: contentWidth,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (latestNote != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD9D4FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'tasks.latest_comment'.tr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5C5589),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        latestNote.note,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryfontColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _buildNoteMeta(latestNote.byWho, latestNote.timestamp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (widget.task.notes.isEmpty)
                Center(
                  child: Text(
                    'content.dialog.no_notes'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var note in widget.task.notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.note,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryfontColor,
                              ),
                            ),
                            Text(
                              note.byWho,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );

    final attachmentsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('content.dialog.attachments'.tr, style: textTheme.titleSmall),
        const SizedBox(height: 10),
        Container(
          width: contentWidth,
          constraints: const BoxConstraints(minHeight: 200),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child:
              widget.task.files.isEmpty
                  ? Center(
                    child: Text(
                      'content.dialog.no_attachments'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                  : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.task.files.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          contentWidth < 340 ? 1 : (contentWidth < 560 ? 2 : 3),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 84,
                    ),
                    itemBuilder: (context, index) {
                      final att = widget.task.files[index];
                      return TaskDetailsDialogHelpers.attachmentThumbnail(
                        att,
                        onOpen: () => _launchUrl(att),
                      );
                    },
                  ),
        ),
      ],
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          notesSection,
          const SizedBox(height: 16),
          attachmentsSection,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [notesSection, attachmentsSection],
    );
  }

  Uri _normalizeAttachmentUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) return parsed;
    return Uri.parse('https://$trimmed');
  }

  Future<void> _launchUrl(String rawUrl) async {
    try {
      final uri = _normalizeAttachmentUri(rawUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // fall through to snackbar
    }

    FunHelper.showsnackbar(
      AppLocaleKeys.errorTitle.tr,
      AppLocaleKeys.contentDialogOpenLinkFailed.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
  }

  Widget _buildSectionShell({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildMetaTile({
    required String label,
    required String value,
    required IconData icon,
    required double width,
    required ColorScheme colorScheme,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 90),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(icon, size: 15, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineShell({
    required BuildContext context,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }

  String _buildNoteMeta(String author, DateTime timestamp) {
    final safeAuthor =
        author.trim().isEmpty ? 'content.dialog.unknown'.tr : author.trim();
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
}
