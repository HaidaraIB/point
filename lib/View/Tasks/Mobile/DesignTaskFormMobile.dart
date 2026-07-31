import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/DesignTaskModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/form_attachment_thumbnails_grid.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/t.dart';
import 'package:point/View/Tasks/Dialogs/task_dialog_constants.dart';
import 'package:point/View/Tasks/Shared/task_voice_form_helpers.dart';
import 'package:point/View/Tasks/Shared/task_note_body.dart';
import 'package:point/View/Tasks/Shared/task_voice_record_field.dart';
import 'package:point/Models/VoiceRecordEntry.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/media_url_opener.dart';

/// Mobile-only full-screen add/edit design task form.
/// Opened when designDialog() is called on mobile; desktop keeps the dialog.
class DesignTaskFormMobilePage extends StatefulWidget {
  final TaskModel? model;

  const DesignTaskFormMobilePage({super.key, this.model});

  @override
  State<DesignTaskFormMobilePage> createState() => _DesignTaskFormMobilePageState();
}

class _DesignTaskFormMobilePageState extends State<DesignTaskFormMobilePage> {
  static const String _otherClientValue = kTaskOtherClientSentinel;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController executorController;
  late final TextEditingController taskTypeController;
  late final RxList<dynamic> platforms;
  late final TextEditingController clientController;
  late final TextEditingController customClientController;
  late final TextEditingController designTypeController;
  late final TextEditingController priorityController;
  late final TextEditingController designsCountController;
  late final TextEditingController dimensionsController;
  late final TextEditingController startDateController;
  late final TextEditingController endDateController;
  late final TextEditingController notesController;

  DateTime? startAt;
  DateTime? endAt;
  bool useCustomClient = false;
  List<VoiceRecordEntry> _voiceRecords = const [];

  TaskModel _applyVoice(TaskModel task) =>
      applyVoiceRecordsToTask(task, _voiceRecords);

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    titleController = TextEditingController(text: m?.title);
    executorController = TextEditingController(text: m?.assignedTo);
    taskTypeController = TextEditingController(text: m?.designDetails?.taskType);
    platforms = normalizeTaskFormPlatformSelections(
      List<dynamic>.from(m?.designDetails?.platform ?? const []),
    ).obs;
    clientController = TextEditingController(text: m?.clientName);
    customClientController = TextEditingController();
    designTypeController = TextEditingController(text: m?.designDetails?.designType);
    priorityController = TextEditingController(text: m?.priority);
    designsCountController = TextEditingController(text: m?.designDetails?.designCount);
    dimensionsController = TextEditingController(text: m?.designDetails?.designsDimensions);
    startDateController = TextEditingController(text: FunHelper.formatdate(m?.fromDate));
    endDateController = TextEditingController(text: FunHelper.formatdate(m?.toDate));
    notesController = TextEditingController(text: m?.description ?? '');
    startAt = m?.fromDate;
    endAt = m?.toDate;
    _voiceRecords = voiceRecordsFromTask(m);
    Get.find<HomeController>().uploadedFilesPaths.assignAll(
      List.from(m?.files ?? []),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    executorController.dispose();
    taskTypeController.dispose();
    clientController.dispose();
    customClientController.dispose();
    designTypeController.dispose();
    priorityController.dispose();
    designsCountController.dispose();
    dimensionsController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await customDatePicker(
      context,
      initialDateTime: startAt,
    );
    if (picked != null && mounted) {
      setState(() {
        startAt = picked;
        startDateController.text = DateFormat('dd MM yyyy - hh:mm a').format(picked.toLocal());
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await customDatePicker(
      context,
      initialDateTime: endAt,
    );
    if (picked != null && mounted) {
      setState(() {
        endAt = picked;
        endDateController.text = DateFormat('dd MM yyyy - hh:mm a').format(picked.toLocal());
      });
    }
  }

  void _submit() async {
    final fallbackDate = DateTime.now();
    final effectiveStartAt = startAt ?? fallbackDate;
    final effectiveEndAt = endAt ?? effectiveStartAt;
    final controller = Get.find<HomeController>();
    final resolvedClientName = useCustomClient
        ? customClientController.text.trim()
        : clientController.text.trim();
    final model = widget.model;
    final keepStatusUnchanged =
        controller.currentEmployee.value?.role == 'admin' ||
        controller.currentEmployee.value?.role == 'supervisor';
    final safeEmployees = (controller.employees as List<EmployeeModel>?) ?? <EmployeeModel>[];

    if (model == null) {
      await controller.addTask(
        _applyVoice(
          TaskModel(
          title: titleController.text,
          description: notesController.text,
          status: StorageKeys.status_not_start_yet,
          priority: priorityController.text,
          fromDate: effectiveStartAt,
          toDate: effectiveEndAt,
          assignedTo: executorController.text,
          clientName: resolvedClientName,
          assignedImageUrl: safeEmployees.firstWhereOrNull((a) => a.id == executorController.text)?.image ?? '',
          notes: notesController.text.isEmpty
              ? []
              : [
                  NoteModel(
                    note: notesController.text,
                    byWho: controller.currentEmployee.value?.name ?? '',
                    timestamp: DateTime.now(),
                  ),
                ],
          actionText: '',
          files: controller.uploadedFilesPaths,
          type: '1',
          designDetails: DesignTaskModel(
            designsDimensions: dimensionsController.text,
            taskType: taskTypeController.text,
            platform: platforms,
            designType: designTypeController.text,
            designCount: designsCountController.text,
          ),
        ),
        ),
      );
      if (!mounted) return;
      Get.back();
      controller.uploadedFilesPaths.clear();
    } else {
      await controller.updateTask(
        _applyVoice(
          TaskModel(
          id: model.id,
          title: titleController.text,
          description: notesController.text,
          status: keepStatusUnchanged
              ? model.status
              : StorageKeys.status_edit_requested,
          priority: priorityController.text,
          fromDate: effectiveStartAt,
          toDate: effectiveEndAt,
          assignedTo: executorController.text,
          clientName: resolvedClientName,
          assignedImageUrl: safeEmployees.firstWhereOrNull((a) => a.id == executorController.text)?.image ?? '',
          actionText: '',
          files: controller.uploadedFilesPaths.cast<String>().toList(),
          notes: model.notes,
          type: '1',
          designDetails: DesignTaskModel(
            designsDimensions: dimensionsController.text,
            taskType: taskTypeController.text,
            platform: platforms,
            designType: designTypeController.text,
            designCount: designsCountController.text,
          ),
        ),
        ),
      );
      if (!mounted) return;
      Get.back();
      controller.uploadedFilesPaths.clear();
    }
  }

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
          widget.model == null ? 'tasks.form.add_title'.tr : 'tasks.form.edit_title'.tr,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: GetBuilder<HomeController>(
        builder: (controller) {
          final safeEmployees = (controller.employees as List<EmployeeModel>?) ?? <EmployeeModel>[];
          final safeClients = (controller.clients as List<ClientModel>?) ?? <ClientModel>[];
          final matchedClient = safeClients.firstWhereOrNull((a) => a.id == clientController.text);
          if (!useCustomClient && clientController.text.isNotEmpty && matchedClient == null) {
            useCustomClient = true;
            customClientController.text = clientController.text;
          }

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionLabel('tasks.form.section_task_data'.tr),
                  InputText(
                    labelText: 'tasks.form.design_title_label'.tr,
                    hintText: 'tasks.form.design_name_hint'.tr,
                    height: 48,
                    controller: titleController,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  DynamicDropdown<EmployeeModel>(
                    items: safeEmployees
                        .where(
                          (a) => a.canBeAssignedAsExecutorFor(
                            StorageKeys.departmentDesign,
                          ),
                        )
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('${v.name} (${v.role})'),
                          ),
                        )
                        .toList(),
                    value: executorController.text.isEmpty ? null : safeEmployees.firstWhereOrNull((a) => a.id == executorController.text),
                    label: 'content.dialog.executor'.tr,
                    borderRadius: 8,
                    height: 48,
                    onChanged: (value) {
                      if (value != null) executorController.text = value.id ?? '';
                    },
                    validator: (v) => v == null ? ' ' : null,
                  ),
                  const SizedBox(height: 16),
                  DynamicDropdown<String>(
                    items: StorageKeys.tasktype.map((v) => DropdownMenuItem(value: v, child: Text(v.tr))).toList(),
                    value: taskTypeController.text.isEmpty ? null : taskTypeController.text,
                    label: 'tasks.form.task_type_label'.tr,
                    borderRadius: 8,
                    height: 48,
                    onChanged: (value) {
                      if (value != null) taskTypeController.text = value;
                    },
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('tasks.form.section_client_platform'.tr),
                  DynamicDropdown<dynamic>(
                    items: [
                      ...safeClients.map((v) => DropdownMenuItem(value: v, child: Text('${v.name}'))),
                      DropdownMenuItem(
                        value: _otherClientValue,
                        child: Text('tasks.other_client'.tr),
                      ),
                    ],
                    value: useCustomClient ? _otherClientValue : (clientController.text.isEmpty ? null : matchedClient),
                    label: 'chooseclient'.tr,
                    borderRadius: 8,
                    height: 48,
                    onChanged: (value) {
                      setState(() {
                        if (value == _otherClientValue) {
                          useCustomClient = true;
                          clientController.text = '';
                        } else if (value != null) {
                          useCustomClient = false;
                          clientController.text = value.id ?? '';
                        }
                      });
                    },
                    validator: (v) => v == null ? ' ' : null,
                  ),
                  if (useCustomClient) ...[
                    const SizedBox(height: 12),
                    InputText(
                      labelText: 'tasks.form.client_name_label'.tr,
                      hintText: 'tasks.form.client_name_hint'.tr,
                      height: 48,
                      controller: customClientController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? ' ' : null,
                      borderRadius: 8,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Obx(
                    () => DynamicDropdownMultiSelect<String>(
                      items: StorageKeys.platformList.map((v) => v.tr).toList(),
                      selectedValues: platforms.cast<String>().toList(),
                      itemLabel: (v) => v,
                      label: 'platform'.tr,
                      borderRadius: 8,
                      height: 48,
                      validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                      onChanged: (value) => platforms.assignAll(value),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('tasks.form.section_details'.tr),
                  DynamicDropdown<String>(
                    items: StorageKeys.designTypes.map((v) => DropdownMenuItem(value: v, child: Text(v.tr))).toList(),
                    value: designTypeController.text.isEmpty ? null : designTypeController.text,
                    label: 'tasks.form.design_type_label'.tr,
                    borderRadius: 8,
                    height: 48,
                    onChanged: (value) {
                      if (value != null) designTypeController.text = value;
                    },
                    validator: (v) => v == null ? ' ' : null,
                  ),
                  const SizedBox(height: 16),
                  DynamicDropdown<String>(
                    items: StorageKeys.priority.map((v) => DropdownMenuItem(value: v, child: Text(v.tr))).toList(),
                    value: priorityController.text.isEmpty ? null : priorityController.text,
                    label: 'priortity'.tr,
                    borderRadius: 8,
                    height: 48,
                    onChanged: (value) {
                      if (value != null) priorityController.text = value.toString();
                    },
                    validator: (v) => v == null ? ' ' : null,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: 'task_details.design_count'.tr,
                    hintText: 'task_details.design_count'.tr,
                    height: 48,
                    controller: designsCountController,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: 'task_details.dimensions'.tr,
                    hintText: 'tasks.form.write_dimensions_hint'.tr,
                    height: 48,
                    controller: dimensionsController,
                    validator: (val) => (val == null || val.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('tasks.form.section_dates'.tr),
                  InputText(
                    onTap: _pickStartDate,
                    labelText: 'startat'.tr,
                    hintText: '1/10/2025'.tr,
                    height: 48,
                    controller: startDateController,
                    readOnly: true,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    suffixIcon: Icon(CupertinoIcons.calendar, color: context.appTheme.mutedText),
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    onTap: _pickEndDate,
                    labelText: 'endat'.tr,
                    hintText: '1/10/2026'.tr,
                    height: 48,
                    controller: endDateController,
                    readOnly: true,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    suffixIcon: Icon(CupertinoIcons.calendar, color: context.appTheme.mutedText),
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 24),
                  if (widget.model != null && widget.model!.notes.isNotEmpty) ...[
                    _sectionLabel('tasks.form.notes_log'.tr),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
              color: context.appTheme.cardSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: widget.model!.notes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final note = widget.model!.notes[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TaskNoteBody(note: note),
                              const SizedBox(height: 4),
                              Text(
                                note.byWho,
                                style: TextStyle(fontSize: 12, color: Colors.green),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _sectionLabel('tasks.form.section_notes_attachments'.tr),
                  InputText(
                    labelText: 'notes'.tr,
                    hintText: 'enternotes'.tr,
                    height: 48,
                    controller: notesController,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final files = await controller.pickMultiFiles();
                      for (var file in files) {
                        controller.uploadFiles(filePathOrBytes: file.bytes!, fileName: file.name);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: context.appTheme.unselected,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.appTheme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('uploadfile'.tr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appTheme.secondaryText)),
                          Obx(() => controller.isUploading.value ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.upload_file, color: context.appTheme.accentText)),
                        ],
                      ),
                    ),
                  ),
                  Obx(
                    () => controller.uploadedFilesPaths.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: FormAttachmentThumbnailsGrid(
                              urls: controller.uploadedFilesPaths
                                  .map((e) => e.toString())
                                  .toList(),
                              onRemoveUrl: (u) {
                                controller.uploadedFilesPaths.removeWhere(
                                  (e) => e.toString() == u,
                                );
                              },
                              onOpenUrl: (u) async =>
                                  await openUrlPreferInAppMedia(u),
                              spacing: 10,
                              tileExtent: 96,
                              closeButtonSize: 20,
                              closeIconSize: 13,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TaskVoiceRecordField(
                    records: _voiceRecords,
                    onRecordsChanged: (v) =>
                        setState(() => _voiceRecords = v),
                  ),
                  const SizedBox(height: 32),
                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: controller.isLoading.value ? null : _submit,
                        child: controller.isLoading.value
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                (widget.model != null &&
                                        ((controller.currentEmployee.value
                                                    ?.role ==
                                                'admin') ||
                                            (controller.currentEmployee.value
                                                    ?.role ==
                                                'supervisor')))
                                    ? 'edit'.tr
                                    : 'common.save'.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Get.back(),
                    child: Text('common.cancel'.tr),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: context.appTheme.primaryText,
        ),
      ),
    );
  }
}
