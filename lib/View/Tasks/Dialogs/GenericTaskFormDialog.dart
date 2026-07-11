import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Shared/form_attachment_thumbnails_grid.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Tasks/Dialogs/TaskFormDialogDelegate.dart';
import 'package:point/View/Tasks/Dialogs/task_dialog_constants.dart';
import 'package:point/View/Tasks/Dialogs/TaskFormDialogHeader.dart';
import 'package:point/View/Tasks/Shared/task_form_dialog_actions.dart';
import 'package:point/View/Tasks/Shared/task_voice_form_helpers.dart';
import 'package:point/View/Tasks/Shared/task_voice_record_field.dart';
import 'package:point/Models/VoiceRecordEntry.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Generic web dialog for add/edit task. Renders common fields and delegates
/// type-specific fields and task building to [TaskFormDialogDelegate].
class GenericTaskFormDialog extends StatefulWidget {
  final TaskModel? model;
  final TaskFormDialogDelegate delegate;

  const GenericTaskFormDialog({
    super.key,
    this.model,
    required this.delegate,
  });

  @override
  State<GenericTaskFormDialog> createState() => _GenericTaskFormDialogState();
}

class _GenericTaskFormDialogState extends State<GenericTaskFormDialog> {
  static const String _otherClientValue = kTaskOtherClientSentinel;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _executorController;
  late final TextEditingController _clientController;
  late final TextEditingController _customClientController;
  late final TextEditingController _priorityController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _notesController;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _useCustomClient = false;
  List<VoiceRecordEntry> _voiceRecords = const [];

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _titleController = TextEditingController(text: m?.title);
    _executorController = TextEditingController(text: m?.assignedTo);
    _clientController = TextEditingController(text: m?.clientName);
    _customClientController = TextEditingController();
    _priorityController = TextEditingController(text: m?.priority);
    _startDateController = TextEditingController(text: FunHelper.formatdate(m?.fromDate));
    _endDateController = TextEditingController(text: FunHelper.formatdate(m?.toDate));
    _notesController = TextEditingController(text: m?.description ?? '');
    _startAt = m?.fromDate;
    _endAt = m?.toDate;
    _voiceRecords = voiceRecordsFromTask(m);
    Get.find<HomeController>().uploadedFilesPaths.assignAll(m?.files ?? []);
    widget.delegate.initFromModel(m);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _executorController.dispose();
    _clientController.dispose();
    _customClientController.dispose();
    _priorityController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _notesController.dispose();
    widget.delegate.dispose();
    super.dispose();
  }

  double get _dialogWidth => (Get.width * 0.7).clamp(300.0, Get.width - 24.0);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.appTheme.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: GetBuilder<HomeController>(
        builder: (controller) {
          return Form(
            key: _formKey,
            child: SizedBox(
              width: _dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TaskFormDialogHeader(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildTitleAndExecutorRow(controller),
                          _buildClientRow(controller),
                          widget.delegate.buildTypeSpecificFields(context, _dialogWidth),
                          _buildPriorityRow(controller),
                          _buildDatesRow(context),
                          _buildNotesAndAttachmentsRow(controller),
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TaskVoiceRecordField(
                              records: _voiceRecords,
                              onRecordsChanged: (v) =>
                                  setState(() => _voiceRecords = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildActions(controller),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitleAndExecutorRow(HomeController controller) {
    final w = (_dialogWidth / 2) - 25;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: w.clamp(60.0, double.infinity),
          child: InputText(
            labelText: 'tasks.form.title_short'.tr,
            hintText: 'tasks.form.write_title_hint'.tr,
            height: 42,
            controller: _titleController,
            validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
            borderRadius: 5,
          ),
        ),
        SizedBox(
          width: w.clamp(60.0, double.infinity),
          child: DynamicDropdown(
            items: controller.employees
                .where(
                  (a) => a.hasDepartment(
                    widget.delegate.executorDepartment,
                  ) ||
                  (((controller.currentEmployee.value?.role == 'admin') ||
                          (controller.currentEmployee.value?.role ==
                              'supervisor')) &&
                      a.id == controller.currentEmployee.value?.id),
                )
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text('${v.name} (${v.role})'),
                  ),
                )
                .toList(),
            value: _executorController.text.isEmpty
                ? null
                : controller.employees.firstWhereOrNull(
                    (a) => a.id == _executorController.text,
                  ),
            label: 'tasks.form.select_executor'.tr,
            borderRadius: 5,
            height: 42,
            onChanged: (value) {
              if (value != null) _executorController.text = value.id ?? '';
            },
            validator: (v) => v == null ? ' ' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildClientRow(HomeController controller) {
    final matchedClient = controller.clients.firstWhereOrNull(
      (a) => a.id == _clientController.text,
    );
    if (!_useCustomClient &&
        _clientController.text.isNotEmpty &&
        matchedClient == null) {
      _useCustomClient = true;
      _customClientController.text = _clientController.text;
    }

    final w = (_dialogWidth / 2) - 20;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: w,
                child: DynamicDropdown<dynamic>(
                  items: [
                    ...controller.clients
                        .map((v) => DropdownMenuItem(value: v, child: Text('${v.name}'))),
                    DropdownMenuItem(
                      value: _otherClientValue,
                      child: Text('tasks.other_client'.tr),
                    ),
                  ],
                  value: _useCustomClient
                      ? _otherClientValue
                      : (_clientController.text.isEmpty ? null : matchedClient),
                  label: 'chooseclient'.tr,
                  borderRadius: 5,
                  height: 42,
                  onChanged: (value) {
                    setState(() {
                      if (value == _otherClientValue) {
                        _useCustomClient = true;
                        _clientController.text = '';
                      } else if (value != null) {
                        _useCustomClient = false;
                        _clientController.text = value.id ?? '';
                      }
                    });
                  },
                  validator: (v) => v == null ? ' ' : null,
                ),
              ),
            ],
          ),
          if (_useCustomClient)
            SizedBox(
              width: w,
              child: InputText(
                labelText: 'tasks.form.client_name_label'.tr,
                hintText: 'tasks.form.client_name_hint'.tr,
                height: 42,
                controller: _customClientController,
                validator: (v) => (v == null || v.trim().isEmpty) ? ' ' : null,
                borderRadius: 5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriorityRow(HomeController controller) {
    final w = (_dialogWidth / 3) - 25;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: w.clamp(60.0, double.infinity),
            child: DynamicDropdown<String>(
              items: StorageKeys.priority
                  .map((v) => DropdownMenuItem(value: v, child: Text(v.tr)))
                  .toList(),
              value: _priorityController.text.isEmpty ? null : _priorityController.text,
              label: 'priortity'.tr,
              borderRadius: 5,
              height: 42,
              onChanged: (value) {
                if (value != null) _priorityController.text = value;
              },
              validator: (v) => v == null ? ' ' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesRow(BuildContext context) {
    final w = (_dialogWidth / 2) - 25;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: w,
            child: InputText(
              onTap: () async {
                final picked = await customDatePicker(
                  context,
                  initialDateTime: _startAt,
                );
                if (picked != null) {
                  setState(() {
                    _startAt = picked;
                    _startDateController.text =
                        DateFormat('dd MM yyyy - hh:mm a').format(picked.toLocal());
                  });
                }
              },
              labelText: 'startat'.tr,
              hintText: '1/10/2025'.tr,
              height: 42,
              textInputType: TextInputType.datetime,
              controller: _startDateController,
              readOnly: true,
              validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
              suffixIcon: Icon(CupertinoIcons.calendar, color: context.appTheme.secondaryText),
              borderRadius: 5,
            ),
          ),
          SizedBox(
            width: w,
            child: InputText(
              onTap: () async {
                final picked = await customDatePicker(
                  context,
                  initialDateTime: _endAt,
                );
                if (picked != null) {
                  setState(() {
                    _endAt = picked;
                    _endDateController.text =
                        DateFormat('dd MM yyyy - hh:mm a').format(picked.toLocal());
                  });
                }
              },
              labelText: 'endat'.tr,
              hintText: '1/10/2026'.tr,
              height: 42,
              textInputType: TextInputType.datetime,
              controller: _endDateController,
              readOnly: true,
              validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
              suffixIcon: Icon(CupertinoIcons.calendar, color: context.appTheme.secondaryText),
              borderRadius: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesAndAttachmentsRow(HomeController controller) {
    final w = (_dialogWidth / 2) - 30;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.model != null)
                SizedBox(
                  width: (_dialogWidth / 2) - 25,
                  child: InputText(
                    labelText: 'tasks.form.notes_log'.tr,
                    hintText: '',
                    height: 250,
                    enable: false,
                    body: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var note in widget.model!.notes)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note.note,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: context.appTheme.primaryText,
                                  ),
                                ),
                                Text(
                                  note.byWho,
                                  style: TextStyle(fontSize: 12, color: Colors.green),
                                ),
                                const SizedBox(height: 5),
                              ],
                            ),
                        ],
                      ),
                    ),
                    expanded: true,
                    borderRadius: 5,
                  ),
                ),
              SizedBox(
                width: (_dialogWidth / 2) - 25,
                child: InputText(
                  labelText: 'notes'.tr,
                  hintText: 'enternotes'.tr,
                  height: 30,
                  controller: _notesController,
                  borderRadius: 5,
                ),
              ),
            ],
          ),
          Obx(
            () => Column(
              children: [
                SizedBox(
                  width: w,
                  child: GestureDetector(
                    onTap: () async {
                      final files = await controller.pickMultiFiles();
                      for (var file in files) {
                        controller.uploadFiles(
                          filePathOrBytes: file.bytes!,
                          fileName: file.name,
                        );
                      }
                    },
                    child: InputText(
                      labelText: 'dragfile'.tr,
                      hintText: '',
                      enable: false,
                      height: 100,
                      expanded: true,
                      body: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(color: context.appTheme.unselected),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'dragfile'.tr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            MainButton(
                              width: 100,
                              borderSize: 5,
                              height: 30,
                              fontSize: 12,
                              load: controller.isUploading.value,
                              title: 'uploadfile'.tr,
                              backgroundColor: context.appTheme.cardSurface,
                              fontColor: context.appTheme.primaryText,
                            ),
                          ],
                        ),
                      ),
                      borderRadius: 5,
                    ),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: Obx(
                    () => FormAttachmentThumbnailsGrid(
                      urls:
                          controller.uploadedFilesPaths
                              .map((e) => e.toString())
                              .toList(),
                      onRemoveUrl: (u) {
                        controller.uploadedFilesPaths.removeWhere(
                          (e) => e.toString() == u,
                        );
                      },
                      onOpenUrl: (u) async => await openUrlPreferInAppMedia(u),
                      spacing: 6,
                      tileExtent: 88,
                      closeButtonSize: 20,
                      closeIconSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(HomeController controller) {
    return Obx(
      () => TaskFormDialogActions(
        isLoading: controller.isLoading.value,
        onSave: () => _onSave(controller),
        saveLabel: (widget.model != null &&
                ((controller.currentEmployee.value?.role == 'admin') ||
                    (controller.currentEmployee.value?.role == 'supervisor')))
            ? 'edit'.tr
            : 'common.save'.tr,
      ),
    );
  }

  Future<void> _onSave(HomeController controller) async {
    final fallbackDate = DateTime.now();
    final fromDate = _startAt ?? fallbackDate;
    final toDate = _endAt ?? fromDate;
    final resolvedClientName = _useCustomClient
        ? _customClientController.text.trim()
        : _clientController.text.trim();
    final notes = widget.model?.notes ?? [];
    final common = CommonFormData(
      title: _titleController.text,
      description: _notesController.text,
      priority: _priorityController.text,
      fromDate: fromDate,
      toDate: toDate,
      assignedTo: _executorController.text,
      clientName: resolvedClientName,
      assignedImageUrl: controller.employees
              .firstWhereOrNull((a) => a.id == _executorController.text)
              ?.image ??
          '',
      notes: notes,
      // On edit, the notes field is [TaskModel.description] only — comments use
      // [TaskModel.notes] via add-comment flows; do not treat description as newNoteText.
      newNoteText: widget.model == null
          ? (_notesController.text.isEmpty ? null : _notesController.text)
          : null,
      newNoteAuthor: controller.currentEmployee.value?.name,
      files: controller.uploadedFilesPaths.cast<String>().toList(),
      voiceRecords: _voiceRecords,
      voiceRecordUrl: VoiceRecordEntry.primaryUrl(_voiceRecords),
      voiceRecordDurationSec:
          VoiceRecordEntry.primaryDurationSec(_voiceRecords),
    );
    final task = applyVoiceRecordsToTask(
      widget.delegate.buildTask(common, widget.model, controller),
      _voiceRecords,
    );
    if (widget.model == null) {
      await controller.addTask(task);
      Get.back();
      controller.uploadedFilesPaths.clear();
    } else {
      controller.updateTask(task);
      Get.back();
      controller.uploadedFilesPaths.clear();
    }
  }
}
