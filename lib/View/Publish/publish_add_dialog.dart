import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/MetaPostModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/meta/meta_graph_client.dart';
import 'package:point/Services/meta/meta_errors.dart';
import 'package:point/Services/meta/meta_media_util.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/ContentPermissions.dart';
import 'package:point/View/Contents/Shared/content_attachment_source_input.dart';
import 'package:point/View/Contents/Shared/content_library_attachment_picker.dart';
import 'package:point/View/Publish/publish_add_mobile_page.dart';
import 'package:point/View/Shared/app_date_time_picker.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Publish/publish_meta_settings_dialog.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/t.dart';

/// Only Facebook + Instagram keys from [StorageKeys.platformList].
List<String> get _publishPlatformChoiceKeys => [
  StorageKeys.platformList[0],
  StorageKeys.platformList[1],
];

Future<void> _pickAndUploadSinglePublishMedia({
  required HomeController controller,
  required Rxn<String> mediaUrl,
  required Rxn<String> mediaType,
}) async {
  if (controller.isUploading.value) return;
  controller.uploadedFilesPaths.clear();
  final files = await controller.pickMultiFiles();
  if (files.isEmpty) return;
  if (files.length > 1) {
    FunHelper.showSnackbarDeduped(
      'common.info'.tr,
      'publish.local_extra_files_snackbar'.tr,
      dedupeKey: 'publish_local_extra_files',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.blueGrey.shade700,
      colorText: Colors.white,
    );
  }
  final f = files.first;
  if (f.bytes == null) return;
  final url = await controller.uploadFiles(
    filePathOrBytes: f.bytes!,
    fileName: f.name,
  );
  if (url != null && url.isNotEmpty) {
    mediaUrl.value = url;
    mediaType.value = publishMediaTypeFromUrl(url) ?? 'photo';
    controller.update();
  }
}

void _syncMediaFromUploadedList(
  HomeController controller,
  Rxn<String> mediaUrl,
  Rxn<String> mediaType,
) {
  if (controller.uploadedFilesPaths.isEmpty) {
    mediaUrl.value = null;
    mediaType.value = null;
    return;
  }
  final last = controller.uploadedFilesPaths.last.toString();
  mediaUrl.value = last;
  mediaType.value = publishMediaTypeFromUrl(last);
}

/// Library vs local drive — same flow as Content attachments.
Future<void> _pickPublishMediaWithSource({
  required BuildContext context,
  required HomeController controller,
  required Rxn<String> mediaUrl,
  required Rxn<String> mediaType,
}) async {
  if (controller.isUploading.value) return;
  final source = await showContentAttachmentSourceDialog(context);
  if (!context.mounted) return;
  if (source == null) return;
  if (source == ContentAttachmentSource.local) {
    await _pickAndUploadSinglePublishMedia(
      controller: controller,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );
    return;
  }
  final selected = await showLibraryAttachmentPickerDialog(
    context,
    maxSelections: 1,
    title: 'publish.library_picker_title'.tr,
  );
  if (!context.mounted) return;
  final urls = selected
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
  if (urls.isEmpty) return;
  final url = urls.first;
  controller.uploadedFilesPaths.clear();
  controller.uploadedFilesPaths.add(url);
  mediaUrl.value = url;
  mediaType.value = publishMediaTypeFromUrl(url) ?? 'photo';
  controller.update();
}

Future<void> showAddPublishDialog({
  MetaPostModel? existing,
  MetaPostModel? initialDraft,
  String? initialScheduleMode,
  bool forceSingleMediaSelection = false,
}) async {
  // Open full-screen add page on native OR compact web widths.
  // This keeps behavior aligned with the table responsive breakpoint.
  final bool useMobilePage = !kIsWeb || Get.width <= 850;
  if (useMobilePage) {
    await Get.to(
      () => PublishAddMobilePage(
        initialPost: existing,
        initialDraft: initialDraft,
        initialScheduleMode: initialScheduleMode,
        forceSingleMediaSelection: forceSingleMediaSelection,
      ),
    );
    return;
  }
  final hc = Get.find<HomeController>();
  if (!ContentPermissions.canAccessPublishSection(hc.currentEmployee.value)) {
    FunHelper.showSnackbarDeduped(
      'error'.tr,
      'errors.forbidden'.tr,
      dedupeKey: 'publish_access_forbidden',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return;
  }

  MetaAppSettings? settings;
  Get.dialog(
    const Center(child: CircularProgressIndicator()),
    barrierDismissible: false,
  );
  try {
    settings = await MetaAppSettings.load();
  } catch (e) {
    if (Get.isDialogOpen == true) Get.back();
    FunHelper.showSnackbarDeduped(
      'error'.tr,
      '${'publish.settings_load_failed'.tr}\n${e.toString()}',
      dedupeKey: 'publish_settings_load_failed',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return;
  }
  if (settings == null) {
    if (Get.isDialogOpen == true) Get.back();
    await Get.dialog<void>(
      AlertDialog(
        title: Text('error'.tr),
        content: Text('meta_err_settings_missing'.tr),
        actions: [
          TextButton(onPressed: Get.back, child: Text('common.cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              showPublishMetaSettingsDialog();
            },
            child: Text('publish.meta_settings'.tr),
          ),
        ],
      ),
      barrierDismissible: true,
    );
    return;
  }

  List<MetaBusinessAsset> assets;
  try {
    assets = await MetaGraphClient.listBusinessAssets(settings);
  } catch (e) {
    if (Get.isDialogOpen == true) Get.back();
    FunHelper.showSnackbarDeduped(
      'error'.tr,
      formatMetaPublishFailure(e, Get.locale?.languageCode ?? 'ar'),
      dedupeKey: 'publish_bootstrap_error',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return;
  }
  if (assets.isEmpty) {
    if (Get.isDialogOpen == true) Get.back();
    FunHelper.showSnackbarDeduped(
      'error'.tr,
      'publish.no_pages'.tr,
      dedupeKey: 'publish_no_pages',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return;
  }
  if (Get.isDialogOpen == true) Get.back();

  final titleController = TextEditingController();
  final captionController = TextEditingController();
  final selectedAsset = Rxn<MetaBusinessAsset>(assets.first);
  final postType = 'feed'.obs;
  final scheduleMode = 'now'.obs; // now | schedule
  final scheduledAt = Rxn<DateTime>();
  final platforms = <String>[
    StorageKeys.platformList[0],
    StorageKeys.platformList[1],
  ].obs;
  final mediaUrl = Rxn<String>();
  final mediaType = Rxn<String>();
  final clientId = '__none__'.obs;
  const noneClient = '__none__';

  hc.uploadedFilesPaths.clear();
  final seed = existing ?? initialDraft;
  if (seed != null) {
    titleController.text = seed.title;
    captionController.text = seed.caption ?? '';
    postType.value = seed.postType.trim().isEmpty
        ? 'feed'
        : seed.postType;
    scheduleMode.value =
        (initialScheduleMode ?? (seed.status == 'scheduled' ? 'schedule' : 'now')) ==
            'schedule'
        ? 'schedule'
        : 'now';
    scheduledAt.value = seed.scheduledAt;
    final existingMedia = seed.mediaUrl?.trim();
    if (existingMedia != null && existingMedia.isNotEmpty) {
      hc.uploadedFilesPaths.add(existingMedia);
      mediaUrl.value = existingMedia;
      mediaType.value = seed.mediaType ?? publishMediaTypeFromUrl(existingMedia);
    } else {
      mediaUrl.value = null;
      mediaType.value = seed.mediaType;
    }
    final existingClient = seed.clientId?.trim();
    clientId.value = (existingClient != null && existingClient.isNotEmpty)
        ? existingClient
        : noneClient;
    final pset = seed.platforms
        .map((e) => e.toString().toLowerCase())
        .toSet();
    final initialPlatforms = <String>[
      if (pset.contains('facebook')) StorageKeys.platformList[0],
      if (pset.contains('instagram')) StorageKeys.platformList[1],
    ];
    if (initialPlatforms.isNotEmpty) {
      platforms.assignAll(initialPlatforms);
    }
    for (final a in assets) {
      if (a.pageId == seed.pageId) {
        selectedAsset.value = a;
        break;
      }
    }
  }

  await Get.dialog<void>(
    Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: GetBuilder<HomeController>(
        builder: (controller) {
          return Builder(
            builder: (dialogContext) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existing == null
                            ? 'publish.add_title'.tr
                            : '${'edit'.tr} - ${'publish.add_title'.tr}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryfontColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      InputText(
                        labelText: 'title'.tr,
                        hintText: 'entertitle'.tr,
                        height: 42,
                        fillColor: Colors.white,
                        controller: titleController,
                        borderRadius: 5,
                        borderColor: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Obx(
                        () => DynamicDropdown<MetaBusinessAsset>(
                          items: assets
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(
                                    a.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          value: selectedAsset.value,
                          label: 'publish.page_label'.tr,
                          borderRadius: 5,
                          borderColor: Colors.grey.shade300,
                          height: 42,
                          fillColor: Colors.white,
                          onChanged: (v) {
                            selectedAsset.value = v;
                            controller.update();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Obx(
                        () => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text('publish.post_type_feed'.tr),
                              selected: postType.value == 'feed',
                              onSelected: (_) => postType.value = 'feed',
                            ),
                            ChoiceChip(
                              label: Text('publish.post_type_story'.tr),
                              selected: postType.value == 'story',
                              onSelected: (_) => postType.value = 'story',
                            ),
                            ChoiceChip(
                              label: Text('publish.post_type_reel'.tr),
                              selected: postType.value == 'reel',
                              onSelected: (_) => postType.value = 'reel',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'publish.schedule_mode'.tr,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Obx(
                        () => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text('publish.mode_now'.tr),
                              selected: scheduleMode.value == 'now',
                              onSelected: (_) => scheduleMode.value = 'now',
                            ),
                            ChoiceChip(
                              label: Text('publish.mode_schedule'.tr),
                              selected: scheduleMode.value == 'schedule',
                              onSelected: (_) =>
                                  scheduleMode.value = 'schedule',
                            ),
                          ],
                        ),
                      ),
                      Obx(() {
                        if (scheduleMode.value != 'schedule') {
                          return const SizedBox.shrink();
                        }
                        final t = scheduledAt.value;
                        final label = t == null
                            ? 'publish.pick_schedule_time'.tr
                            : DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(t.toLocal());
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              minimumSize: const Size.fromHeight(42),
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              final now = DateTime.now();
                              final initialDate =
                                  t?.toLocal() ??
                                  now.add(const Duration(minutes: 5));
                              final local = await pickAppDateTime(
                                dialogContext,
                                initialDateTime: initialDate,
                                firstDate: now,
                                lastDate: now.add(const Duration(days: 365)),
                              );
                              if (local == null) return;
                              scheduledAt.value = local.toUtc();
                              controller.update();
                            },
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(label),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Obx(
                        () => ContentAttachmentSourceInput(
                          labelText: 'publish.media'.tr,
                          bodyHintText: 'content.attachment_field_hint'.tr,
                          onTap: () => _pickPublishMediaWithSource(
                            context: dialogContext,
                            controller: controller,
                            mediaUrl: mediaUrl,
                            mediaType: mediaType,
                          ),
                          loading: controller.isUploading.value,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'publish.media_single_file_note'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                      ),
                      Obx(() {
                        final files = controller.uploadedFilesPaths.toList();
                        if (files.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: GridView.builder(
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
                            itemBuilder: (_, i) {
                              final fileUrl = files[i].toString();
                              final kind = publishFileKindFromUrl(fileUrl);
                              return Center(
                                child: SizedBox(
                                  width: 88,
                                  height: 88,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: kind == 'image'
                                              ? Image.network(
                                                  fileUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Container(
                                                        color: Colors
                                                            .blueGrey
                                                            .shade100,
                                                        child: Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          color: Colors
                                                              .blueGrey
                                                              .shade700,
                                                        ),
                                                      ),
                                                )
                                              : Container(
                                                  color:
                                                      Colors.blueGrey.shade100,
                                                  child: Icon(
                                                    kind == 'video'
                                                        ? Icons
                                                              .play_circle_fill_rounded
                                                        : Icons.link,
                                                    color: Colors
                                                        .blueGrey
                                                        .shade700,
                                                    size: kind == 'video'
                                                        ? 40
                                                        : 28,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: InkWell(
                                          onTap: () {
                                            controller.uploadedFilesPaths
                                                .remove(fileUrl);
                                            _syncMediaFromUploadedList(
                                              controller,
                                              mediaUrl,
                                              mediaType,
                                            );
                                            controller.update();
                                          },
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(10),
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
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      InputText(
                        labelText: 'publish.caption'.tr,
                        hintText: 'content.caption_hint'.tr,
                        height: 80,
                        fillColor: Colors.white,
                        controller: captionController,
                        expanded: true,
                        borderRadius: 5,
                        borderColor: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Obx(
                        () => DynamicDropdownMultiSelect<String>(
                          key: ValueKey(platforms.join(',')),
                          items: _publishPlatformChoiceKeys,
                          selectedValues: platforms.toList(),
                          itemLabel: (k) => k.tr,
                          label: 'publish.platforms'.tr,
                          borderRadius: 5,
                          borderColor: Colors.grey.shade300,
                          height: 42,
                          fillColor: Colors.white,
                          onChanged: (v) => platforms.assignAll(v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('publish.client_optional'.tr),
                      const SizedBox(height: 6),
                      Obx(
                        () => DropdownButton<String>(
                          isExpanded: true,
                          value: clientId.value,
                          items: [
                            DropdownMenuItem<String>(
                              value: noneClient,
                              child: Text('publish.client_none'.tr),
                            ),
                            ...controller.clients
                                .where((c) => (c.id ?? '').isNotEmpty)
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id!,
                                    child: Text(c.name ?? ''),
                                  ),
                                ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            clientId.value = v;
                            if (v == noneClient) return;
                            final selectedClient = controller.clients
                                .firstWhereOrNull((c) => c.id == v);
                            final linkedPageId =
                                (selectedClient?.metaPageId ?? '').trim();
                            if (linkedPageId.isEmpty) return;
                            final linkedAsset = assets.firstWhereOrNull(
                              (a) => a.pageId == linkedPageId,
                            );
                            if (linkedAsset != null) {
                              selectedAsset.value = linkedAsset;
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(120, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            onPressed: controller.isLoading.value
                                ? null
                                : () {
                                    controller.uploadedFilesPaths.clear();
                                    Get.back();
                                  },
                            child: Text(
                              'common.cancel'.tr,
                              style: TextStyle(
                                color: AppColors.primaryfontColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          MainButton(
                            title: existing == null
                                ? 'publish.save_draft'.tr
                                : 'common.save'.tr,
                            height: 40,
                            borderSize: 20,
                            width: 140,
                            margin: EdgeInsets.zero,
                            load: controller.isLoading.value,
                            onPressed: () async {
                              final asset = selectedAsset.value;
                              if (asset == null) return;
                              final title = titleController.text.trim();
                              if (title.isEmpty) return;
                              if (forceSingleMediaSelection &&
                                  (mediaUrl.value == null ||
                                      mediaUrl.value!.trim().isEmpty)) {
                                FunHelper.showSnackbarDeduped(
                                  'error'.tr,
                                  'publish.pick_single_dedicated_media'.tr,
                                  dedupeKey: 'publish_pick_single_media',
                                  snackPosition: SnackPosition.TOP,
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                );
                                return;
                              }
                              if (scheduleMode.value == 'schedule') {
                                final s = scheduledAt.value;
                                if (s == null) {
                                  FunHelper.showSnackbarDeduped(
                                    'error'.tr,
                                    'publish.schedule_time_required'.tr,
                                    dedupeKey: 'publish_schedule_required',
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                  return;
                                }
                                if (s.isBefore(
                                  DateTime.now().toUtc().add(
                                    const Duration(minutes: 1),
                                  ),
                                )) {
                                  FunHelper.showSnackbarDeduped(
                                    'error'.tr,
                                    'publish.schedule_time_future'.tr,
                                    dedupeKey: 'publish_schedule_future',
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                  return;
                                }
                              }
                              final fs = normalizeMetaPlatformsForFirestore(
                                platforms,
                              );
                              if (fs.isEmpty) {
                                FunHelper.showSnackbarDeduped(
                                  'error'.tr,
                                  'meta_err_no_platforms'.tr,
                                  dedupeKey: 'publish_no_platforms',
                                  snackPosition: SnackPosition.TOP,
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                );
                                return;
                              }
                              final emp = controller.currentEmployee.value;
                              final nextStatus =
                                  scheduleMode.value == 'schedule'
                                  ? 'scheduled'
                                  : 'created';
                              final post = MetaPostModel(
                                title: title,
                                pageId: asset.pageId,
                                pageAccessToken: asset.pageAccessToken,
                                pageName: asset.pageName,
                                instagramUserId: asset.instagramUserId,
                                instagramUserName: asset.instagramUserName,
                                postType: postType.value,
                                mediaType: mediaType.value,
                                mediaUrl: mediaUrl.value,
                                caption: captionController.text.trim(),
                                platforms: fs,
                                status: nextStatus,
                                clientId: clientId.value == noneClient
                                    ? null
                                    : clientId.value.trim(),
                                createdBy: existing?.createdBy ?? emp?.id,
                                lang: Get.locale?.languageCode ?? 'ar',
                                scheduledAt: scheduleMode.value == 'schedule'
                                    ? scheduledAt.value
                                    : null,
                                createdAt:
                                    existing?.createdAt ?? DateTime.now(),
                              );
                              final ok = existing == null
                                  ? await controller.addMetaPost(post)
                                  : await controller.updateMetaPost(
                                      existing.copyWith(
                                        title: post.title,
                                        pageId: post.pageId,
                                        pageAccessToken: post.pageAccessToken,
                                        pageName: post.pageName,
                                        instagramUserId: post.instagramUserId,
                                        instagramUserName:
                                            post.instagramUserName,
                                        postType: post.postType,
                                        mediaType: post.mediaType,
                                        mediaUrl: post.mediaUrl,
                                        caption: post.caption,
                                        platforms: post.platforms,
                                        status: post.status,
                                        clientId: post.clientId,
                                        createdBy: post.createdBy,
                                        lang: post.lang,
                                        scheduledAt: post.scheduledAt,
                                      ),
                                    );
                              controller.uploadedFilesPaths.clear();
                              if (ok && scheduleMode.value == 'schedule') {
                                FunHelper.showSnackbarDeduped(
                                  'common.save'.tr,
                                  'publish.schedule_saved'.tr,
                                  dedupeKey: 'publish_schedule_saved',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: Colors.green,
                                  colorText: Colors.white,
                                );
                              }
                              if (ok) Get.back();
                            },
                          ),
                        ],
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
    barrierDismissible: false,
  );
}
