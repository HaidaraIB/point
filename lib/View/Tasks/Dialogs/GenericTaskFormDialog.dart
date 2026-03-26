import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Tasks/Dialogs/TaskFormDialogDelegate.dart';
import 'package:point/View/Tasks/Dialogs/TaskFormDialogHeader.dart';

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
  static const String _otherClientValue = '__other_client__';
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
    _notesController = TextEditingController();
    _startAt = m?.fromDate;
    _endAt = m?.toDate;
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
      backgroundColor: Colors.white,
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
            fillColor: Colors.white,
            controller: _titleController,
            validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
            borderRadius: 5,
            borderColor: Colors.grey.shade300,
          ),
        ),
        SizedBox(
          width: w.clamp(60.0, double.infinity),
          child: DynamicDropdown(
            items: controller.employees
                .where((a) => a.department == widget.delegate.executorDepartment)
                .map((v) => DropdownMenuItem(value: v, child: Text('${v.name} (${v.role})')))
                .toList(),
            value: _executorController.text.isEmpty
                ? null
                : controller.employees.firstWhereOrNull(
                    (a) => a.id == _executorController.text,
                  ),
            label: 'tasks.form.select_executor'.tr,
            borderRadius: 5,
            borderColor: Colors.grey.shade300,
            height: 42,
            fillColor: Colors.white,
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
                  borderColor: Colors.grey.shade300,
                  height: 42,
                  fillColor: Colors.white,
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
                fillColor: Colors.white,
                controller: _customClientController,
                validator: (v) => (v == null || v.trim().isEmpty) ? ' ' : null,
                borderRadius: 5,
                borderColor: Colors.grey.shade300,
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
              borderColor: Colors.grey.shade300,
              height: 42,
              fillColor: Colors.white,
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
                final picked = await customDatePicker(context);
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
              fillColor: Colors.white,
              textInputType: TextInputType.datetime,
              controller: _startDateController,
              readOnly: true,
              validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
              suffixIcon: Icon(CupertinoIcons.calendar, color: Colors.grey),
              borderRadius: 5,
              borderColor: Colors.grey.shade300,
            ),
          ),
          SizedBox(
            width: w,
            child: InputText(
              onTap: () async {
                final picked = await customDatePicker(context);
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
              fillColor: Colors.white,
              textInputType: TextInputType.datetime,
              controller: _endDateController,
              readOnly: true,
              validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
              suffixIcon: Icon(CupertinoIcons.calendar, color: Colors.grey),
              borderRadius: 5,
              borderColor: Colors.grey.shade300,
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
                    fillColor: Colors.white,
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
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryfontColor,
                                  ),
                                ),
                                Text(
                                  note.byWho,
                                  style: const TextStyle(fontSize: 12, color: Colors.green),
                                ),
                                const SizedBox(height: 5),
                              ],
                            ),
                        ],
                      ),
                    ),
                    expanded: true,
                    borderRadius: 5,
                    borderColor: Colors.grey.shade300,
                  ),
                ),
              SizedBox(
                width: (_dialogWidth / 2) - 25,
                child: InputText(
                  labelText: 'notes'.tr,
                  hintText: 'enternotes'.tr,
                  height: 30,
                  fillColor: Colors.white,
                  controller: _notesController,
                  borderRadius: 5,
                  borderColor: Colors.grey.shade300,
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
                      fillColor: Colors.white,
                      expanded: true,
                      body: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(color: Colors.grey.shade200),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'dragfile'.tr,
                                style: const TextStyle(
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
                              backgroundColor: Colors.white,
                              fontColor: AppColors.primaryfontColor,
                            ),
                          ],
                        ),
                      ),
                      borderRadius: 5,
                      borderColor: Colors.grey.shade300,
                    ),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: Obx(
                    () {
                      final files = controller.uploadedFilesPaths.toList();
                      if (files.isEmpty) return const SizedBox.shrink();
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: files.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              mainAxisExtent: 96,
                            ),
                        itemBuilder: (context, index) {
                          final filePath = files[index];
                          final lower = filePath.toString().toLowerCase();
                          final isImage =
                              lower.endsWith('.jpg') ||
                              lower.endsWith('.jpeg') ||
                              lower.endsWith('.png') ||
                              lower.endsWith('.webp') ||
                              lower.endsWith('.gif');
                          return Center(
                            child: SizedBox(
                              width: 88,
                              height: 88,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child:
                                          isImage
                                              ? Image.network(
                                                filePath,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (_, __, ___) => Container(
                                                      color: Colors
                                                          .blueGrey
                                                          .shade100,
                                                      child: Icon(
                                                        Icons.link,
                                                        color: Colors
                                                            .blueGrey
                                                            .shade700,
                                                      ),
                                                    ),
                                              )
                                              : Container(
                                                color: Colors.blueGrey.shade100,
                                                child: Icon(
                                                  Icons.link,
                                                  color: Colors
                                                      .blueGrey
                                                      .shade700,
                                                ),
                                              ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: InkWell(
                                      onTap:
                                          () => controller.uploadedFilesPaths
                                              .remove(filePath),
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Obx(
            () => SizedBox(
              width: Get.width * 0.4 - 260,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C5589),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                ),
                onPressed: () => _onSave(controller),
                child: controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : Text('common.save'.tr, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 160,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr),
            ),
          ),
        ],
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
      newNoteText: _notesController.text.isEmpty ? null : _notesController.text,
      newNoteAuthor: controller.currentemployee.value?.name,
      files: controller.uploadedFilesPaths.cast<String>().toList(),
    );
    final task = widget.delegate.buildTask(common, widget.model, controller);
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
