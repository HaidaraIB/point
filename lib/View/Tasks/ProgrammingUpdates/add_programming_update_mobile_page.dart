import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/ProgrammingUpdateModel.dart';
import 'package:point/Models/VoiceRecordEntry.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/form_attachment_thumbnails_grid.dart';
import 'package:point/View/Tasks/Dialogs/task_dialog_constants.dart';
import 'package:point/View/Tasks/Shared/task_form_dialog_actions.dart';
import 'package:point/View/Tasks/Shared/task_voice_form_helpers.dart';
import 'package:point/View/Tasks/Shared/task_voice_record_field.dart';

/// Mobile page for add/edit programming update.
class AddProgrammingUpdateMobilePage extends StatefulWidget {
  final ProgrammingUpdateModel? model;

  const AddProgrammingUpdateMobilePage({super.key, this.model});

  @override
  State<AddProgrammingUpdateMobilePage> createState() =>
      _AddProgrammingUpdateMobilePageState();
}

class _AddProgrammingUpdateMobilePageState
    extends State<AddProgrammingUpdateMobilePage> {
  static const _otherClient = kTaskOtherClientSentinel;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController executorController;
  late final TextEditingController clientController;
  late final TextEditingController customClientController;
  late final TextEditingController priorityController;
  late final TextEditingController categoryController;
  late final TextEditingController startDateController;
  late final TextEditingController endDateController;
  late final TextEditingController contenturlController;
  late final TextEditingController fileurlController;
  late final TextEditingController aboutTaskController;
  late final TextEditingController notesController;
  bool useCustomClient = false;
  List<VoiceRecordEntry> _voiceRecords = const [];
  DateTime? startAt;
  DateTime? endAt;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    titleController = TextEditingController(text: m?.title);
    executorController = TextEditingController(text: m?.assignedTo);
    clientController = TextEditingController(text: m?.clientName);
    customClientController = TextEditingController();
    priorityController = TextEditingController(text: m?.priority);
    categoryController = TextEditingController(text: m?.category);
    startDateController =
        TextEditingController(text: FunHelper.formatdate(m?.fromDate));
    endDateController =
        TextEditingController(text: FunHelper.formatdate(m?.toDate));
    startAt = m?.fromDate;
    endAt = m?.toDate;
    contenturlController = TextEditingController(text: m?.contenturl);
    fileurlController = TextEditingController(text: m?.fileurl);
    aboutTaskController = TextEditingController(text: m?.aboutTask);
    notesController = TextEditingController(text: m?.description);
    _voiceRecords = voiceRecordsFromUpdate(m);
    final hc = Get.find<HomeController>();
    hc.uploadedFilesPaths.assignAll(List.from(m?.files ?? []));
    final clients = hc.clients;
    useCustomClient = clientController.text.isNotEmpty &&
        !clients.any((c) => c.id == clientController.text);
    if (useCustomClient) {
      customClientController.text = clientController.text;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    executorController.dispose();
    clientController.dispose();
    customClientController.dispose();
    priorityController.dispose();
    categoryController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    contenturlController.dispose();
    fileurlController.dispose();
    aboutTaskController.dispose();
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
        startDateController.text =
            DateFormat('dd MM yyyy - hh:mm a').format(picked.toLocal());
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
        endDateController.text =
            DateFormat('dd MM yyyy - hh:mm a').format(picked.toLocal());
      });
    }
  }

  List<EmployeeModel> _programmingExecutors(HomeController controller) {
    final role = controller.currentEmployee.value?.role;
    final currentId = controller.currentEmployee.value?.id;
    final isManager = role == 'admin' || role == 'supervisor';
    return controller.employees
        .where(
          (a) =>
              a.hasDepartment(StorageKeys.departmentProgramming) ||
              (isManager && a.id == currentId),
        )
        .toList();
  }

  Future<void> _submit() async {
    final controller = Get.find<HomeController>();
    final resolvedClient = useCustomClient
        ? customClientController.text.trim()
        : clientController.text.trim();
    final payload = applyVoiceRecordsToUpdate(
      ProgrammingUpdateModel(
      id: widget.model?.id,
      title: titleController.text.trim(),
      description: notesController.text.trim(),
      assignedTo: executorController.text.trim(),
      clientName: resolvedClient,
      priority: priorityController.text.trim(),
      fromDate: startAt,
      toDate: endAt,
      contenturl: contenturlController.text.trim(),
      category: categoryController.text.trim(),
      fileurl: fileurlController.text.trim(),
      aboutTask: aboutTaskController.text.trim(),
      files: controller.uploadedFilesPaths.cast<String>().toList(),
      status:
          widget.model?.status ?? StorageKeys.programmingUpdateStatusPending,
    ),
      _voiceRecords,
    );
    final ok = widget.model == null
        ? await controller.addProgrammingUpdate(payload)
        : await controller.updateProgrammingUpdate(payload);
    if (!mounted) return;
    if (ok) {
      controller.uploadedFilesPaths.clear();
      Get.back();
      FunHelper.showSnackbar(
        'common.success'.tr,
        'programming.updates.saved'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.pageBackground,
      appBar: AppBar(
        title: Text('programming.updates.form_title'.tr),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: GetBuilder<HomeController>(
        builder: (controller) {
          final executors = _programmingExecutors(controller);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                InputText(
                  labelText: 'task_details.task_title'.tr,
                  hintText: 'tasks.form.write_title_hint'.tr,
                  controller: titleController,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                DynamicDropdown<EmployeeModel>(
                  items: executors
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text('${v.name} (${v.role})'),
                        ),
                      )
                      .toList(),
                  value: executorController.text.isEmpty
                      ? null
                      : executors.firstWhereOrNull(
                          (a) => a.id == executorController.text,
                        ),
                  label: 'tasks.form.select_executor'.tr,
                  borderRadius: 8,
                  height: 42,
                  onChanged: (value) {
                    if (value != null) {
                      executorController.text = value.id ?? '';
                    }
                  },
                ),
                const SizedBox(height: 12),
                DynamicDropdown<dynamic>(
                  items: [
                    ...controller.clients.map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(v.name ?? ''),
                      ),
                    ),
                    DropdownMenuItem(
                      value: _otherClient,
                      child: Text('tasks.other_client'.tr),
                    ),
                  ],
                  value: useCustomClient
                      ? _otherClient
                      : (clientController.text.isEmpty
                          ? null
                          : controller.clients.firstWhereOrNull(
                              (a) => a.id == clientController.text,
                            )),
                  label: 'chooseclient'.tr,
                  borderRadius: 8,
                  height: 42,
                  onChanged: (value) {
                    setState(() {
                      if (value == _otherClient) {
                        useCustomClient = true;
                        clientController.text = '';
                      } else if (value != null) {
                        useCustomClient = false;
                        clientController.text = value.id ?? '';
                      }
                    });
                  },
                ),
                if (useCustomClient) ...[
                  const SizedBox(height: 8),
                  InputText(
                    labelText: 'tasks.form.client_name_label'.tr,
                    hintText: 'tasks.form.client_name_hint'.tr,
                    controller: customClientController,
                    borderRadius: 8,
                  ),
                ],
                const SizedBox(height: 12),
                InputText(
                  labelText: 'task_details.content_link'.tr,
                  hintText: '',
                  controller: contenturlController,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                InputText(
                  labelText: 'task_details.files_link'.tr,
                  hintText: '',
                  controller: fileurlController,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                DynamicDropdown<String>(
                  items: StorageKeys.priority
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v.tr),
                        ),
                      )
                      .toList(),
                  value: priorityController.text.isEmpty
                      ? null
                      : priorityController.text,
                  label: 'priortity'.tr,
                  borderRadius: 8,
                  height: 42,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => priorityController.text = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                InputText(
                  labelText: 'task_details.category'.tr,
                  hintText: '',
                  controller: categoryController,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                InputText(
                  onTap: _pickStartDate,
                  labelText: 'startat'.tr,
                  hintText: 'common.select_date'.tr,
                  height: 48,
                  controller: startDateController,
                  readOnly: true,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                InputText(
                  onTap: _pickEndDate,
                  labelText: 'endat'.tr,
                  hintText: 'common.select_date'.tr,
                  height: 48,
                  controller: endDateController,
                  readOnly: true,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                InputText(
                  labelText: 'tasks.form.about_task_label'.tr,
                  hintText: 'tasks.form.about_task_hint'.tr,
                  controller: aboutTaskController,
                  height: 80,
                  expanded: true,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                InputText(
                  labelText: 'notes'.tr,
                  hintText: 'enternotes'.tr,
                  controller: notesController,
                  height: 80,
                  expanded: true,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final files = await controller.pickMultiFiles();
                    for (final file in files) {
                      controller.uploadFiles(
                        filePathOrBytes: file.bytes!,
                        fileName: file.name,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.appTheme.unselected,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.appTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'dragfile'.tr,
                          style: TextStyle(color: context.appTheme.secondaryText),
                        ),
                        Obx(
                          () => controller.isUploading.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => FormAttachmentThumbnailsGrid(
                    urls: controller.uploadedFilesPaths
                        .map((e) => e.toString())
                        .toList(),
                    onRemoveUrl: (u) {
                      controller.uploadedFilesPaths.removeWhere(
                        (e) => e.toString() == u,
                      );
                    },
                    onOpenUrl: (u) async => openUrlPreferInAppMedia(u),
                    spacing: 6,
                    tileExtent: 88,
                  ),
                ),
                const SizedBox(height: 12),
                TaskVoiceRecordField(
                  records: _voiceRecords,
                  onRecordsChanged: (v) =>
                      setState(() => _voiceRecords = v),
                ),
                const SizedBox(height: 24),
                Obx(
                  () => TaskFormDialogActions(
                    isLoading: controller.isLoading.value,
                    onSave: _submit,
                    onCancel: () => Get.back(),
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
