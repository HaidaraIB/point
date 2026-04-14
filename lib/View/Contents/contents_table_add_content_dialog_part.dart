part of 'package:point/View/Contents/ContentsTable.dart';

Widget _buildAttachmentPreviewTile(String url) {
  final bool isImage = getFileType(url) == 'image';
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child:
        isImage
            ? Image.network(
              url,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => _attachmentPlaceholderThumbnail(
                    Icons.broken_image_outlined,
                  ),
            )
            : _attachmentPlaceholderThumbnail(Icons.link_outlined),
  );
}

Widget _attachmentPlaceholderThumbnail(IconData icon) {
  return Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: Colors.blueGrey.shade100,
      border: Border.all(color: Colors.blueGrey.shade200),
    ),
    child: Icon(icon, size: 22, color: Colors.blueGrey.shade700),
  );
}

Widget _buildFormAttachmentThumbnail(String url) {
  final isImage = getFileType(url) == 'image';
  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.grey.shade100,
      ),
      child:
          isImage
              ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => _attachmentPlaceholderThumbnail(
                      Icons.broken_image_outlined,
                    ),
              )
              : _attachmentPlaceholderThumbnail(Icons.link_outlined),
    ),
  );
}

Future<void> _openAttachmentUrl(String rawUrl) async {
  await openUrlPreferInAppMedia(rawUrl);
}

void showAddContentDialog(
  BuildContext context, {
  ContentModel? model,
  required String clientId,
  bool? view,
}) {
  final hc = Get.find<HomeController>();
  if (!ContentPermissions.canAddOrEditContent(hc.currentEmployee.value)) {
    FunHelper.showSnackbar(
      'error'.tr,
      'errors.forbidden'.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return;
  }
  final titleController = TextEditingController(text: model?.title);
  RxList platforms = (model?.platform ?? []).obs;

  final contentTypeController = TextEditingController(text: model?.contentType);
  final executorController = TextEditingController(text: model?.executor);
  final notesController = TextEditingController(text: model?.clientNotes);
  final filecontroller = TextEditingController();

  final publishDatectr = TextEditingController(
    text: FunHelper.formatdate(model?.publishDate),
  );
  DateTime? publishDate = model?.publishDate;
  var _key = GlobalKey<FormState>();
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GetBuilder<HomeController>(
          builder: (controller) {
            return Form(
              key: _key,
              child: SizedBox(
                width: Get.width * 0.7,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        margin: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Color(0xFF5C5589),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/svgs/icon_check_circle.svg',
                            ),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'addcontent'.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'addcontenthint'.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            SizedBox(
                              width: (Get.width * 0.7) - 30,
                              child: InputText(
                                labelText: 'title'.tr,
                                hintText: 'entertitle'.tr,
                                height: 42,
                                fillColor: Colors.white,
                                controller: titleController,

                                validator: (_) => null,

                                borderRadius: 5,
                                borderColor: Colors.grey.shade300,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: (Get.width * 0.7 / 2) - 30,
                                  child: InputText(
                                    onTap: () async {
                                      final picked = await customDatePicker(
                                        context,
                                      );
                                      if (picked != null) {
                                        publishDate = picked;
                                        publishDatectr.text = DateFormat(
                                          'dd MM yyyy - hh:mm a',
                                        ).format(picked.toLocal());
                                      }
                                    },
                                    labelText: 'publish_date'.tr,
                                    hintText: '1/10/2025'.tr,
                                    height: 42,
                                    fillColor: Colors.white,
                                    textInputType: TextInputType.datetime,
                                    controller: publishDatectr,
                                    readOnly: true,
                                    validator: (_) => null,
                                    suffixIcon: Icon(
                                      CupertinoIcons.calendar,
                                      color: Colors.grey,
                                    ),
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                  ),
                                ),

                                SizedBox(
                                  width: (Get.width * 0.7 / 2) - 30,

                                  child: DynamicDropdown(
                                    items:
                                        controller.employees
                                            .map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(
                                                  '${v.name} (${v.role})',
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    value:
                                        executorController.text.isEmpty
                                            ? null
                                            : controller.employees
                                                .firstWhereOrNull(
                                                  (a) =>
                                                      a.id ==
                                                      executorController.text,
                                                ),
                                    label: 'content_provider'.tr,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                    height: 42,
                                    fillColor: Colors.white,
                                    onChanged: (value) {
                                      if (value != null) {
                                        executorController.text =
                                            (value).id ?? '';
                                      }
                                    },

                                    validator: (_) => null,
                                  ),
                                ),
                              ],
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: (Get.width * 0.7 / 2) - 30,

                                  child: DynamicDropdown(
                                    items:
                                        StorageKeys.contentsTypeList
                                            .map(
                                              (v) => DropdownMenuItem(
                                                value: v,
                                                child: Text(v.tr),
                                              ),
                                            )
                                            .toList(),
                                    value:
                                        contentTypeController.text.isEmpty
                                            ? null
                                            : contentTypeController.text,
                                    label: 'choosecontenttype'.tr,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                    height: 42,
                                    fillColor: Colors.white,
                                    onChanged: (value) {
                                      if (value != null) {
                                        contentTypeController.text = value;
                                      }
                                    },

                                    validator: (_) => null,
                                  ),
                                ),
                                Obx(
                                  () => SizedBox(
                                    width: (Get.width * 0.7 / 2) - 30,

                                    child: DynamicDropdownMultiSelect(
                                      items:
                                          StorageKeys.platformList
                                              .map((v) => v.tr)
                                              .toList(),
                                      selectedValues: List.from(platforms),
                                      label: 'platform'.tr,
                                      borderRadius: 5,
                                      borderColor: Colors.grey.shade300,
                                      height: 42,
                                      fillColor: Colors.white,

                                      validator: (_) => null,
                                      onChanged: (value) {
                                        platforms.assignAll(value);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: (Get.width * 0.7 / 2) - 30,
                                  child: InputText(
                                    labelText: 'notes'.tr,
                                    hintText: 'enternotes'.tr,
                                    height: 100,
                                    fillColor: Colors.white,
                                    controller: notesController,
                                    expanded: true,
                                    borderRadius: 5,
                                    borderColor: Colors.grey.shade300,
                                  ),
                                ),
                                Obx(
                                  () => Column(
                                    children: [
                                      SizedBox(
                                        width: (Get.width * 0.7 / 2) - 30,

                                        child: InputText(
                                          labelText:
                                              'content.form.insert_link'.tr,
                                          hintText: 'googledrivelink .com'.tr,
                                          height: 40,
                                          fillColor: Colors.white,
                                          validator: (_) => null,
                                          controller: filecontroller,
                                          suffixIcon: Container(
                                            width: 80,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              color: Colors.grey.shade200,
                                            ),
                                            // padding: EdgeInsets.only(left: 10),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Copy',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(width: 5),
                                                Icon(
                                                  Icons.copy_rounded,
                                                  weight: 1,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                              ],
                                            ),
                                          ),
                                          borderRadius: 5,
                                          borderColor: Colors.grey.shade300,
                                        ),
                                      ),
                                      SizedBox(
                                        width: (Get.width * 0.7 / 2) - 30,
                                        child: GestureDetector(
                                          onTap: () async {
                                            final files =
                                                await controller
                                                    .pickMultiFiles();
                                            for (var file in files) {
                                              controller.uploadFiles(
                                                filePathOrBytes: file.bytes!,
                                                fileName: file.name,
                                              );
                                            }
                                          },
                                          child: InputText(
                                            labelText: 'dragfile'.tr,
                                            hintText: ''.tr,
                                            validator: (_) => null,
                                            enable: false,
                                            height: 100,
                                            fillColor: Colors.white,
                                            // controller: notesController,
                                            expanded: true,

                                            body: Container(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Container(
                                                    margin:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),
                                                    child: Text(
                                                      'dragfile'.tr,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  MainButton(
                                                    width: 100,
                                                    borderSize: 5,
                                                    height: 30,
                                                    fontSize: 12,
                                                    load:
                                                        controller
                                                            .isUploading
                                                            .value,
                                                    title: 'uploadfile'.tr,
                                                    backgroundColor:
                                                        Colors.white,
                                                    fontColor:
                                                        AppColors
                                                            .primaryfontColor,
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
                                        width: (Get.width * 0.7 / 2) - 30,
                                        child: Obx(() {
                                          final files =
                                              controller.uploadedFilesPaths
                                                  .toList();
                                          if (files.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return GridView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: files.length,
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 2,
                                                  crossAxisSpacing: 10,
                                                  mainAxisSpacing: 10,
                                                  childAspectRatio: 1,
                                                ),
                                            itemBuilder: (context, index) {
                                              final filePath = files[index];
                                              return InkWell(
                                                onTap: () async {
                                                  await _openAttachmentUrl(
                                                    filePath,
                                                  );
                                                },
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child:
                                                          _buildFormAttachmentThumbnail(
                                                            filePath,
                                                          ),
                                                    ),
                                                    Positioned(
                                                      top: 6,
                                                      right: 6,
                                                      child: InkWell(
                                                        onTap: () {
                                                          controller
                                                              .uploadedFilesPaths
                                                              .remove(filePath);
                                                        },
                                                        child: Container(
                                                          width: 24,
                                                          height: 24,
                                                          decoration: BoxDecoration(
                                                            color:
                                                                Colors.black54,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          child: const Icon(
                                                            Icons.close,
                                                            color: Colors.white,
                                                            size: 15,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Actions
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (view != true)
                              Obx(
                                () => SizedBox(
                                  width: Get.width * 0.4 - 260,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF5C5589),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 48,
                                        vertical: 20,
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (_key.currentState!.validate()) {
                                        if (model == null) {
                                          await controller
                                              .addContent(
                                                ContentModel(
                                                  title: titleController.text,
                                                  files: [
                                                    ...controller
                                                        .uploadedFilesPaths,
                                                    ...filecontroller
                                                            .text
                                                            .isEmpty
                                                        ? []
                                                        : [
                                                          filecontroller.text
                                                              .trim(),
                                                        ], // الملفات الجديدة
                                                  ],
                                                  platform: platforms,
                                                  publishDate: publishDate,

                                                  contentType:
                                                      contentTypeController
                                                          .text,
                                                  executor:
                                                      executorController.text,
                                                  clientId: clientId,
                                                  status:
                                                      StorageKeys
                                                          .status_under_revision,
                                                  promotion: 'no_promotion',
                                                  // publishDate: publishDate,
                                                  createdAt: DateTime.now(),
                                                  notes: notesController.text,
                                                ),
                                              )
                                              .then((v) async {
                                                if (v) {
                                                  controller
                                                      .refreshFilteredContents();
                                                  Get.back();

                                                  await NotificationService.notifyClientContentPendingApproval(
                                                    clientId: clientId,
                                                    contentTypeLabel:
                                                        'content.notify.design_video_new'
                                                            .tr,
                                                  );
                                                  final clientName =
                                                      controller.clients
                                                          .firstWhereOrNull(
                                                            (c) =>
                                                                c.id ==
                                                                clientId,
                                                          )
                                                          ?.name ??
                                                      clientId;
                                                  await NotificationService.notifyManagersContentSubmittedByClient(
                                                    clientName: clientName,
                                                    contentTitle:
                                                        titleController.text,
                                                  );
                                                }
                                              });
                                        } else {
                                          controller
                                              .updateContent(
                                                model.copyWith(
                                                  title: titleController.text,

                                                  files: [
                                                    // الملفات القديمة (لو موجودة)
                                                    ...controller
                                                        .uploadedFilesPaths,
                                                    ...filecontroller
                                                            .text
                                                            .isEmpty
                                                        ? []
                                                        : [
                                                          filecontroller.text
                                                              .trim(),
                                                        ], // الملفات الجديدة
                                                  ],
                                                  platform: platforms,
                                                  publishDate: publishDate,
                                                  contentType:
                                                      contentTypeController
                                                          .text,
                                                  executor:
                                                      executorController.text,
                                                  clientId: clientId,
                                                  status:
                                                      StorageKeys
                                                          .status_under_revision,

                                                  notes: notesController.text,
                                                ),
                                              )
                                              .then((v) async {
                                                if (v) {
                                                  controller
                                                      .refreshFilteredContents();
                                                  Get.back();

                                                  await NotificationService.notifyClientContentUpdatedForApproval(
                                                    clientId: clientId,
                                                    contentTitle:
                                                        titleController.text,
                                                  );
                                                }
                                              });
                                        }
                                      }
                                    },
                                    child:
                                        controller.isLoading.value
                                            ? Center(
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                              ),
                                            )
                                            : Text(
                                              'common.save'.tr,
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                  ),
                                ),
                              ),
                            SizedBox(width: 20),
                            SizedBox(
                              width: 160,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 20,
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text('common.cancel'.tr),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
