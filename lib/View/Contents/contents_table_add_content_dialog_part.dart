part of 'package:point/View/Contents/ContentsTable.dart';

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
  final captionController = TextEditingController(text: model?.caption);
  final filecontroller = TextEditingController();
  final postAttachmentController = TextEditingController(
    text: (model?.postAttachments ?? []).whereType<String>().join('\n'),
  );
  final storyAttachmentController = TextEditingController(
    text: (model?.storyAttachments ?? []).whereType<String>().join('\n'),
  );
  final reelAttachmentController = TextEditingController(
    text: (model?.reelAttachments ?? []).whereType<String>().join('\n'),
  );
  var submitStatus = StorageKeys.status_under_revision;
  List<String> splitAttachmentInput(String raw) {
    return raw
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void removeUrlFromAttachmentField(TextEditingController c, String url) {
    final next =
        splitAttachmentInput(c.text).where((e) => e != url).toList();
    c.text = next.join('\n');
  }

  void appendAttachmentLinks(
    TextEditingController controller,
    List<String> urls,
  ) {
    if (urls.isEmpty) return;
    final current = splitAttachmentInput(controller.text);
    final merged = {...current, ...urls}.toList();
    controller.text = merged.join('\n');
  }

  Future<void> pickMainAttachmentFromLocal() async {
    final files = await hc.pickMultiFiles();
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      await hc.uploadFiles(filePathOrBytes: bytes, fileName: file.name);
    }
  }

  Future<void> pickMainAttachmentWithSource(BuildContext context) async {
    final source = await resolveAttachmentSource(context);
    if (source == null) return;
    if (source == ContentAttachmentSource.local) {
      await pickMainAttachmentFromLocal();
      return;
    }
    final selected = await showLibraryAttachmentPickerDialog(context);
    if (selected.isEmpty) return;
    final merged = <String>{
      ...hc.uploadedFilesPaths.map((e) => e.toString().trim()),
      ...selected.map((e) => e.trim()),
    }.where((e) => e.isNotEmpty).toList();
    hc.uploadedFilesPaths.assignAll(merged);
  }

  Future<void> pickAttachmentFieldFromLocal(
    TextEditingController targetController,
  ) async {
    final files = await hc.pickMultiFiles();
    final added = <String>[];
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final url = await hc.uploadFiles(
        filePathOrBytes: bytes,
        fileName: file.name,
        addToUploadedFilesPathsList: false,
      );
      if (url != null && url.trim().isNotEmpty) {
        added.add(url.trim());
      }
    }
    appendAttachmentLinks(targetController, added);
  }

  Future<void> pickAttachmentFieldWithSource(
    BuildContext context,
    TextEditingController targetController,
  ) async {
    final source = await resolveAttachmentSource(context);
    if (source == null) return;
    if (source == ContentAttachmentSource.local) {
      await pickAttachmentFieldFromLocal(targetController);
      return;
    }
    final selected = await showLibraryAttachmentPickerDialog(context);
    appendAttachmentLinks(targetController, selected);
  }

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
        backgroundColor: Theme.of(context).colorScheme.surface,
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
                          color: context.appTheme.navSurface,
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
                                controller: titleController,

                                validator: (_) => null,

                                borderRadius: 5,
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
                                        initialDateTime: publishDate,
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
                                    textInputType: TextInputType.datetime,
                                    controller: publishDatectr,
                                    readOnly: true,
                                    validator: (_) => null,
                                    suffixIcon: Icon(
                                      CupertinoIcons.calendar,
                                      color: context.appTheme.mutedText,
                                    ),
                                    borderRadius: 5,
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
                                    height: 42,
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
                                    height: 42,
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
                                      height: 42,

                                      validator: (_) => null,
                                      onChanged: (value) {
                                        platforms.assignAll(value);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: (Get.width * 0.7) - 30,
                              child: InputText(
                                labelText: 'content.caption'.tr,
                                hintText: 'content.caption_hint'.tr,
                                height: 100,
                                controller: captionController,
                                expanded: true,
                                borderRadius: 5,
                              ),
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
                                    controller: notesController,
                                    expanded: true,
                                    borderRadius: 5,
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
                                          validator: (_) => null,
                                          controller: filecontroller,
                                          suffixIcon: Container(
                                            width: 80,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              color: context.appTheme.unselected,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Copy',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: context.appTheme.mutedText,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(width: 5),
                                                Icon(
                                                  Icons.copy_rounded,
                                                  weight: 1,
                                                  size: 16,
                                                  color: context.appTheme.mutedText,
                                                ),
                                              ],
                                            ),
                                          ),
                                          borderRadius: 5,
                                        ),
                                      ),
                                      SizedBox(
                                        width: (Get.width * 0.7 / 2) - 30,
                                        child: ContentAttachmentSourceInput(
                                          labelText: 'dragfile'.tr,
                                          bodyHintText: 'dragfile'.tr,
                                          onTap:
                                              () => pickMainAttachmentWithSource(
                                                context,
                                              ),
                                          loading: controller.isUploading.value,
                                        ),
                                      ),

                                      SizedBox(
                                        width: (Get.width * 0.7 / 2) - 30,
                                        child: ListenableBuilder(
                                          listenable: Listenable.merge([
                                            postAttachmentController,
                                            storyAttachmentController,
                                            reelAttachmentController,
                                          ]),
                                          builder: (context, _) {
                                            return Obx(
                                              () {
                                                final fieldUrls = <String>{
                                                  ...splitAttachmentInput(
                                                    postAttachmentController
                                                        .text,
                                                  ),
                                                  ...splitAttachmentInput(
                                                    storyAttachmentController
                                                        .text,
                                                  ),
                                                  ...splitAttachmentInput(
                                                    reelAttachmentController
                                                        .text,
                                                  ),
                                                };
                                                final urls =
                                                    controller
                                                        .uploadedFilesPaths
                                                        .map((e) => e.toString())
                                                        .where(
                                                          (u) =>
                                                              !fieldUrls
                                                                  .contains(
                                                                    u,
                                                                  ),
                                                        )
                                                        .toList();
                                                return FormAttachmentThumbnailsGrid(
                                                  urls: urls,
                                                  onRemoveUrl: (u) {
                                                    controller
                                                        .uploadedFilesPaths
                                                        .removeWhere(
                                                          (e) =>
                                                              e.toString() ==
                                                              u,
                                                        );
                                                  },
                                                  onOpenUrl:
                                                      _openAttachmentUrl,
                                                  spacing: 6,
                                                  tileExtent: 72,
                                                  closeButtonSize: 22,
                                                  closeIconSize: 13,
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ContentAttachmentSourceInput(
                                        labelText:
                                            'content.post_attachment'.tr,
                                        bodyHintText: 'dragfile'.tr,
                                        onTap:
                                            () =>
                                                pickAttachmentFieldWithSource(
                                                  context,
                                                  postAttachmentController,
                                                ),
                                      ),
                                      ListenableBuilder(
                                        listenable: postAttachmentController,
                                        builder: (context, _) {
                                          final urls = splitAttachmentInput(
                                            postAttachmentController.text,
                                          );
                                          if (urls.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child:
                                                FormAttachmentThumbnailsGrid(
                                                  urls: urls,
                                                  onRemoveUrl: (u) =>
                                                      removeUrlFromAttachmentField(
                                                        postAttachmentController,
                                                        u,
                                                      ),
                                                  onOpenUrl: _openAttachmentUrl,
                                                  spacing: 4,
                                                  tileExtent: 64,
                                                  closeButtonSize: 20,
                                                  closeIconSize: 12,
                                                ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ContentAttachmentSourceInput(
                                        labelText:
                                            'content.story_attachment'.tr,
                                        bodyHintText: 'dragfile'.tr,
                                        onTap:
                                            () =>
                                                pickAttachmentFieldWithSource(
                                                  context,
                                                  storyAttachmentController,
                                                ),
                                      ),
                                      ListenableBuilder(
                                        listenable: storyAttachmentController,
                                        builder: (context, _) {
                                          final urls = splitAttachmentInput(
                                            storyAttachmentController.text,
                                          );
                                          if (urls.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child:
                                                FormAttachmentThumbnailsGrid(
                                                  urls: urls,
                                                  onRemoveUrl: (u) =>
                                                      removeUrlFromAttachmentField(
                                                        storyAttachmentController,
                                                        u,
                                                      ),
                                                  onOpenUrl: _openAttachmentUrl,
                                                  spacing: 4,
                                                  tileExtent: 64,
                                                  closeButtonSize: 20,
                                                  closeIconSize: 12,
                                                ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ContentAttachmentSourceInput(
                                        labelText:
                                            'content.reel_attachment'.tr,
                                        bodyHintText: 'dragfile'.tr,
                                        onTap:
                                            () =>
                                                pickAttachmentFieldWithSource(
                                                  context,
                                                  reelAttachmentController,
                                                ),
                                      ),
                                      ListenableBuilder(
                                        listenable: reelAttachmentController,
                                        builder: (context, _) {
                                          final urls = splitAttachmentInput(
                                            reelAttachmentController.text,
                                          );
                                          if (urls.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child:
                                                FormAttachmentThumbnailsGrid(
                                                  urls: urls,
                                                  onRemoveUrl: (u) =>
                                                      removeUrlFromAttachmentField(
                                                        reelAttachmentController,
                                                        u,
                                                      ),
                                                  onOpenUrl: _openAttachmentUrl,
                                                  spacing: 4,
                                                  tileExtent: 64,
                                                  closeButtonSize: 20,
                                                  closeIconSize: 12,
                                                ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
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
                                      backgroundColor: AppColors.primary,
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
                                        final enteredPost = splitAttachmentInput(
                                          postAttachmentController.text,
                                        );
                                        final enteredStory = splitAttachmentInput(
                                          storyAttachmentController.text,
                                        );
                                        final enteredReel = splitAttachmentInput(
                                          reelAttachmentController.text,
                                        );
                                        final mergedPost = [
                                          ...?(model?.postAttachments),
                                          ...enteredPost,
                                        ].toSet().toList();
                                        final mergedStory = [
                                          ...?(model?.storyAttachments),
                                          ...enteredStory,
                                        ].toSet().toList();
                                        final mergedReel = [
                                          ...?(model?.reelAttachments),
                                          ...enteredReel,
                                        ].toSet().toList();
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
                                                        ],
                                                    ...mergedPost,
                                                    ...mergedStory,
                                                    ...mergedReel,
                                                  ].toSet().toList(),
                                                  platform: platforms,
                                                  publishDate: publishDate,

                                                  contentType:
                                                      contentTypeController
                                                          .text,
                                                  executor:
                                                      executorController.text,
                                                  clientId: clientId,
                                                  status:
                                                      submitStatus,
                                                  promotion: 'no_promotion',
                                                  // publishDate: publishDate,
                                                  createdAt: DateTime.now(),
                                                  notes: notesController.text,
                                                  caption: captionController.text,
                                                  postAttachments: mergedPost,
                                                  storyAttachments: mergedStory,
                                                  reelAttachments: mergedReel,
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
                                                        ],
                                                    ...mergedPost,
                                                    ...mergedStory,
                                                    ...mergedReel,
                                                  ].toSet().toList(),
                                                  platform: platforms,
                                                  publishDate: publishDate,
                                                  contentType:
                                                      contentTypeController
                                                          .text,
                                                  executor:
                                                      executorController.text,
                                                  clientId: clientId,
                                                  status:
                                                      submitStatus,

                                                  notes: notesController.text,
                                                  caption: captionController.text,
                                                  postAttachments: mergedPost,
                                                  storyAttachments: mergedStory,
                                                  reelAttachments: mergedReel,
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
