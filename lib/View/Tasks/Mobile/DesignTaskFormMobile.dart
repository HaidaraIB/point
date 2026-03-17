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
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/t.dart';

/// Mobile-only full-screen add/edit design task form.
/// Opened when designDialog() is called on mobile; desktop keeps the dialog.
class DesignTaskFormMobilePage extends StatefulWidget {
  final TaskModel? model;

  const DesignTaskFormMobilePage({super.key, this.model});

  @override
  State<DesignTaskFormMobilePage> createState() => _DesignTaskFormMobilePageState();
}

class _DesignTaskFormMobilePageState extends State<DesignTaskFormMobilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController executorController;
  late final TextEditingController taskTypeController;
  late final RxList<dynamic> platforms;
  late final TextEditingController clientController;
  late final TextEditingController designTypeController;
  late final TextEditingController priorityController;
  late final TextEditingController designsCountController;
  late final TextEditingController dimensionsController;
  late final TextEditingController startDateController;
  late final TextEditingController endDateController;
  late final TextEditingController notesController;

  DateTime? startAt;
  DateTime? endAt;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    titleController = TextEditingController(text: m?.title);
    executorController = TextEditingController(text: m?.assignedTo);
    taskTypeController = TextEditingController(text: m?.designDetails?.taskType);
    platforms = (m?.designDetails?.platform ?? []).obs;
    clientController = TextEditingController(text: m?.clientName);
    designTypeController = TextEditingController(text: m?.designDetails?.designType);
    priorityController = TextEditingController(text: m?.priority);
    designsCountController = TextEditingController(text: m?.designDetails?.designCount);
    dimensionsController = TextEditingController(text: m?.designDetails?.designsDimensions);
    startDateController = TextEditingController(text: FunHelper.formatdate(m?.fromDate));
    endDateController = TextEditingController(text: FunHelper.formatdate(m?.toDate));
    notesController = TextEditingController();
    startAt = m?.fromDate;
    endAt = m?.toDate;
  }

  @override
  void dispose() {
    titleController.dispose();
    executorController.dispose();
    taskTypeController.dispose();
    clientController.dispose();
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
    final picked = await customDatePicker(context);
    if (picked != null && mounted) {
      setState(() {
        startAt = picked;
        startDateController.text = DateFormat('dd MM yyyy - hh:mm a').format(picked.toLocal());
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await customDatePicker(context);
    if (picked != null && mounted) {
      setState(() {
        endAt = picked;
        endDateController.text = DateFormat('dd MM yyyy - hh:mm a').format(picked.toLocal());
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (startAt == null || endAt == null) {
      Get.snackbar('تنبيه', 'يرجى اختيار تاريخ البداية والنهاية');
      return;
    }
    final controller = Get.find<HomeController>();
    final model = widget.model;
    final safeEmployees = (controller.employees as List<EmployeeModel>?) ?? <EmployeeModel>[];

    if (model == null) {
      await controller.addTask(
        TaskModel(
          title: titleController.text,
          description: notesController.text,
          status: StorageKeys.status_not_start_yet,
          priority: priorityController.text,
          fromDate: startAt!,
          toDate: endAt!,
          assignedTo: executorController.text,
          clientName: clientController.text,
          assignedImageUrl: safeEmployees.firstWhereOrNull((a) => a.id == executorController.text)?.image ?? '',
          notes: notesController.text.isEmpty
              ? []
              : [
                  NoteModel(
                    note: notesController.text,
                    byWho: controller.currentemployee.value?.name ?? '',
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
      );
      if (!mounted) return;
      Get.back();
      controller.uploadedFilesPaths.clear();
    } else {
      await controller.updateTask(
        TaskModel(
          id: model.id,
          title: titleController.text,
          description: notesController.text,
          status: StorageKeys.status_edit_requested,
          priority: priorityController.text,
          fromDate: startAt!,
          toDate: endAt!,
          assignedTo: executorController.text,
          clientName: clientController.text,
          assignedImageUrl: safeEmployees.firstWhereOrNull((a) => a.id == executorController.text)?.image ?? '',
          actionText: '',
          files: model.files + controller.uploadedFilesPaths.cast<String>().toList(),
          notes: model.notes +
              (notesController.text.isEmpty
                  ? []
                  : [
                      NoteModel(
                        note: notesController.text,
                        byWho: controller.currentemployee.value?.name ?? '',
                        timestamp: DateTime.now(),
                      ),
                    ]),
          type: '1',
          designDetails: DesignTaskModel(
            designsDimensions: dimensionsController.text,
            taskType: taskTypeController.text,
            platform: platforms,
            designType: designTypeController.text,
            designCount: designsCountController.text,
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.model == null ? 'اضافة مهمة'.tr : 'تعديل المهمة'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionLabel('بيانات المهمة'),
                  InputText(
                    labelText: 'عنوان التصميم'.tr,
                    hintText: 'اكتب اسم التصميم'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: titleController,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  DynamicDropdown<EmployeeModel>(
                    items: safeEmployees.where((a) => a.department == 'cat2').map((v) => DropdownMenuItem(value: v, child: Text('${v.name} (${v.role})'))).toList(),
                    value: executorController.text.isEmpty ? null : safeEmployees.firstWhereOrNull((a) => a.id == executorController.text),
                    label: 'المنفذ'.tr,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                    height: 48,
                    fillColor: Colors.white,
                    onChanged: (value) {
                      if (value != null) executorController.text = value.id ?? '';
                    },
                    validator: (v) => v == null ? ' ' : null,
                  ),
                  const SizedBox(height: 16),
                  DynamicDropdown<String>(
                    items: StorageKeys.tasktype.map((v) => DropdownMenuItem(value: v, child: Text(v.tr))).toList(),
                    value: taskTypeController.text.isEmpty ? null : taskTypeController.text,
                    label: 'نوع المهمه'.tr,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                    height: 48,
                    fillColor: Colors.white,
                    onChanged: (value) {
                      if (value != null) taskTypeController.text = value;
                    },
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('العميل والمنصة'),
                  DynamicDropdown<ClientModel>(
                    items: safeClients.map((v) => DropdownMenuItem(value: v, child: Text('${v.name}'))).toList(),
                    value: clientController.text.isEmpty ? null : safeClients.firstWhereOrNull((a) => a.id == clientController.text),
                    label: 'chooseclient'.tr,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                    height: 48,
                    fillColor: Colors.white,
                    onChanged: (value) {
                      if (value != null) clientController.text = value.id ?? '';
                    },
                    validator: (v) => v == null ? ' ' : null,
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => DynamicDropdownMultiSelect<String>(
                      items: StorageKeys.platformList.map((v) => v.tr).toList(),
                      selectedValues: platforms.cast<String>().toList(),
                      itemLabel: (v) => v,
                      label: 'platform'.tr,
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                      height: 48,
                      fillColor: Colors.white,
                      validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                      onChanged: (value) => platforms.assignAll(value),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('التفاصيل'),
                  DynamicDropdown<String>(
                    items: StorageKeys.designTypes.map((v) => DropdownMenuItem(value: v, child: Text(v.tr))).toList(),
                    value: designTypeController.text.isEmpty ? null : designTypeController.text,
                    label: 'نوع التصميم'.tr,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                    height: 48,
                    fillColor: Colors.white,
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
                    borderColor: Colors.grey.shade300,
                    height: 48,
                    fillColor: Colors.white,
                    onChanged: (value) {
                      if (value != null) priorityController.text = value.toString();
                    },
                    validator: (v) => v == null ? ' ' : null,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: 'عدد التصاميم'.tr,
                    hintText: 'عدد التصاميم'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: designsCountController,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: 'القياسات'.tr,
                    hintText: 'اكتب القياسات'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: dimensionsController,
                    validator: (val) => (val == null || val.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('التواريخ'),
                  InputText(
                    ontap: _pickStartDate,
                    labelText: 'startat'.tr,
                    hintText: '1/10/2025'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: startDateController,
                    readonly: true,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    suffixIcon: Icon(CupertinoIcons.calendar, color: Colors.grey.shade600),
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    ontap: _pickEndDate,
                    labelText: 'endat'.tr,
                    hintText: '1/10/2026'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: endDateController,
                    readonly: true,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    suffixIcon: Icon(CupertinoIcons.calendar, color: Colors.grey.shade600),
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 24),
                  if (widget.model != null && widget.model!.notes.isNotEmpty) ...[
                    _sectionLabel('سجل الملاحظات'.tr),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                              Text(
                                note.note,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryfontColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                note.byWho,
                                style: const TextStyle(fontSize: 12, color: Colors.green),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _sectionLabel('الملاحظات والمرفقات'),
                  InputText(
                    labelText: 'notes'.tr,
                    hintText: 'enternotes'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: notesController,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
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
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('uploadfile'.tr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                          Obx(() => controller.isUploading.value ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.upload_file, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                  Obx(
                    () => controller.uploadedFilesPaths.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              ...controller.uploadedFilesPaths.map(
                                (filePath) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () => controller.uploadedFilesPaths.remove(filePath),
                                        child: const Icon(Icons.cancel, color: Colors.red, size: 22),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          FunHelper.getFileNameFromUrl(filePath),
                                          style: const TextStyle(fontSize: 13, color: Colors.blue, decoration: TextDecoration.underline),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                            : Text('حفظ'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                    child: Text('إلغاء'.tr),
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
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}
