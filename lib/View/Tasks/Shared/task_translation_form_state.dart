import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/translation_service.dart';
import 'package:point/Utils/translation_text.dart';

/// Holds generated task title/description translations in a form.
class TaskTranslationFormState {
  Map<String, String> titleTranslations = {};
  Map<String, String> descriptionTranslations = {};
  String titleTranslationHash = '';
  String descriptionTranslationHash = '';

  void loadFromTask(TaskModel? task) {
    if (task == null) {
      clear();
      return;
    }
    titleTranslations = Map<String, String>.from(task.titleTranslations);
    descriptionTranslations =
        Map<String, String>.from(task.descriptionTranslations);
    titleTranslationHash = task.titleTranslationHash;
    descriptionTranslationHash = task.descriptionTranslationHash;
  }

  void clear() {
    titleTranslations = {};
    descriptionTranslations = {};
    titleTranslationHash = '';
    descriptionTranslationHash = '';
  }

  bool isTitleStale(String title) {
    final t = title.trim();
    if (t.isEmpty || titleTranslationHash.isEmpty) return false;
    return titleTranslationHash != translationTextHash(t);
  }

  bool isDescriptionStale(String description) {
    final d = description.trim();
    if (d.isEmpty || descriptionTranslationHash.isEmpty) return false;
    return descriptionTranslationHash != translationTextHash(d);
  }

  bool get hasStaleFields =>
      isTitleStale(_lastTitle) || isDescriptionStale(_lastDescription);

  String _lastTitle = '';
  String _lastDescription = '';

  void rememberCurrentFields(String title, String description) {
    _lastTitle = title;
    _lastDescription = description;
  }

  void applyResult(TaskTranslationResult result) {
    titleTranslations = Map<String, String>.from(result.titleTranslations);
    descriptionTranslations =
        Map<String, String>.from(result.descriptionTranslations);
    titleTranslationHash = result.titleSourceHash;
    descriptionTranslationHash = result.descriptionSourceHash;
  }

  TaskModel mergeInto(TaskModel task) {
    return task.copyWith(
      titleTranslations: titleTranslations,
      descriptionTranslations: descriptionTranslations,
      titleTranslationHash: titleTranslationHash,
      descriptionTranslationHash: descriptionTranslationHash,
    );
  }
}
