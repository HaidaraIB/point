import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/translation_service.dart';
import 'package:point/View/Os/os_ai_generate_button.dart';
import 'package:point/View/Tasks/Shared/task_translation_form_state.dart';

/// Admin/supervisor button to generate the other app-language translation.
class TaskTranslationGenerateBar extends StatefulWidget {
  const TaskTranslationGenerateBar({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.translationState,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TaskTranslationFormState translationState;

  @override
  State<TaskTranslationGenerateBar> createState() =>
      _TaskTranslationGenerateBarState();
}

class _TaskTranslationGenerateBarState extends State<TaskTranslationGenerateBar> {
  bool _loading = false;

  bool _canGenerate(HomeController controller) {
    final role = controller.currentEmployee.value?.role ?? '';
    return role == 'admin' || role == 'supervisor';
  }

  Future<void> _generate() async {
    final title = widget.titleController.text.trim();
    final description = widget.descriptionController.text.trim();
    if (title.isEmpty && description.isEmpty) return;

    setState(() => _loading = true);
    try {
      final result = await TranslationService.instance.translateTaskFields(
        title: title,
        description: description,
      );
      if (!mounted) return;
      if (result == null) {
        FunHelper.showSnackbar(
          AppLocaleKeys.errorTitle.tr,
          AppLocaleKeys.tasksTranslationFailed.tr,
        );
        return;
      }
      widget.translationState.applyResult(result);
      widget.translationState.rememberCurrentFields(title, description);
      setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        if (!_canGenerate(controller)) return const SizedBox.shrink();

        widget.translationState.rememberCurrentFields(
          widget.titleController.text,
          widget.descriptionController.text,
        );
        final stale = widget.translationState.hasStaleFields &&
            (widget.translationState.titleTranslations.isNotEmpty ||
                widget.translationState.descriptionTranslations.isNotEmpty);

        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              OsAiGenerateButton(
                compact: true,
                isLoading: _loading,
                onPressed: _generate,
                icon: Icons.translate_outlined,
                label: _loading
                    ? AppLocaleKeys.tasksTranslationGenerating.tr
                    : AppLocaleKeys.tasksTranslationGenerate.tr,
              ),
              if (stale) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocaleKeys.tasksTranslationStale.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
