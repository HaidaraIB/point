import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ProgrammingUpdateModel.dart';
import 'package:point/Models/VoiceRecordEntry.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/Utils/merge_programming_updates.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/form_attachment_thumbnails_grid.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';
import 'package:point/View/Tasks/ProgrammingUpdates/programming_update_details.dart';
import 'package:point/View/Tasks/Shared/task_voice_record_field.dart';

void _openCreateTaskFromUpdates(
  BuildContext context,
  List<ProgrammingUpdateModel> selected,
) {
  if (selected.isEmpty) return;

  final mergeIssue = validateProgrammingUpdatesMerge(selected);
  if (mergeIssue != null) {
    FunHelper.showSnackbar(
      'programming.updates.form_title'.tr,
      mergeIssue.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange.shade800,
      colorText: Colors.white,
    );
    return;
  }

  final draft = buildTaskDraftFromUpdates(selected);
  programmingDialog(context, model: draft, sourceUpdates: selected);
}

/// Quick "suggestions" composer + pending-suggestions board, shown at the
/// top of the programming department tasks tab (see the reference design).
class ProgrammingSuggestionsCard extends StatefulWidget {
  const ProgrammingSuggestionsCard({super.key});

  @override
  State<ProgrammingSuggestionsCard> createState() =>
      _ProgrammingSuggestionsCardState();
}

class _ProgrammingSuggestionsCardState
    extends State<ProgrammingSuggestionsCard> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<VoiceRecordEntry> _pendingVoice = [];
  // Kept local (not [HomeController.uploadedFilesPaths]) — that list is also
  // seeded by the task dialogs when converting a suggestion, so sharing it
  // here would leak the composer's staged files into/from those dialogs.
  final List<String> _pendingFiles = [];
  bool _showVoiceField = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _attachImages(HomeController controller) async {
    final files = await controller.pickMultiFiles();
    for (final file in files) {
      if (file.bytes == null) continue;
      final url = await controller.uploadFiles(
        filePathOrBytes: file.bytes!,
        fileName: file.name,
        addToUploadedFilesPathsList: false,
      );
      if (url != null && mounted) {
        setState(() => _pendingFiles.add(url));
      }
    }
  }

  Future<void> _addSuggestion(HomeController controller) async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty && description.isEmpty) return;

    final payload = ProgrammingUpdateModel(
      title: name,
      description: description,
      files: List<String>.from(_pendingFiles),
      voiceRecords: _pendingVoice,
      voiceRecordUrl: VoiceRecordEntry.primaryUrl(_pendingVoice),
      voiceRecordDurationSec: VoiceRecordEntry.primaryDurationSec(
        _pendingVoice,
      ),
      status: StorageKeys.programmingUpdateStatusPending,
    );
    final ok = await controller.addProgrammingUpdate(payload);
    if (ok) {
      _nameController.clear();
      _descriptionController.clear();
      setState(() {
        _pendingFiles.clear();
        _pendingVoice = [];
        _showVoiceField = false;
      });
    }
  }

  void _toggleSelect(String id, List<ProgrammingUpdateModel> allPending) {
    if (_selectedIds.contains(id)) {
      setState(() => _selectedIds.remove(id));
      return;
    }
    if (_selectedIds.isNotEmpty) {
      final anchor = allPending.firstWhereOrNull(
        (u) => u.id != null && _selectedIds.contains(u.id),
      );
      final candidate = allPending.firstWhereOrNull((u) => u.id == id);
      if (anchor != null &&
          candidate != null &&
          !canMergeProgrammingUpdates(anchor, candidate)) {
        FunHelper.showSnackbar(
          'programming.updates.form_title'.tr,
          'programming.updates.merge_selection_mismatch'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade800,
          colorText: Colors.white,
        );
        return;
      }
    }
    setState(() => _selectedIds.add(id));
  }

  Future<void> _deleteSuggestion(
    BuildContext context,
    ProgrammingUpdateModel update,
  ) async {
    final id = update.id;
    if (id == null || id.isEmpty) return;
    await FunHelper.showConfirmDailog(
      context,
      title: 'tasks.confirm_delete_title'.tr,
      message: 'programming.updates.delete_confirm'.tr,
      confirmText: 'delete'.tr,
      confirmColor: Colors.red,
      onTap: () async {
        await Get.find<HomeController>().deleteProgrammingUpdate(id);
        if (mounted) setState(() => _selectedIds.remove(id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final theme = context.appTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'programming.suggestions.title'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _suggestionTextField(
            context,
            controller: _nameController,
            hint: 'programming.suggestions.feature_name_hint'.tr,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _suggestionTextField(
                  context,
                  controller: _descriptionController,
                  hint: 'programming.suggestions.description_hint'.tr,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'tasks.form.voice_record'.tr,
                        icon: Icon(
                          _showVoiceField ? Icons.mic : Icons.mic_none,
                          color: _showVoiceField
                              ? AppColors.primary
                              : theme.mutedText,
                        ),
                        onPressed: () =>
                            setState(() => _showVoiceField = !_showVoiceField),
                      ),
                      IconButton(
                        tooltip: 'dragfile'.tr,
                        icon: Icon(
                          Icons.image_outlined,
                          color: theme.mutedText,
                        ),
                        onPressed: () => _attachImages(controller),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Obx(
                () => MainButton(
                  width: 96,
                  height: 46,
                  borderSize: 12,
                  fontColor: Colors.white,
                  backgroundColor: AppColors.primary,
                  load: controller.isUploading.value,
                  title: 'programming.suggestions.add_button'.tr,
                  onPressed: () => _addSuggestion(controller),
                ),
              ),
            ],
          ),
          if (_showVoiceField) ...[
            const SizedBox(height: 10),
            TaskVoiceRecordField(
              records: _pendingVoice,
              onRecordsChanged: (v) => setState(() => _pendingVoice = v),
            ),
          ],
          FormAttachmentThumbnailsGrid(
            urls: List<String>.from(_pendingFiles),
            onRemoveUrl: (u) => setState(() => _pendingFiles.remove(u)),
            onOpenUrl: (u) async => openUrlPreferInAppMedia(u),
            spacing: 6,
            tileExtent: 80,
          ),
          const SizedBox(height: 18),
          Obx(() {
            final pending = controller.programmingUpdates
                .where((u) => u.isPending)
                .toList();
            if (pending.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'programming.updates.empty_pending'.tr,
                    style: TextStyle(color: theme.mutedText),
                  ),
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final update in pending)
                      SizedBox(
                        width: cardWidth,
                        child: _SuggestionCard(
                          update: update,
                          selected: _selectedIds.contains(update.id),
                          onToggle: (id) => _toggleSelect(id, pending),
                          onView: (u) =>
                              showProgrammingUpdateDetails(context, update: u),
                          onDelete: (u) => _deleteSuggestion(context, u),
                          onConvert: (u) =>
                              _openCreateTaskFromUpdates(context, [u]),
                        ),
                      ),
                  ],
                );
              },
            );
          }),
          const SizedBox(height: 16),
          Obx(() {
            final pending = controller.programmingUpdates
                .where((u) => u.isPending)
                .toList();
            final enabled = _selectedIds.isNotEmpty;
            return MainButton(
              width: double.infinity,
              height: 48,
              borderSize: 30,
              fontColor: Colors.white,
              backgroundColor: AppColors.primary,
              enabled: enabled,
              widget: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'programming.suggestions.create_task_button'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              onPressed: () {
                final selected = pending
                    .where((u) => u.id != null && _selectedIds.contains(u.id))
                    .toList();
                _openCreateTaskFromUpdates(context, selected);
                setState(() => _selectedIds.clear());
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _suggestionTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    Widget? trailing,
  }) {
    final theme = context.appTheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.unselected,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: theme.primaryText, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: theme.mutedText, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          suffixIcon: trailing,
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final ProgrammingUpdateModel update;
  final bool selected;
  final ValueChanged<String> onToggle;
  final void Function(ProgrammingUpdateModel) onView;
  final void Function(ProgrammingUpdateModel) onDelete;
  final void Function(ProgrammingUpdateModel) onConvert;

  const _SuggestionCard({
    required this.update,
    required this.selected,
    required this.onToggle,
    required this.onView,
    required this.onDelete,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final id = update.id ?? '';
    final title = update.title.trim().isNotEmpty
        ? update.title.trim()
        : 'programming.updates.update_n'.trParams({'n': '1'});
    final statusFg = context.statusChipForeground(Colors.green);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBg = isDark
        ? Colors.green.withValues(alpha: 0.18)
        : Colors.green.shade50;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onView(update),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.panelTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (id.isNotEmpty)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: selected,
                      side: BorderSide(color: theme.mutedText, width: 1.5),
                      onChanged: (_) => onToggle(id),
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'programming.suggestions.status_pending'.tr,
                    style: TextStyle(
                      color: statusFg,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.primaryText,
              ),
            ),
            if (update.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                update.description.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: theme.secondaryText),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onConvert(update),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.accentText,
                      side: BorderSide(color: theme.accentText),
                      backgroundColor: theme.accentText.withValues(
                        alpha: isDark ? 0.12 : 0.06,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      'programming.suggestions.convert_button'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => onDelete(update),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'delete'.tr,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
