import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/MetaPostModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/meta/meta_graph_client.dart';
import 'package:point/Services/meta/meta_media_util.dart';
import 'package:point/View/Contents/Shared/content_attachment_source_input.dart';
import 'package:point/View/Contents/Shared/content_library_attachment_picker.dart';
import 'package:point/View/Shared/app_choice_chip.dart';
import 'package:point/View/Shared/app_date_time_picker.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/form_attachment_thumbnails_grid.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/t.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/media_url_opener.dart';

class PublishAddMobilePage extends StatefulWidget {
  const PublishAddMobilePage({
    super.key,
    required this.assets,
    this.initialPost,
    this.initialDraft,
    this.initialScheduleMode,
    this.forceSingleMediaSelection = false,
    this.queueOnNowSave = false,
  });

  final List<MetaBusinessAsset> assets;
  final MetaPostModel? initialPost;
  final MetaPostModel? initialDraft;
  final String? initialScheduleMode;
  final bool forceSingleMediaSelection;

  /// When true and schedule mode is "now", save as `queued_now` instead of
  /// a `created` draft (Content → Publish now).
  final bool queueOnNowSave;

  @override
  State<PublishAddMobilePage> createState() => _PublishAddMobilePageState();
}

class _PublishAddMobilePageState extends State<PublishAddMobilePage> {
  final HomeController _controller = Get.find<HomeController>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();

  final Rxn<MetaBusinessAsset> _selectedAsset = Rxn<MetaBusinessAsset>();
  final RxString _postType = 'feed'.obs;
  final RxString _scheduleMode = 'now'.obs;
  final Rxn<DateTime> _scheduledAt = Rxn<DateTime>();
  final RxList<String> _platforms = <String>[
    StorageKeys.platformList[0],
    StorageKeys.platformList[1],
  ].obs;
  final Rxn<String> _mediaUrl = Rxn<String>();
  final Rxn<String> _mediaType = Rxn<String>();
  final RxString _clientId = '__none__'.obs;

  final RxList<MetaBusinessAsset> _assets = <MetaBusinessAsset>[].obs;

  static const String _noneClient = '__none__';

  @override
  void initState() {
    super.initState();
    _seedForm(widget.assets);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _seedForm(List<MetaBusinessAsset> assets) {
    _controller.uploadedFilesPaths.clear();
    _assets.assignAll(assets);
    _selectedAsset.value = assets.first;
    final seed = widget.initialPost ?? widget.initialDraft;
    if (seed == null) return;

    _titleController.text = seed.title;
    _captionController.text = seed.caption ?? '';
    _postType.value =
        seed.postType.trim().isEmpty ? 'feed' : seed.postType;
    final mode =
        widget.initialScheduleMode ??
        (seed.status == 'scheduled' ? 'schedule' : 'now');
    _scheduleMode.value = mode == 'schedule' ? 'schedule' : 'now';
    _scheduledAt.value = seed.scheduledAt;
    final existingMedia = seed.mediaUrl?.trim();
    if (existingMedia != null && existingMedia.isNotEmpty) {
      _controller.uploadedFilesPaths.add(existingMedia);
      _mediaUrl.value = existingMedia;
      _mediaType.value =
          seed.mediaType ?? publishMediaTypeFromUrl(existingMedia);
    } else {
      _mediaType.value = seed.mediaType;
    }
    final existingClient = seed.clientId?.trim();
    _clientId.value = (existingClient != null && existingClient.isNotEmpty)
        ? existingClient
        : _noneClient;
    final pset = seed.platforms.map((e) => e.toString().toLowerCase()).toSet();
    final initialPlatforms = <String>[
      if (pset.contains('facebook')) StorageKeys.platformList[0],
      if (pset.contains('instagram')) StorageKeys.platformList[1],
    ];
    if (initialPlatforms.isNotEmpty) {
      _platforms.assignAll(initialPlatforms);
    }
    for (final a in assets) {
      if (a.pageId == seed.pageId) {
        _selectedAsset.value = a;
        break;
      }
    }
  }

  Future<void> _pickAndUploadSinglePublishMedia() async {
    if (_controller.isUploading.value) return;
    _controller.uploadedFilesPaths.clear();
    final files = await _controller.pickMultiFiles();
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
    final url = await _controller.uploadFiles(
      filePathOrBytes: f.bytes!,
      fileName: f.name,
    );
    if (url != null && url.isNotEmpty) {
      _mediaUrl.value = url;
      _mediaType.value = publishMediaTypeFromUrl(url) ?? 'photo';
      _controller.update();
    }
  }

  Future<void> _pickPublishMediaWithSource() async {
    if (_controller.isUploading.value) return;
    final source = await resolveAttachmentSource(context);
    if (!mounted) return;
    if (source == null) return;
    if (source == ContentAttachmentSource.local) {
      await _pickAndUploadSinglePublishMedia();
      return;
    }
    final selected = await showLibraryAttachmentPickerDialog(
      context,
      maxSelections: 1,
      title: 'publish.library_picker_title'.tr,
    );
    if (!mounted) return;
    final urls = selected
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) return;
    final url = urls.first;
    _controller.uploadedFilesPaths.clear();
    _controller.uploadedFilesPaths.add(url);
    _mediaUrl.value = url;
    _mediaType.value = publishMediaTypeFromUrl(url) ?? 'photo';
    _controller.update();
  }

  void _syncMediaFromUploadedList() {
    if (_controller.uploadedFilesPaths.isEmpty) {
      _mediaUrl.value = null;
      _mediaType.value = null;
      return;
    }
    final last = _controller.uploadedFilesPaths.last.toString();
    _mediaUrl.value = last;
    _mediaType.value = publishMediaTypeFromUrl(last);
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final initialDate =
        _scheduledAt.value?.toLocal() ?? now.add(const Duration(minutes: 5));
    final local = await pickAppDateTime(
      context,
      initialDateTime: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (local == null || !mounted) return;
    _scheduledAt.value = local.toUtc();
  }

  Future<void> _save() async {
    final asset = _selectedAsset.value;
    if (asset == null) {
      FunHelper.showSnackbarDeduped(
        'error'.tr,
        'publish.no_pages'.tr,
        dedupeKey: 'publish_no_page_selected',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      FunHelper.showSnackbarDeduped(
        'error'.tr,
        'entertitle'.tr,
        dedupeKey: 'publish_title_required',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (widget.forceSingleMediaSelection &&
        (_mediaUrl.value == null || _mediaUrl.value!.trim().isEmpty)) {
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

    if (_scheduleMode.value == 'schedule') {
      final s = _scheduledAt.value;
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
      if (s.isBefore(DateTime.now().toUtc().add(const Duration(minutes: 1)))) {
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

    final fs = normalizeMetaPlatformsForFirestore(_platforms);
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

    final emp = _controller.currentEmployee.value;
    final queueNow =
        widget.queueOnNowSave && _scheduleMode.value == 'now';
    final nextStatus = _scheduleMode.value == 'schedule'
        ? 'scheduled'
        : (queueNow ? 'queued_now' : 'created');
    final nowUtc = DateTime.now().toUtc();
    final seed = widget.initialPost ?? widget.initialDraft;
    final post = MetaPostModel(
      title: title,
      pageId: asset.pageId,
      pageAccessToken: asset.pageAccessToken,
      pageName: asset.pageName,
      instagramUserId: asset.instagramUserId,
      instagramUserName: asset.instagramUserName,
      postType: _postType.value,
      mediaType: _mediaType.value,
      mediaUrl: _mediaUrl.value,
      caption: _captionController.text.trim(),
      platforms: fs,
      status: nextStatus,
      clientId: _clientId.value == _noneClient ? null : _clientId.value.trim(),
      contentId: seed?.contentId,
      createdBy: widget.initialPost?.createdBy ?? emp?.id,
      lang: Get.locale?.languageCode ?? 'ar',
      scheduledAt: _scheduleMode.value == 'schedule'
          ? _scheduledAt.value
          : (queueNow ? nowUtc : null),
      createdAt: widget.initialPost?.createdAt ?? DateTime.now(),
    );
    final ok = widget.initialPost == null
        ? await _controller.addMetaPost(post)
        : await _controller.updateMetaPost(
            widget.initialPost!.copyWith(
              title: post.title,
              pageId: post.pageId,
              pageAccessToken: post.pageAccessToken,
              pageName: post.pageName,
              instagramUserId: post.instagramUserId,
              instagramUserName: post.instagramUserName,
              postType: post.postType,
              mediaType: post.mediaType,
              mediaUrl: post.mediaUrl,
              caption: post.caption,
              platforms: post.platforms,
              status: post.status,
              clientId: post.clientId,
              contentId: post.contentId,
              createdBy: post.createdBy,
              lang: post.lang,
              scheduledAt: post.scheduledAt,
              lastError: queueNow ? null : widget.initialPost!.lastError,
              metaResponse: queueNow ? null : widget.initialPost!.metaResponse,
            ),
          );
    _controller.uploadedFilesPaths.clear();
    if (!mounted || !ok) return;
    // Close page before snackbar. GetX Get.back() dismisses an open
    // snackbar instead of the route.
    Get.back();
    if (_scheduleMode.value == 'schedule') {
      FunHelper.showSnackbarDeduped(
        'common.save'.tr,
        'publish.schedule_saved'.tr,
        dedupeKey: 'publish_schedule_saved',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else if (queueNow) {
      FunHelper.showSnackbarDeduped(
        'common.save'.tr,
        'publish.queued_now'.tr,
        dedupeKey: 'publish_queued_now',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialPost == null
              ? 'publish.add_title'.tr
              : '${'edit'.tr} - ${'publish.add_title'.tr}',
        ),
        actions: [
          Obx(
            () => _controller.isLoading.value
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: Text('common.save'.tr),
                  ),
          ),
        ],
      ),
      body: Obx(() {
        return Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: ListView(
                  children: [
                InputText(
                  labelText: 'title'.tr,
                  hintText: 'entertitle'.tr,
                  height: 44,
                  controller: _titleController,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                Obx(
                  () => DynamicDropdown<MetaBusinessAsset>(
                    items: _assets
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
                    value: _selectedAsset.value,
                    label: 'publish.page_label'.tr,
                    borderRadius: 8,
                    height: 44,
                    onChanged: (v) {
                      _selectedAsset.value = v;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Obx(
                  () => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppChoiceChip(
                        label: 'publish.post_type_feed'.tr,
                        selected: _postType.value == 'feed',
                        onSelected: () => _postType.value = 'feed',
                      ),
                      AppChoiceChip(
                        label: 'publish.post_type_story'.tr,
                        selected: _postType.value == 'story',
                        onSelected: () => _postType.value = 'story',
                      ),
                      AppChoiceChip(
                        label: 'publish.post_type_reel'.tr,
                        selected: _postType.value == 'reel',
                        onSelected: () => _postType.value = 'reel',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'publish.schedule_mode'.tr,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Obx(
                  () => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppChoiceChip(
                        label: 'publish.mode_now'.tr,
                        selected: _scheduleMode.value == 'now',
                        onSelected: () => _scheduleMode.value = 'now',
                      ),
                      AppChoiceChip(
                        label: 'publish.mode_schedule'.tr,
                        selected: _scheduleMode.value == 'schedule',
                        onSelected: () => _scheduleMode.value = 'schedule',
                      ),
                    ],
                  ),
                ),
                Obx(() {
                  if (_scheduleMode.value != 'schedule') {
                    return const SizedBox.shrink();
                  }
                  final t = _scheduledAt.value;
                  final label = t == null
                      ? 'publish.pick_schedule_time'.tr
                      : DateFormat('yyyy-MM-dd HH:mm').format(t.toLocal());
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: _pickScheduleDateTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(label),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Obx(
                  () => ContentAttachmentSourceInput(
                    labelText: 'publish.media'.tr,
                    bodyHintText: 'content.attachment_field_hint'.tr,
                    onTap: _pickPublishMediaWithSource,
                    loading: _controller.isUploading.value,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'publish.media_single_file_note'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTheme.mutedText,
                      height: 1.35,
                    ),
                  ),
                ),
                Obx(() {
                  final files = _controller.uploadedFilesPaths
                      .map((e) => e.toString())
                      .toList();
                  if (files.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FormAttachmentThumbnailsGrid(
                      urls: files,
                      crossAxisCount: 3,
                      onRemoveUrl: (u) {
                        _controller.uploadedFilesPaths.removeWhere(
                          (e) => e.toString() == u,
                        );
                        _syncMediaFromUploadedList();
                        _controller.update();
                      },
                      onOpenUrl: (u) async => await openUrlPreferInAppMedia(u),
                      spacing: 10,
                      tileExtent: 96,
                      closeButtonSize: 20,
                      closeIconSize: 13,
                    ),
                  );
                }),
                const SizedBox(height: 12),
                InputText(
                  labelText: 'publish.caption'.tr,
                  hintText: 'content.caption_hint'.tr,
                  height: 100,
                  controller: _captionController,
                  expanded: true,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                Obx(
                  () => DynamicDropdownMultiSelect<String>(
                    key: ValueKey(_platforms.join(',')),
                    items: [
                      StorageKeys.platformList[0],
                      StorageKeys.platformList[1],
                    ],
                    selectedValues: _platforms.toList(),
                    itemLabel: (k) => k.tr,
                    label: 'publish.platforms'.tr,
                    borderRadius: 8,
                    height: 44,
                    onChanged: (v) => _platforms.assignAll(v),
                  ),
                ),
                const SizedBox(height: 12),
                Text('publish.client_optional'.tr),
                const SizedBox(height: 6),
                Obx(
                  () => DropdownButton<String>(
                    isExpanded: true,
                    value: _clientId.value,
                    items: [
                      DropdownMenuItem<String>(
                        value: _noneClient,
                        child: Text('publish.client_none'.tr),
                      ),
                      ..._controller.clients
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
                      _clientId.value = v;
                      if (v == _noneClient) return;
                      final selectedClient = _controller.clients
                          .firstWhereOrNull((c) => c.id == v);
                      final linkedPageId =
                          (selectedClient?.metaPageId ?? '').trim();
                      if (linkedPageId.isEmpty) return;
                      final linkedAsset = _assets.firstWhereOrNull(
                        (a) => a.pageId == linkedPageId,
                      );
                      if (linkedAsset != null) {
                        _selectedAsset.value = linkedAsset;
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
                MainButton(
                  title: widget.initialPost != null
                      ? 'common.save'.tr
                      : (widget.queueOnNowSave &&
                            _scheduleMode.value == 'now')
                      ? 'content.publish_now'.tr
                      : 'publish.save_draft'.tr,
                  height: 44,
                  borderSize: 12,
                  margin: EdgeInsets.zero,
                  load: _controller.isLoading.value,
                  onPressed: _save,
                ),
                const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_controller.isLoading.value)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      }),
    );
  }
}
