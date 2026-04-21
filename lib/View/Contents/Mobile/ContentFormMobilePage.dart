import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/ContentPermissions.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Clients/ClientsTable.dart' show customDatePicker;
import 'package:point/View/Contents/Shared/content_library_attachment_picker.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/t.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';

/// Mobile-only full-screen form for add/edit content. Desktop keeps using [showAddContentDialog].
class ContentFormMobilePage extends StatefulWidget {
  final String clientId;
  final ContentModel? model;

  const ContentFormMobilePage({
    super.key,
    required this.clientId,
    this.model,
  });

  @override
  State<ContentFormMobilePage> createState() => _ContentFormMobilePageState();
}

class _ContentFormMobilePageState extends State<ContentFormMobilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController publishDateController;
  late final TextEditingController executorController;
  late final TextEditingController contentTypeController;
  late final TextEditingController notesController;
  late final TextEditingController captionController;
  late final TextEditingController fileController;
  late final TextEditingController postAttachmentController;
  late final TextEditingController storyAttachmentController;
  late final RxList<dynamic> platforms;
  DateTime? publishDate;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    titleController = TextEditingController(text: m?.title);
    publishDateController = TextEditingController(
      text: FunHelper.formatdate(m?.publishDate),
    );
    publishDate = m?.publishDate;
    executorController = TextEditingController(text: m?.executor);
    contentTypeController = TextEditingController(text: m?.contentType);
    notesController = TextEditingController(text: m?.clientNotes);
    captionController = TextEditingController(text: m?.caption);
    fileController = TextEditingController();
    postAttachmentController = TextEditingController();
    storyAttachmentController = TextEditingController();
    platforms = (m?.platform ?? []).obs;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hc = Get.find<HomeController>();
      if (!ContentPermissions.canAddOrEditContent(hc.currentEmployee.value)) {
        FunHelper.showSnackbar(
          'error'.tr,
          'errors.forbidden'.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Get.back();
      }
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    publishDateController.dispose();
    executorController.dispose();
    contentTypeController.dispose();
    notesController.dispose();
    captionController.dispose();
    fileController.dispose();
    postAttachmentController.dispose();
    storyAttachmentController.dispose();
    super.dispose();
  }

  Future<void> _openUploadedFile(String rawUrl) async {
    await openUrlPreferInAppMedia(rawUrl);
  }

  List<String> _splitAttachmentInput(String raw) {
    return raw
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _appendAttachmentLinks(
    TextEditingController controller,
    List<String> urls,
  ) {
    if (urls.isEmpty) return;
    final current = _splitAttachmentInput(controller.text);
    final merged = {...current, ...urls}.toList();
    controller.text = merged.join('\n');
  }

  Future<void> _pickAttachmentFieldFromLocal(
    TextEditingController targetController,
  ) async {
    final hc = Get.find<HomeController>();
    if (hc.isUploading.value) return;
    final files = await hc.pickMultiFiles();
    final added = <String>[];
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final url = await hc.uploadFiles(filePathOrBytes: bytes, fileName: file.name);
      if (url != null && url.trim().isNotEmpty) {
        added.add(url.trim());
      }
    }
    if (!mounted || added.isEmpty) return;
    setState(() => _appendAttachmentLinks(targetController, added));
  }

  Future<void> _pickAttachmentFieldWithSource(
    TextEditingController targetController,
  ) async {
    final source = await showContentAttachmentSourceDialog(context);
    if (source == null || !mounted) return;
    if (source == ContentAttachmentSource.local) {
      await _pickAttachmentFieldFromLocal(targetController);
      return;
    }
    final selected = await showLibraryAttachmentPickerDialog(context);
    if (!mounted || selected.isEmpty) return;
    setState(() => _appendAttachmentLinks(targetController, selected));
  }

  Future<void> _pickMainAttachmentFromLocal() async {
    final hc = Get.find<HomeController>();
    if (hc.isUploading.value) return;
    final files = await hc.pickMultiFiles();
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      await hc.uploadFiles(filePathOrBytes: bytes, fileName: file.name);
    }
  }

  Future<void> _pickMainAttachmentWithSource() async {
    final hc = Get.find<HomeController>();
    final source = await showContentAttachmentSourceDialog(context);
    if (source == null || !mounted) return;
    if (source == ContentAttachmentSource.local) {
      await _pickMainAttachmentFromLocal();
      return;
    }
    final selected = await showLibraryAttachmentPickerDialog(context);
    if (!mounted || selected.isEmpty) return;
    final merged = <String>{
      ...hc.uploadedFilesPaths.map((e) => e.toString().trim()),
      ...selected.map((e) => e.trim()),
    }.where((e) => e.isNotEmpty).toList();
    hc.uploadedFilesPaths.assignAll(merged);
  }

  Future<void> _pickPublishDate() async {
    final picked = await customDatePicker(context);
    if (picked != null && mounted) {
      setState(() {
        publishDate = picked;
        publishDateController.text =
            DateFormat('dd MM yyyy - hh:mm a').format(picked.toLocal());
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = Get.find<HomeController>();
    final enteredPost = _splitAttachmentInput(postAttachmentController.text);
    final enteredStory = _splitAttachmentInput(storyAttachmentController.text);
    final postAttachments = [
      ...?widget.model?.postAttachments,
      ...enteredPost,
    ].toSet().toList();
    final storyAttachments = [
      ...?widget.model?.storyAttachments,
      ...enteredStory,
    ].toSet().toList();
    final files = [
      ...controller.uploadedFilesPaths,
      if (fileController.text.trim().isNotEmpty) fileController.text.trim(),
      ...postAttachments,
      ...storyAttachments,
    ].toSet().toList();

    final effectiveStatus =
        widget.model == null
            ? StorageKeys.status_under_revision
            : widget.model!.status;

    if (widget.model == null) {
      final ok = await controller.addContent(
        ContentModel(
          title: titleController.text,
          files: files,
          platform: platforms.toList(),
          publishDate: publishDate,
          contentType: contentTypeController.text,
          executor: executorController.text,
          clientId: widget.clientId,
          status: effectiveStatus,
          promotion: 'no_promotion',
          createdAt: DateTime.now(),
          notes: notesController.text,
          caption: captionController.text,
          postAttachments: postAttachments,
          storyAttachments: storyAttachments,
        ),
      );
      if (!mounted) return;
      if (ok) {
        controller.searchedContents.assignAll(
          List.from(
            controller.contents
                .where((a) => a.clientId == controller.clientController.text),
          ),
        );
        Get.back();
        controller.uploadedFilesPaths.clear();
        final clientName = controller.clients.firstWhereOrNull((c) => c.id == widget.clientId)?.name ?? widget.clientId;
        await NotificationService.notifyClientContentPendingApproval(
          clientId: widget.clientId,
          contentTypeLabel: 'content.notify.design_video_new'.tr,
        );
        await NotificationService.notifyManagersContentSubmittedByClient(clientName: clientName, contentTitle: titleController.text);
        if (effectiveStatus == StorageKeys.status_scheduled &&
            publishDate != null) {
          await NotificationService.notifyClientContentScheduled(
            clientId: widget.clientId,
            contentTitle: titleController.text,
            dateFormatted: FunHelper.formatdate(publishDate) ?? '',
          );
        }
      }
    } else {
      final ok = await controller.updateContent(
        widget.model!.copyWith(
          title: titleController.text,
          files: files,
          platform: platforms.toList(),
          publishDate: publishDate,
          contentType: contentTypeController.text,
          executor: executorController.text,
          clientId: widget.clientId,
          status: effectiveStatus,
          notes: notesController.text,
          caption: captionController.text,
          postAttachments: postAttachments,
          storyAttachments: storyAttachments,
        ),
      );
      if (!mounted) return;
      if (ok) {
        controller.searchedContents.assignAll(
          List.from(
            controller.contents
                .where((a) => a.clientId == controller.clientController.text),
          ),
        );
        Get.back();
        controller.uploadedFilesPaths.clear();
        await NotificationService.notifyClientContentUpdatedForApproval(clientId: widget.clientId, contentTitle: titleController.text);
        if (widget.model!.status == StorageKeys.status_edit_requested) {
          await NotificationService.notifyClientEditsDone(clientId: widget.clientId, contentTitle: titleController.text);
        }
        if (effectiveStatus == StorageKeys.status_scheduled &&
            publishDate != null) {
          await NotificationService.notifyClientContentScheduled(
            clientId: widget.clientId,
            contentTitle: titleController.text,
            dateFormatted: FunHelper.formatdate(publishDate) ?? '',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Color(0xFF5C5589),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.model == null ? 'addcontent'.tr : 'content.form.edit_title'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: GetBuilder<HomeController>(
        builder: (controller) {
          final employees = controller.employees;
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InputText(
                    labelText: 'title'.tr,
                    hintText: 'entertitle'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: titleController,
                    validator: (_) => null,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _pickPublishDate,
                    child: InputText(
                      labelText: 'publish_date'.tr,
                      hintText: '1/10/2025'.tr,
                      height: 48,
                      fillColor: Colors.white,
                      textInputType: TextInputType.datetime,
                      controller: publishDateController,
                      readOnly: true,
                      validator: (_) => null,
                      suffixIcon: Icon(
                        CupertinoIcons.calendar,
                        color: Colors.grey.shade600,
                      ),
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DynamicDropdown<EmployeeModel>(
                    items: employees
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('${v.name} (${v.role})'),
                          ),
                        )
                        .toList(),
                    value: executorController.text.isEmpty
                        ? null
                        : employees.firstWhereOrNull(
                            (a) => a.id == executorController.text,
                          ),
                    label: 'content_provider'.tr,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                    height: 48,
                    fillColor: Colors.white,
                    onChanged: (value) {
                      if (value != null) {
                        executorController.text = value.id ?? '';
                      }
                    },
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 16),
                  DynamicDropdown<String>(
                    items: StorageKeys.contentsTypeList
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(v.tr),
                          ),
                        )
                        .toList(),
                    value: contentTypeController.text.isEmpty
                        ? null
                        : contentTypeController.text,
                    label: 'choosecontenttype'.tr,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                    height: 48,
                    fillColor: Colors.white,
                    onChanged: (value) {
                      if (value != null) contentTypeController.text = value;
                    },
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => DynamicDropdownMultiSelect<String>(
                      items: StorageKeys.platformList
                          .map((v) => v.tr)
                          .toList(),
                      selectedValues: List<String>.from(platforms),
                      label: 'platform'.tr,
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                      height: 48,
                      fillColor: Colors.white,
                      validator: (_) => null,
                      onChanged: (value) => platforms.assignAll(value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: 'notes'.tr,
                    hintText: 'enternotes'.tr,
                    height: 100,
                    fillColor: Colors.white,
                    controller: notesController,
                    expanded: true,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: 'content.caption'.tr,
                    hintText: 'content.caption_hint'.tr,
                    height: 100,
                    fillColor: Colors.white,
                    controller: captionController,
                    expanded: true,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  InputText(
                    labelText: 'content.form.insert_link'.tr,
                    hintText: 'googledrivelink .com'.tr,
                    height: 48,
                    fillColor: Colors.white,
                    controller: fileController,
                    validator: (_) => null,
                    borderRadius: 8,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap:
                        () =>
                            _pickAttachmentFieldWithSource(postAttachmentController),
                    child: InputText(
                      labelText: 'content.post_attachment'.tr,
                      hintText: ''.tr,
                      enable: false,
                      height: 92,
                      fillColor: Colors.white,
                      controller: postAttachmentController,
                      validator: (_) => null,
                      expanded: true,
                      body: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'content.attachment_field_hint'.tr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            MainButton(
                              width: 132,
                              borderSize: 5,
                              height: 34,
                              fontSize: 11,
                              title: 'content.attachment_add_from_source'.tr,
                              backgroundColor: Colors.white,
                              fontColor: AppColors.primaryfontColor,
                            ),
                          ],
                        ),
                      ),
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap:
                        () => _pickAttachmentFieldWithSource(
                          storyAttachmentController,
                        ),
                    child: InputText(
                      labelText: 'content.story_attachment'.tr,
                      hintText: ''.tr,
                      enable: false,
                      height: 92,
                      fillColor: Colors.white,
                      controller: storyAttachmentController,
                      validator: (_) => null,
                      expanded: true,
                      body: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'content.attachment_field_hint'.tr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            MainButton(
                              width: 132,
                              borderSize: 5,
                              height: 34,
                              fontSize: 11,
                              title: 'content.attachment_add_from_source'.tr,
                              backgroundColor: Colors.white,
                              fontColor: AppColors.primaryfontColor,
                            ),
                          ],
                        ),
                      ),
                      borderRadius: 8,
                      borderColor: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      await _pickMainAttachmentWithSource();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'dragfile'.tr,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Obx(
                            () => controller.isUploading.value
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : MainButton(
                                    width: 100,
                                    borderSize: 5,
                                    height: 36,
                                    fontSize: 12,
                                    title:
                                        'content.attachment_add_from_source'.tr,
                                    backgroundColor: Colors.white,
                                    fontColor: AppColors.primaryfontColor,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Obx(
                    () =>
                        controller.uploadedFilesPaths.isEmpty
                            ? const SizedBox.shrink()
                            : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: controller.uploadedFilesPaths.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      mainAxisExtent: 96,
                                    ),
                                itemBuilder: (context, i) {
                                  final filePath =
                                      controller.uploadedFilesPaths[i]
                                          .toString();
                                  return Center(
                                    child: SizedBox(
                                      width: 88,
                                      height: 88,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned.fill(
                                            child:
                                                TaskDetailsDialogHelpers.attachmentThumbnail(
                                                  filePath,
                                                  onOpen: () =>
                                                      _openUploadedFile(
                                                        filePath,
                                                      ),
                                                ),
                                          ),
                                          PositionedDirectional(
                                            top: 4,
                                            end: 4,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  controller.uploadedFilesPaths
                                                      .remove(filePath);
                                                },
                                                child: Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          11,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                  ),
                  const SizedBox(height: 32),
                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5C5589),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: controller.isLoading.value
                            ? null
                            : _submit,
                        child: controller.isLoading.value
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'common.save'.tr,
                                style: const TextStyle(
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
}
