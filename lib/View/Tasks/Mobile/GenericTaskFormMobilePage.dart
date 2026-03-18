import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/ContentWriteModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/MonatageModel.dart';
import 'package:point/Models/PhotographyModel.dart';
import 'package:point/Models/ProgrammingModel.dart';
import 'package:point/Models/PromotionModel.dart';
import 'package:point/Models/PublishModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/t.dart';

/// Mobile full-screen form for add/edit task. Used for all task types except Design
/// (Design uses DesignTaskFormMobilePage). Web dialogs are not touched.
class GenericTaskFormMobilePage extends StatefulWidget {
  final TaskModel? model;
  /// When adding (model == null), pass the task type as string '0'-'6'.
  final String? typeForNew;

  const GenericTaskFormMobilePage({super.key, this.model, this.typeForNew});

  @override
  State<GenericTaskFormMobilePage> createState() => _GenericTaskFormMobilePageState();
}

class _GenericTaskFormMobilePageState extends State<GenericTaskFormMobilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController clientController;
  late final TextEditingController executorController;
  late final TextEditingController priorityController;
  late final TextEditingController startDateController;
  late final TextEditingController endDateController;
  late final TextEditingController notesController;

  // Promotion (0)
  late final TextEditingController campaignReasonController;
  late final TextEditingController marksController;
  late final TextEditingController durationPromoController;
  late final TextEditingController attachmentPromoController;
  late final TextEditingController ageRangesController;
  late final RxList<String> platformsPromo;
  late final RxList<String> countriesList;
  late final RxList<String> interestsList;
  late final RxList<String> cityList;
  late final RxList<String> specializationsList;

  // Photography (2)
  late final RxList<String> platformsPhoto;
  late final TextEditingController shootingLocationController;
  late final TextEditingController shootingTypeController;
  late final TextEditingController designCountPhotoController;
  late final TextEditingController durationPhotoController;

  // ContentWrite (3)
  late final RxList<String> platformsContent;
  late final TextEditingController contentTypeController;
  late final TextEditingController designCountContentController;
  late final TextEditingController dimensionsContentController;

  // Montage (4)
  late final RxList<String> platformsMontage;
  late final TextEditingController categoryMontageController;
  late final TextEditingController dimensionsMontageController;
  late final TextEditingController attachmentMontageController;
  late final TextEditingController durationMontageController;

  // Publish (5) & Programming (6)
  late final TextEditingController contentUrlController;
  late final TextEditingController fileUrlController;
  late final TextEditingController categoryController;
  late final RxList<String> platformsPublish;
  late final TextEditingController dimensionsPublishController;

  DateTime? startAt;
  DateTime? endAt;
  late String taskType;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    taskType = m?.type ?? widget.typeForNew ?? '0';
    titleController = TextEditingController(text: m?.title);
    clientController = TextEditingController(text: m?.clientName);
    executorController = TextEditingController(text: m?.assignedTo);
    priorityController = TextEditingController(text: m?.priority);
    startDateController = TextEditingController(text: FunHelper.formatdate(m?.fromDate));
    endDateController = TextEditingController(text: FunHelper.formatdate(m?.toDate));
    notesController = TextEditingController(text: m?.description);
    startAt = m?.fromDate;
    endAt = m?.toDate;

    // Promotion (0)
    final promo = m?.promotionModel;
    campaignReasonController = TextEditingController(text: promo?.target);
    marksController = TextEditingController(text: promo?.tags);
    durationPromoController = TextEditingController(text: promo?.duration);
    attachmentPromoController = TextEditingController(text: promo?.attachementurl);
    ageRangesController = TextEditingController(text: promo?.ageRanges);
    platformsPromo = (promo?.platforms?.cast<String>() ?? []).obs;
    countriesList = (promo?.countries ?? []).obs;
    interestsList = (promo?.interests ?? []).obs;
    cityList = (promo?.cities ?? []).obs;
    specializationsList = (promo?.specializations ?? []).obs;

    // Photography (2)
    final photo = m?.photoGrapghyModel;
    platformsPhoto = (photo?.platform.cast<String>() ?? []).obs;
    shootingLocationController = TextEditingController(text: photo?.shootinglocation);
    shootingTypeController = TextEditingController(text: photo?.shootingtype);
    designCountPhotoController = TextEditingController(text: photo?.designCount?.toString());
    durationPhotoController = TextEditingController(text: photo?.duration);

    // ContentWrite (3)
    final content = m?.contentWriteModel;
    platformsContent = (content?.platform.cast<String>() ?? []).obs;
    contentTypeController = TextEditingController(text: content?.contenttype);
    designCountContentController = TextEditingController(text: content?.designCount?.toString());
    dimensionsContentController = TextEditingController(text: content?.designsDimensions);

    // Montage (4)
    final montage = m?.monatageModel;
    platformsMontage = (montage?.platform.cast<String>() ?? []).obs;
    categoryMontageController = TextEditingController(text: montage?.category);
    dimensionsMontageController = TextEditingController(text: montage?.dimentioans);
    attachmentMontageController = TextEditingController(text: montage?.attachementurl);
    durationMontageController = TextEditingController(text: montage?.duration);

    // Publish (5) & Programming (6)
    final publish = m?.publishModel;
    final prog = m?.programmingModel;
    contentUrlController = TextEditingController(text: publish?.contenturl ?? prog?.contenturl);
    fileUrlController = TextEditingController(text: publish?.fileurl ?? prog?.fileurl);
    categoryController = TextEditingController(text: publish?.category ?? prog?.category);
    platformsPublish = (publish?.platform.cast<String>() ?? []).obs;
    dimensionsPublishController = TextEditingController(text: publish?.designsDimensions);

    final hc = Get.find<HomeController>();
    if (m == null) {
      hc.uploadedFilesPaths.clear();
    } else {
      hc.uploadedFilesPaths.assignAll(List.from(m.files));
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    clientController.dispose();
    executorController.dispose();
    priorityController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    notesController.dispose();
    campaignReasonController.dispose();
    marksController.dispose();
    durationPromoController.dispose();
    attachmentPromoController.dispose();
    ageRangesController.dispose();
    shootingLocationController.dispose();
    shootingTypeController.dispose();
    designCountPhotoController.dispose();
    durationPhotoController.dispose();
    contentTypeController.dispose();
    designCountContentController.dispose();
    dimensionsContentController.dispose();
    categoryMontageController.dispose();
    dimensionsMontageController.dispose();
    attachmentMontageController.dispose();
    durationMontageController.dispose();
    contentUrlController.dispose();
    fileUrlController.dispose();
    categoryController.dispose();
    dimensionsPublishController.dispose();
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

  String _departmentForType(String type) {
    final i = int.tryParse(type) ?? 0;
    return 'cat${i + 1}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (startAt == null || endAt == null) {
      Get.snackbar('تنبيه', 'يرجى اختيار تاريخ البداية والنهاية');
      return;
    }
    final controller = Get.find<HomeController>();
    final model = widget.model;
    final safeEmployees = (controller.employees as List<EmployeeModel>?) ?? <EmployeeModel>[];
    final execImage = safeEmployees.firstWhereOrNull((a) => a.id == executorController.text)?.image ?? '';

    if (model == null) {
      final newTask = _buildNewTask(execImage, controller);
      if (newTask == null) return;
      await controller.addTask(newTask);
      if (!mounted) return;
      Get.back();
      controller.uploadedFilesPaths.clear();
    } else {
      final updatedFiles = model.files + controller.uploadedFilesPaths.cast<String>().toList();
      final updatedNotes = model.notes +
          (notesController.text.isEmpty
              ? []
              : [
                  NoteModel(
                    note: notesController.text,
                    byWho: controller.currentemployee.value?.name ?? '',
                    timestamp: DateTime.now(),
                  ),
                ]);
      TaskModel updated;
      switch (taskType) {
        case '0':
          updated = model.copyWith(
            title: titleController.text,
            description: notesController.text,
            priority: priorityController.text,
            fromDate: startAt!,
            toDate: endAt!,
            assignedTo: executorController.text,
            clientName: clientController.text,
            assignedImageUrl: execImage,
            status: StorageKeys.status_edit_requested,
            notes: updatedNotes,
            files: updatedFiles,
            promotionModel: PromotionModel(
              name: titleController.text,
              target: campaignReasonController.text,
              campaignName: titleController.text,
              type: '0',
              priority: priorityController.text,
              status: StorageKeys.status_edit_requested,
              duration: durationPromoController.text,
              tags: marksController.text,
              platforms: platformsPromo.toList(),
              countries: countriesList.toList(),
              interests: interestsList.toList(),
              cities: cityList.toList(),
              ageRanges: ageRangesController.text,
              specializations: specializationsList.toList(),
              attachementurl: attachmentPromoController.text,
            ),
          );
          break;
        case '2':
          updated = model.copyWith(
            title: titleController.text,
            description: notesController.text,
            priority: priorityController.text,
            fromDate: startAt!,
            toDate: endAt!,
            assignedTo: executorController.text,
            clientName: clientController.text,
            assignedImageUrl: execImage,
            status: StorageKeys.status_edit_requested,
            notes: updatedNotes,
            files: updatedFiles,
            photoGrapghyModel: PhotographyModel(
              shootingtype: shootingTypeController.text,
              platform: platformsPhoto.toList(),
              shootinglocation: shootingLocationController.text,
              designCount: designCountPhotoController.text,
              duration: durationPhotoController.text,
            ),
          );
          break;
        case '3':
          updated = model.copyWith(
            title: titleController.text,
            description: notesController.text,
            priority: priorityController.text,
            fromDate: startAt!,
            toDate: endAt!,
            assignedTo: executorController.text,
            clientName: clientController.text,
            assignedImageUrl: execImage,
            status: StorageKeys.status_edit_requested,
            notes: updatedNotes,
            files: updatedFiles,
            contentWriteModel: ContentWriteModel(
              contenttype: contentTypeController.text,
              platform: platformsContent.toList(),
              designCount: designCountContentController.text,
              designsDimensions: dimensionsContentController.text,
            ),
          );
          break;
        case '4':
          updated = model.copyWith(
            title: titleController.text,
            description: notesController.text,
            priority: priorityController.text,
            fromDate: startAt!,
            toDate: endAt!,
            assignedTo: executorController.text,
            clientName: clientController.text,
            assignedImageUrl: execImage,
            status: StorageKeys.status_edit_requested,
            notes: updatedNotes,
            files: updatedFiles,
            monatageModel: MonatageModel(
              category: categoryMontageController.text,
              platform: platformsMontage.toList(),
              dimentioans: dimensionsMontageController.text,
              attachementurl: attachmentMontageController.text,
              duration: durationMontageController.text,
            ),
          );
          break;
        case '5':
          updated = model.copyWith(
            title: titleController.text,
            description: notesController.text,
            priority: priorityController.text,
            fromDate: startAt!,
            toDate: endAt!,
            assignedTo: executorController.text,
            clientName: clientController.text,
            assignedImageUrl: execImage,
            status: StorageKeys.status_edit_requested,
            notes: updatedNotes,
            files: updatedFiles,
            publishModel: PublishModel(
              contenturl: contentUrlController.text,
              platform: platformsPublish.toList(),
              category: categoryController.text,
              fileurl: fileUrlController.text,
              designsDimensions: dimensionsPublishController.text,
            ),
          );
          break;
        case '6':
          updated = model.copyWith(
            title: titleController.text,
            description: notesController.text,
            priority: priorityController.text,
            fromDate: startAt!,
            toDate: endAt!,
            assignedTo: executorController.text,
            clientName: clientController.text,
            assignedImageUrl: execImage,
            status: StorageKeys.status_edit_requested,
            notes: updatedNotes,
            files: updatedFiles,
            programmingModel: ProgrammingModel(
              contenturl: contentUrlController.text,
              category: categoryController.text,
              fileurl: fileUrlController.text,
              designsDimensions: '',
            ),
          );
          break;
        default:
          updated = model.copyWith(
            title: titleController.text,
            description: notesController.text,
            priority: priorityController.text,
            fromDate: startAt!,
            toDate: endAt!,
            assignedTo: executorController.text,
            clientName: clientController.text,
            assignedImageUrl: execImage,
            status: StorageKeys.status_edit_requested,
            notes: updatedNotes,
            files: updatedFiles,
          );
      }
      await controller.updateTask(updated);
      if (!mounted) return;
      Get.back();
      controller.uploadedFilesPaths.clear();
    }
  }

  TaskModel? _buildNewTask(String assignedImageUrl, HomeController controller) {
    final now = DateTime.now();
    final files = controller.uploadedFilesPaths.cast<String>().toList();
    final notesList = notesController.text.isEmpty ? <NoteModel>[] : <NoteModel>[
      NoteModel(note: notesController.text, byWho: controller.currentemployee.value?.name ?? '', timestamp: now),
    ];
    switch (taskType) {
      case '0':
        return TaskModel(
          title: titleController.text,
          description: notesController.text,
          status: StorageKeys.status_not_start_yet,
          priority: priorityController.text,
          fromDate: startAt!,
          toDate: endAt!,
          assignedTo: executorController.text,
          clientName: clientController.text,
          assignedImageUrl: assignedImageUrl,
          actionText: '',
          files: files,
          notes: notesList,
          type: '0',
          promotionModel: PromotionModel(
            name: titleController.text,
            target: campaignReasonController.text,
            campaignName: titleController.text,
            type: '0',
            priority: priorityController.text,
            status: StorageKeys.status_not_start_yet,
            duration: durationPromoController.text,
            tags: marksController.text,
            platforms: platformsPromo.toList(),
            countries: countriesList.toList(),
            interests: interestsList.toList(),
            cities: cityList.toList(),
            ageRanges: ageRangesController.text,
            specializations: specializationsList.toList(),
            attachementurl: attachmentPromoController.text,
          ),
        );
      case '2':
        return TaskModel(
          title: titleController.text,
          description: notesController.text,
          status: StorageKeys.status_not_start_yet,
          priority: priorityController.text,
          fromDate: startAt!,
          toDate: endAt!,
          assignedTo: executorController.text,
          clientName: clientController.text,
          assignedImageUrl: assignedImageUrl,
          actionText: '',
          files: files,
          notes: notesList,
          type: '2',
          photoGrapghyModel: PhotographyModel(
            shootingtype: shootingTypeController.text,
            platform: platformsPhoto.toList(),
            shootinglocation: shootingLocationController.text,
            designCount: designCountPhotoController.text,
            duration: durationPhotoController.text,
          ),
        );
      case '3':
        return TaskModel(
          title: titleController.text,
          description: notesController.text,
          status: StorageKeys.status_not_start_yet,
          priority: priorityController.text,
          fromDate: startAt!,
          toDate: endAt!,
          assignedTo: executorController.text,
          clientName: clientController.text,
          assignedImageUrl: assignedImageUrl,
          actionText: '',
          files: files,
          notes: notesList,
          type: '3',
          contentWriteModel: ContentWriteModel(
            contenttype: contentTypeController.text,
            platform: platformsContent.toList(),
            designCount: designCountContentController.text,
            designsDimensions: dimensionsContentController.text,
          ),
        );
      case '4':
        return TaskModel(
          title: titleController.text,
          description: notesController.text,
          status: StorageKeys.status_not_start_yet,
          priority: priorityController.text,
          fromDate: startAt!,
          toDate: endAt!,
          assignedTo: executorController.text,
          clientName: clientController.text,
          assignedImageUrl: assignedImageUrl,
          actionText: '',
          files: files,
          notes: notesList,
          type: '4',
          monatageModel: MonatageModel(
            category: categoryMontageController.text,
            platform: platformsMontage.toList(),
            dimentioans: dimensionsMontageController.text,
            attachementurl: attachmentMontageController.text,
            duration: durationMontageController.text,
          ),
        );
      case '5':
        return TaskModel(
          title: titleController.text,
          description: notesController.text,
          status: StorageKeys.status_not_start_yet,
          priority: priorityController.text,
          fromDate: startAt!,
          toDate: endAt!,
          assignedTo: executorController.text,
          clientName: clientController.text,
          assignedImageUrl: assignedImageUrl,
          actionText: '',
          files: files,
          notes: notesList,
          type: '5',
          publishModel: PublishModel(
            contenturl: contentUrlController.text,
            platform: platformsPublish.toList(),
            category: categoryController.text,
            fileurl: fileUrlController.text,
            designsDimensions: dimensionsPublishController.text,
          ),
        );
      case '6':
        return TaskModel(
          title: titleController.text,
          description: notesController.text,
          status: StorageKeys.status_not_start_yet,
          priority: priorityController.text,
          fromDate: startAt!,
          toDate: endAt!,
          assignedTo: executorController.text,
          clientName: clientController.text,
          assignedImageUrl: assignedImageUrl,
          actionText: '',
          files: files,
          notes: notesList,
          type: '6',
          programmingModel: ProgrammingModel(
            contenturl: contentUrlController.text,
            category: categoryController.text,
            fileurl: fileUrlController.text,
            designsDimensions: '',
          ),
        );
      default:
        Get.snackbar('تنبيه', 'نوع المهمة غير مدعوم');
        return null;
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
          final department = _departmentForType(taskType);
          final filteredEmployees = safeEmployees.where((a) => a.department == department).toList();

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionLabel('بيانات المهمة'),
                  InputText(
                    labelText: 'عنوان المهمة'.tr,
                    hintText: 'اكتب عنوان المهمة'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: titleController,
                    validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  DynamicDropdown<dynamic>(
                    items: safeClients
                        .map((v) => DropdownMenuItem(value: v, child: Text('${v.name}')))
                        .toList(),
                    value: clientController.text.isEmpty ? null : safeClients.firstWhereOrNull((a) => a.id == clientController.text),
                    label: 'العميل'.tr,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                    height: 48,
                    fillColor: Colors.white,
                    onChanged: (value) {
                      if (value != null) clientController.text = (value as dynamic).id ?? '';
                    },
                    validator: (v) => v == null ? ' ' : null,
                  ),
                  const SizedBox(height: 16),
                  DynamicDropdown<EmployeeModel>(
                    items: filteredEmployees
                        .map((v) => DropdownMenuItem(value: v, child: Text('${v.name} (${v.role})')))
                        .toList(),
                    value: executorController.text.isEmpty ? null : filteredEmployees.firstWhereOrNull((a) => a.id == executorController.text),
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
                    items: StorageKeys.priority
                        .map((v) => DropdownMenuItem(value: v, child: Text(v.tr)))
                        .toList(),
                    value: priorityController.text.isEmpty ? null : priorityController.text,
                    label: 'الأولوية'.tr,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                    height: 48,
                    fillColor: Colors.white,
                    onChanged: (value) {
                      if (value != null) priorityController.text = value;
                    },
                    validator: (v) => v == null ? ' ' : null,
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('التواريخ'),
                  InkWell(
                    onTap: _pickStartDate,
                    child: InputText(
                      labelText: 'تاريخ البداية'.tr,
                      hintText: 'اختر التاريخ'.tr,
                      height: 48,
                      fillColor: Colors.white,
                      controller: startDateController,
                      readOnly: true,
                      validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickEndDate,
                    child: InputText(
                      labelText: 'تاريخ النهاية'.tr,
                      hintText: 'اختر التاريخ'.tr,
                      height: 48,
                      fillColor: Colors.white,
                      controller: endDateController,
                      readOnly: true,
                      validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                    ),
                  ),
                  ..._buildTypeSpecificFields(),
                  const SizedBox(height: 16),
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
                  InputText(
                    labelText: 'ملاحظات'.tr,
                    hintText: 'ملاحظات (اختياري)'.tr,
                    height: 80,
                    fillColor: Colors.white,
                    controller: notesController,
                    expanded: true,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('الملاحظات والمرفقات'),
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

  List<Widget> _buildTypeSpecificFields() {
    const pad = SizedBox(height: 16);
    switch (taskType) {
      case '0': // Promotion
        return [
          const SizedBox(height: 24),
          _sectionLabel('تفاصيل الترويج'),
          DynamicDropdown<String>(
            items: StorageKeys.campaignTarget.map((v) => DropdownMenuItem(value: v, child: Text(v.tr))).toList(),
            value: campaignReasonController.text.isEmpty ? null : campaignReasonController.text,
            label: 'campainreason'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) { if (v != null) campaignReasonController.text = v; },
            validator: (v) => v == null ? ' ' : null,
          ),
          pad,
          Obx(() => DynamicDropdownMultiSelect<String>(
            items: StorageKeys.platformList.map((v) => v.tr).toList(),
            selectedValues: platformsPromo.toList(),
            itemLabel: (v) => v,
            label: 'platform'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) => platformsPromo.assignAll(v),
            validator: (v) => (v == null || v.isEmpty) ? ' ' : null,
          )),
          pad,
          InputText(labelText: 'marks'.tr, hintText: 'addmark'.tr, height: 48, fillColor: Colors.white, controller: marksController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          InputText(labelText: 'المدة'.tr, hintText: 'مدة الحملة'.tr, height: 48, fillColor: Colors.white, controller: durationPromoController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          Obx(() => DynamicDropdownMultiSelect<String>(
            items: StorageKeys.countryCitiesMap.keys.toList(),
            selectedValues: countriesList.toList(),
            itemLabel: (v) => v,
            label: 'الدول'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) {
              countriesList.assignAll(v);
              final allowed = StorageKeys.getCitiesForCountries(v);
              cityList.assignAll(cityList.where((c) => allowed.contains(c)).toList());
            },
          )),
          pad,
          Obx(() => DynamicDropdownMultiSelect<String>(
            items: StorageKeys.interestsList,
            selectedValues: interestsList.toList(),
            itemLabel: (v) => v,
            label: 'الاهتمامات'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) => interestsList.assignAll(v),
          )),
          pad,
          Obx(() => DynamicDropdownMultiSelect<String>(
            items: StorageKeys.getCitiesForCountries(countriesList.toList()),
            selectedValues: cityList.toList(),
            itemLabel: (v) => v,
            label: 'المدن'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) => cityList.assignAll(v),
          )),
          pad,
          InputText(labelText: 'الفئات العمرية'.tr, hintText: 'الفئات العمرية'.tr, height: 48, fillColor: Colors.white, controller: ageRangesController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          Obx(() => DynamicDropdownMultiSelect<String>(
            items: StorageKeys.specialist,
            selectedValues: specializationsList.toList(),
            itemLabel: (v) => v,
            label: 'التخصصات'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) => specializationsList.assignAll(v),
          )),
          pad,
          InputText(labelText: 'رابط الملفات'.tr, hintText: 'اكتب رابط الملفات'.tr, height: 48, fillColor: Colors.white, controller: attachmentPromoController, borderRadius: 8, borderColor: Colors.grey.shade300),
        ];
      case '2': // Photography
        return [
          const SizedBox(height: 24),
          _sectionLabel('تفاصيل التصوير'),
          Obx(() => DynamicDropdownMultiSelect<String>(
            items: StorageKeys.platformList.map((v) => v.tr).toList(),
            selectedValues: platformsPhoto.toList(),
            itemLabel: (v) => v,
            label: 'platform'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) => platformsPhoto.assignAll(v),
          )),
          pad,
          DynamicDropdown<String>(
            items: StorageKeys.shootingtype.map((v) => DropdownMenuItem(value: v, child: Text(v.tr))).toList(),
            value: shootingTypeController.text.isEmpty ? null : shootingTypeController.text,
            label: 'نوع التصوير'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) { if (v != null) shootingTypeController.text = v; },
          ),
          pad,
          DynamicDropdown<String>(
            items: StorageKeys.shootingLocations.map((v) => DropdownMenuItem(value: v, child: Text(v.tr))).toList(),
            value: shootingLocationController.text.isEmpty ? null : shootingLocationController.text,
            label: 'موقع التصوير'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) { if (v != null) shootingLocationController.text = v; },
          ),
          pad,
          InputText(labelText: 'عدد التصاميم'.tr, hintText: 'عدد التصاميم'.tr, height: 48, fillColor: Colors.white, controller: designCountPhotoController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          InputText(labelText: 'المدة'.tr, hintText: 'المدة'.tr, height: 48, fillColor: Colors.white, controller: durationPhotoController, borderRadius: 8, borderColor: Colors.grey.shade300),
        ];
      case '3': // ContentWrite
        return [
          const SizedBox(height: 24),
          _sectionLabel('تفاصيل كتابة المحتوى'),
          Obx(() => DynamicDropdownMultiSelect<String>(
            items: StorageKeys.platformList.map((v) => v.tr).toList(),
            selectedValues: platformsContent.toList(),
            itemLabel: (v) => v,
            label: 'platform'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) => platformsContent.assignAll(v),
          )),
          pad,
          DynamicDropdown<String>(
            items: StorageKeys.contentTypes.map((v) => DropdownMenuItem(value: v, child: Text(v.tr))).toList(),
            value: contentTypeController.text.isEmpty ? null : contentTypeController.text,
            label: 'نوع المحتوى'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) { if (v != null) contentTypeController.text = v; },
          ),
          pad,
          InputText(labelText: 'عدد التصاميم'.tr, hintText: 'عدد التصاميم'.tr, height: 48, fillColor: Colors.white, controller: designCountContentController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          InputText(labelText: 'القياسات'.tr, hintText: 'القياسات'.tr, height: 48, fillColor: Colors.white, controller: dimensionsContentController, borderRadius: 8, borderColor: Colors.grey.shade300),
        ];
      case '4': // Montage
        return [
          const SizedBox(height: 24),
          _sectionLabel('تفاصيل المونتاج'),
          Obx(() => DynamicDropdownMultiSelect<String>(
            items: StorageKeys.platformList.map((v) => v.tr).toList(),
            selectedValues: platformsMontage.toList(),
            itemLabel: (v) => v,
            label: 'platform'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) => platformsMontage.assignAll(v),
          )),
          pad,
          DynamicDropdown<String>(
            items: StorageKeys.monatgecategory.map((v) => DropdownMenuItem(value: v, child: Text(v.tr))).toList(),
            value: categoryMontageController.text.isEmpty ? null : categoryMontageController.text,
            label: 'التصنيف'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) { if (v != null) categoryMontageController.text = v; },
          ),
          pad,
          InputText(labelText: 'القياسات'.tr, hintText: 'القياسات'.tr, height: 48, fillColor: Colors.white, controller: dimensionsMontageController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          InputText(labelText: 'رابط المرفقات'.tr, hintText: 'رابط المرفقات'.tr, height: 48, fillColor: Colors.white, controller: attachmentMontageController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          InputText(labelText: 'المدة'.tr, hintText: 'المدة'.tr, height: 48, fillColor: Colors.white, controller: durationMontageController, borderRadius: 8, borderColor: Colors.grey.shade300),
        ];
      case '5': // Publish
        return [
          const SizedBox(height: 24),
          _sectionLabel('تفاصيل النشر'),
          InputText(labelText: 'رابط المحتوى'.tr, hintText: 'رابط المحتوى'.tr, height: 48, fillColor: Colors.white, controller: contentUrlController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          InputText(labelText: 'رابط الملفات'.tr, hintText: 'رابط الملفات'.tr, height: 48, fillColor: Colors.white, controller: fileUrlController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          InputText(labelText: 'التصنيف'.tr, hintText: 'التصنيف'.tr, height: 48, fillColor: Colors.white, controller: categoryController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          Obx(() => DynamicDropdownMultiSelect<String>(
            items: StorageKeys.platformList.map((v) => v.tr).toList(),
            selectedValues: platformsPublish.toList(),
            itemLabel: (v) => v,
            label: 'platform'.tr,
            borderRadius: 8,
            borderColor: Colors.grey.shade300,
            height: 48,
            fillColor: Colors.white,
            onChanged: (v) => platformsPublish.assignAll(v),
          )),
          pad,
          InputText(labelText: 'القياسات'.tr, hintText: 'القياسات'.tr, height: 48, fillColor: Colors.white, controller: dimensionsPublishController, borderRadius: 8, borderColor: Colors.grey.shade300),
        ];
      case '6': // Programming
        return [
          const SizedBox(height: 24),
          _sectionLabel('تفاصيل البرمجة'),
          InputText(labelText: 'رابط المحتوى'.tr, hintText: 'رابط المحتوى'.tr, height: 48, fillColor: Colors.white, controller: contentUrlController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          InputText(labelText: 'رابط الملفات'.tr, hintText: 'رابط الملفات'.tr, height: 48, fillColor: Colors.white, controller: fileUrlController, borderRadius: 8, borderColor: Colors.grey.shade300),
          pad,
          InputText(labelText: 'التصنيف'.tr, hintText: 'التصنيف'.tr, height: 48, fillColor: Colors.white, controller: categoryController, validator: (v) => (v == null || v.isEmpty) ? ' ' : null, borderRadius: 8, borderColor: Colors.grey.shade300),
        ];
      default:
        return [];
    }
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
