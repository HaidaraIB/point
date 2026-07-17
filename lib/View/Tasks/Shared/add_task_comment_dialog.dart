import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Models/VoiceRecordEntry.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Tasks/Shared/task_voice_record_field.dart';

Future<void> showAddTaskCommentDialog({
  required BuildContext context,
  required TaskModel task,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _AddTaskCommentDialog(task: task),
  );
}

class _AddTaskCommentDialog extends StatefulWidget {
  final TaskModel task;

  const _AddTaskCommentDialog({required this.task});

  @override
  State<_AddTaskCommentDialog> createState() => _AddTaskCommentDialogState();
}

class _AddTaskCommentDialogState extends State<_AddTaskCommentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  List<VoiceRecordEntry> _voiceRecords = const [];
  var _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _commentController.text.trim().isNotEmpty || _voiceRecords.isNotEmpty;

  Future<void> _save() async {
    if (_saving) return;
    // Validate text only when there is no voice note.
    if (_voiceRecords.isEmpty && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_hasContent) {
      _formKey.currentState?.validate();
      return;
    }

    setState(() => _saving = true);
    final controller = Get.find<HomeController>();
    final author =
        controller.currentEmployee.value?.name?.trim().isNotEmpty == true
            ? controller.currentEmployee.value!.name!.trim()
            : 'employee.fallback_name'.tr;
    final note = NoteModel(
      note: _commentController.text.trim(),
      byWho: author,
      timestamp: DateTime.now(),
      voiceRecords: List<VoiceRecordEntry>.from(_voiceRecords),
    );
    try {
      await controller.updateTask(
        widget.task.copyWith(notes: [...widget.task.notes, note]),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final BoxConstraints? dialogConstraints;
    if (kIsWeb) {
      final size = MediaQuery.sizeOf(context);
      final w = size.width;
      final h = size.height;
      final horizontalInset = 40.0 * 2;
      final maxAllowed = (w - horizontalInset).clamp(280.0, 1200.0);
      final target = (w * 0.72).clamp(560.0, 960.0);
      final dialogWidth = target.clamp(280.0, maxAllowed);
      final verticalInset = 24.0 * 2;
      final maxAllowedH = (h - verticalInset).clamp(200.0, 1200.0);
      final targetH = (h * 0.55).clamp(400.0, 680.0);
      final dialogMinHeight = targetH <= maxAllowedH ? targetH : maxAllowedH;
      dialogConstraints = BoxConstraints(
        minWidth: dialogWidth,
        maxWidth: dialogWidth,
        minHeight: dialogMinHeight,
      );
    } else {
      dialogConstraints = null;
    }

    return AlertDialog(
      constraints: dialogConstraints,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.appTheme.panelTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.add_comment_outlined,
              color: context.appTheme.accentText,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'tasks.add_comment_title'.tr,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.appTheme.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _commentController,
                minLines: kIsWeb ? 8 : 3,
                maxLines: kIsWeb ? 14 : 5,
                maxLength: 500,
                enabled: !_saving,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: context.appTheme.primaryText),
                decoration: InputDecoration(
                  labelText: 'tasks.comment_label'.tr,
                  hintText: 'employee.comment_hint'.tr,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.appTheme.accentBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: context.appTheme.accentBorder,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (value) {
                  if (_voiceRecords.isNotEmpty) return null;
                  if ((value ?? '').trim().isEmpty) {
                    return 'validation.comment_required'.tr;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TaskVoiceRecordField(
                records: _voiceRecords,
                onRecordsChanged: (v) => setState(() => _voiceRecords = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocaleKeys.commonCancel.tr),
        ),
        ElevatedButton(
          onPressed: _saving || !_hasContent ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr),
        ),
      ],
    );
  }
}
