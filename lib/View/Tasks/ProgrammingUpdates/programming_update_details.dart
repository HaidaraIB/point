import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ProgrammingUpdateModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Shared/attachment_thumbnail_tile.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/voice_message_row.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:point/View/Tasks/Shared/task_voice_form_helpers.dart';
import 'package:point/Utils/app_theme_extension.dart';

void showProgrammingUpdateDetails(
  BuildContext context, {
  required ProgrammingUpdateModel update,
}) {
  if (Responsive.isMobile(context)) {
    Get.to(() => ProgrammingUpdateDetailsMobilePage(update: update));
    return;
  }
  showDialog<void>(
    context: context,
    builder: (ctx) => ProgrammingUpdateDetailsDialog(update: update),
  );
}

class ProgrammingUpdateDetailsDialog extends StatelessWidget {
  final ProgrammingUpdateModel update;

  const ProgrammingUpdateDetailsDialog({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    final viewSize = MediaQuery.sizeOf(context);
    final dialogWidth = (viewSize.width * 0.7).clamp(320.0, 860.0);
    final maxDialogHeight = (viewSize.height * 0.9).clamp(420.0, 900.0);
    final colorScheme = Theme.of(context).colorScheme;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: ProgrammingUpdateDetailsBody(
                    update: update,
                    maxWidth: dialogWidth - 36,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgrammingUpdateDetailsMobilePage extends StatelessWidget {
  final ProgrammingUpdateModel update;

  const ProgrammingUpdateDetailsMobilePage({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;
    return Scaffold(
      backgroundColor: appTheme.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'programming.updates.details_title'.tr,
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
          child: ProgrammingUpdateDetailsBody(
            update: update,
            isMobile: true,
          ),
        ),
      ),
    );
  }
}

class ProgrammingUpdateDetailsBody extends StatelessWidget {
  final ProgrammingUpdateModel update;
  final bool isMobile;
  final double? maxWidth;

  const ProgrammingUpdateDetailsBody({
    super.key,
    required this.update,
    this.isMobile = false,
    this.maxWidth,
  });

  ProgrammingUpdateModel _liveUpdate() {
    final id = update.id;
    if (id == null || id.isEmpty) return update;
    return Get.find<HomeController>().programmingUpdates
            .firstWhereOrNull((u) => u.id == id) ??
        update;
  }

  String _clientName(ProgrammingUpdateModel u) {
    final hc = Get.find<HomeController>();
    return hc.clients.firstWhereOrNull((c) => c.id == u.clientName)?.name ??
        u.clientName;
  }

  String _assigneeName(ProgrammingUpdateModel u) {
    final hc = Get.find<HomeController>();
    return hc.employees.firstWhereOrNull((e) => e.id == u.assignedTo)?.name ??
        u.assignedTo;
  }

  String _displayTitle(ProgrammingUpdateModel u) {
    final t = u.title.trim();
    return t.isNotEmpty ? t : 'programming.updates.update_n'.trParams({'n': '1'});
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final live = _liveUpdate();
      final colorScheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      final contentWidth = maxWidth ?? MediaQuery.sizeOf(context).width - 32;
      final compact = contentWidth < 720;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, live, colorScheme, contentWidth),
          const SizedBox(height: 12),
          _buildMetaRow(context, live, colorScheme, contentWidth, compact),
          const SizedBox(height: 16),
          _buildSectionShell(
            context: context,
            title: 'programming.updates.details_section'.tr,
            icon: Icons.view_kanban_outlined,
            child: isMobile
                ? _buildMobileDetailsFields(context, live)
                : _buildWebDetailsGrid(context, live, contentWidth),
          ),
          const SizedBox(height: 16),
          _buildSectionShell(
            context: context,
            title: 'content.dialog.notes_attachments_section'.tr,
            icon: Icons.attach_file_outlined,
            child: _buildNotesAndAttachments(
              context,
              live,
              textTheme,
              contentWidth,
              compact,
            ),
          ),
          if (live.isConverted &&
              (live.convertedToTaskId ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                final taskId = live.convertedToTaskId!;
                final task = Get.find<HomeController>()
                    .tasks
                    .firstWhereOrNull((t) => t.id == taskId);
                if (task != null) {
                  showProgrammingDialog(context, task: task);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: Text('programming.updates.open_task'.tr),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildHeader(
    BuildContext context,
    ProgrammingUpdateModel u,
    ColorScheme colorScheme,
    double contentWidth,
  ) {
    final desc = u.description.trim();
    final assignee = _assigneeName(u);
    final assigneeImage = Get.find<HomeController>()
            .employees
            .firstWhereOrNull((e) => e.id == u.assignedTo)
            ?.image ??
        '';

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
                  _displayTitle(u),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                if (desc.isNotEmpty)
                  LinkifiedText(
                    desc,
                    maxLines: isMobile ? null : 3,
                    overflow: isMobile ? null : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  )
                else
                  Text(
                    'tasks.no_description'.tr,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: BoxConstraints(
              maxWidth: contentWidth < 520 ? contentWidth - 120 : 250,
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
                    assigneeImage.isEmpty
                        ? '${StorageKeys.supabaseStorageBaseUrl}/Avatar.png'
                        : assigneeImage,
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
                        assignee.isEmpty ? '-' : assignee,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
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

  Widget _buildMetaRow(
    BuildContext context,
    ProgrammingUpdateModel u,
    ColorScheme colorScheme,
    double contentWidth,
    bool compact,
  ) {
    final infoWidth = compact ? (contentWidth - 80).clamp(180.0, 240.0) : 220.0;
    final statusLabel = u.isPending
        ? 'programming.updates.pending'.tr
        : 'programming.updates.converted'.tr;
    final created = FunHelper.formatdate(u.createdAt) ?? '-';
    final client = _clientName(u).isEmpty ? '-' : _clientName(u);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _metaTile(
          label: 'tasks.status_label'.tr,
          value: statusLabel,
          icon: u.isPending ? Icons.hourglass_empty : Icons.check_circle_outline,
          width: infoWidth,
          colorScheme: colorScheme,
        ),
        _metaTile(
          label: 'programming.updates.created_at'.tr,
          value: created,
          icon: Icons.schedule_outlined,
          width: infoWidth,
          colorScheme: colorScheme,
        ),
        _metaTile(
          label: 'tasks.form.client_label'.tr,
          value: client,
          icon: Icons.business_outlined,
          width: compact ? contentWidth - 24 : contentWidth * 0.35,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _metaTile({
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
                LinkifiedText(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDetailsGrid(
    BuildContext context,
    ProgrammingUpdateModel u,
    double maxW,
  ) {
    final cellWidth = TaskDetailsDialogHelpers.gridCellWidth(maxW);
    final priority = u.priority.trim();
    final category = u.category.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
              color: context.appTheme.cardSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TaskDetailsDialogHelpers.infoBox(
                'tasks.form.client_label'.tr,
                _clientName(u).isEmpty ? '-' : _clientName(u),
                width: cellWidth,
                height: 110,
              ),
              InkWell(
                onTap: u.contenturl.trim().isEmpty
                    ? null
                    : () => openUrlPreferInAppMedia(u.contenturl),
                child: TaskDetailsDialogHelpers.infoBox(
                  'task_details.content_link'.tr,
                  u.contenturl.trim().isEmpty ? '-' : u.contenturl.trim(),
                  width: cellWidth,
                  height: 110,
                ),
              ),
              TaskDetailsDialogHelpers.infoBox(
                'task_details.task_priority'.tr,
                priority.isEmpty
                    ? '-'
                    : FunHelper.trStored(
                        priority,
                        kind: StoredValueKind.priority,
                      ),
                width: cellWidth,
                height: 110,
                child: priority.isEmpty
                    ? null
                    : TaskDetailsDialogHelpers.buildTag(
                        FunHelper.canonicalStoredPriority(priority),
                        tr: true,
                      ),
              ),
              TaskDetailsDialogHelpers.infoBox(
                'task_details.category'.tr,
                category.isEmpty ? '-' : FunHelper.trStored(category),
                width: cellWidth,
                height: 110,
              ),
              InkWell(
                onTap: u.fileurl.trim().isEmpty
                    ? null
                    : () => openUrlPreferInAppMedia(u.fileurl),
                child: TaskDetailsDialogHelpers.infoBox(
                  'task_details.files_link'.tr,
                  u.fileurl.trim().isEmpty ? '-' : u.fileurl.trim(),
                  width: cellWidth,
                  height: 110,
                ),
              ),
            ],
          ),
        ),
        if (u.aboutTask.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: context.appTheme.cardSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'task_details.about_task'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  u.aboutTask.trim(),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appTheme.secondaryText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
              color: context.appTheme.cardSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 8,
            children: [
              TaskDetailsDialogHelpers.infoBoxDates(
                'task_details.date_start_task'.tr,
                FunHelper.formatdate(u.fromDate),
                CupertinoIcons.calendar,
              ),
              TaskDetailsDialogHelpers.infoBoxDates(
                'task_details.date_end_task'.tr,
                FunHelper.formatdate(u.toDate),
                CupertinoIcons.calendar,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDetailsFields(
    BuildContext context,
    ProgrammingUpdateModel u,
  ) {
    final fields = <Widget>[
      _mobileFieldRow(
        context,
        'tasks.form.client_label'.tr,
        _clientName(u).isEmpty ? '-' : _clientName(u),
      ),
      _mobileLinkRow(context, 'task_details.content_link'.tr, u.contenturl),
      _mobileFieldRow(
        context,
        'task_details.task_priority'.tr,
        u.priority.trim().isEmpty
            ? '-'
            : FunHelper.trStored(u.priority, kind: StoredValueKind.priority),
      ),
      _mobileFieldRow(
        context,
        'task_details.category'.tr,
        u.category.trim().isEmpty ? '-' : FunHelper.trStored(u.category),
      ),
      _mobileLinkRow(context, 'task_details.files_link'.tr, u.fileurl),
      if (u.aboutTask.trim().isNotEmpty)
        _mobileFieldRow(
          context,
          'task_details.about_task'.tr,
          u.aboutTask.trim(),
        ),
      _mobileFieldRow(
        context,
        'task_details.date_start_task'.tr,
        FunHelper.formatdate(u.fromDate) ?? '-',
      ),
      _mobileFieldRow(
        context,
        'task_details.date_end_task'.tr,
        FunHelper.formatdate(u.toDate) ?? '-',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields,
    );
  }

  Widget _mobileFieldRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileLinkRow(BuildContext context, String label, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return _mobileFieldRow(context, label, '-');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
            onTap: () => openUrlPreferInAppMedia(value),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesAndAttachments(
    BuildContext context,
    ProgrammingUpdateModel u,
    TextTheme textTheme,
    double contentWidth,
    bool compact,
  ) {
    final notesWidth =
        compact ? contentWidth : ((contentWidth - 90) / 2).clamp(260.0, 700.0);

    final notesSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('notes'.tr, style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          width: notesWidth,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: u.description.trim().isEmpty
              ? Center(
                  child: Text(
                    'content.dialog.no_notes'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : LinkifiedText(
                  u.description.trim(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.primaryText,
                    height: 1.35,
                  ),
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
          width: notesWidth,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: u.files.isEmpty
              ? Center(
                  child: Text(
                    'content.dialog.no_attachments'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: u.files.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: notesWidth < 340 ? 1 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 88,
                  ),
                  itemBuilder: (_, index) {
                    final url = u.files[index];
                    return InkWell(
                      onTap: () => openUrlPreferInAppMedia(url),
                      borderRadius: BorderRadius.circular(8),
                      child: AttachmentThumbnailTile(
                        url: url,
                        borderRadius: 8,
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    final voiceSection = _buildVoiceSection(context, u);

    if (compact || isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          notesSection,
          const SizedBox(height: 16),
          attachmentsSection,
          voiceSection,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: notesSection),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [attachmentsSection, voiceSection],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSection(BuildContext context, ProgrammingUpdateModel u) {
    final records = voiceRecordsFromUpdate(u);
    if (records.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tasks.form.voice_record'.tr,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...records.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < records.length - 1 ? 8 : 0,
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'tasks.form.voice_record'.tr} ${index + 1}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      VoiceMessageRow(
                        url: record.url,
                        durationSec:
                            record.durationSec > 0 ? record.durationSec : null,
                        isMe: false,
                        compact: false,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
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
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
