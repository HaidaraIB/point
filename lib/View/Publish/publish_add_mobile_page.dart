import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/MetaPostModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/meta/meta_graph_client.dart';
import 'package:point/Services/meta/meta_errors.dart';
import 'package:point/Utils/ContentPermissions.dart';
import 'package:point/View/Contents/Shared/content_attachment_source_input.dart';
import 'package:point/View/Contents/Shared/content_library_attachment_picker.dart';
import 'package:point/View/Publish/publish_meta_settings_dialog.dart';
import 'package:point/View/Shared/app_date_time_picker.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/t.dart';

class PublishAddMobilePage extends StatefulWidget {
  const PublishAddMobilePage({super.key, this.initialPost});

  final MetaPostModel? initialPost;

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

  final RxBool _initialLoading = true.obs;
  final RxList<MetaBusinessAsset> _assets = <MetaBusinessAsset>[].obs;

  static const String _noneClient = '__none__';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  List<String> _normalizePlatformsForFirestore(List<dynamic> selectedKeys) {
    final out = <String>{};
    for (final s in selectedKeys) {
      final t = s.toString().toLowerCase();
      if (t.contains('facebook')) out.add('facebook');
      if (t.contains('instagram')) out.add('instagram');
    }
    return out.toList();
  }

  String _publishPathLower(String url) => url.split('?').first.toLowerCase();

  String _publishFileKindFromUrl(String url) {
    final p = _publishPathLower(url);
    if (p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.webp') ||
        p.endsWith('.gif')) {
      return 'image';
    }
    if (p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.webm') ||
        p.endsWith('.m4v') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv')) {
      return 'video';
    }
    return 'unknown';
  }

  String? _publishMediaTypeFromUrl(String url) {
    switch (_publishFileKindFromUrl(url)) {
      case 'image':
        return 'photo';
      case 'video':
        return 'video';
      default:
        return null;
    }
  }

  Future<void> _bootstrap() async {
    if (!ContentPermissions.canAccessPublishSection(
      _controller.currentEmployee.value,
    )) {
      FunHelper.showSnackbarDeduped(
        'error'.tr,
        'errors.forbidden'.tr,
        dedupeKey: 'publish_access_forbidden',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      if (mounted) Get.back();
      return;
    }

    _controller.uploadedFilesPaths.clear();
    _initialLoading.value = true;
    try {
      final settings = await MetaAppSettings.load();
      if (!mounted) return;
      if (settings == null) {
        await showPublishMetaSettingsDialog();
        if (!mounted) return;
      }
      final reloadedSettings = await MetaAppSettings.load();
      if (!mounted) return;
      if (reloadedSettings == null) {
        FunHelper.showSnackbarDeduped(
          'error'.tr,
          'meta_err_settings_missing'.tr,
          dedupeKey: 'publish_settings_missing',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Get.back();
        return;
      }
      final assets = await MetaGraphClient.listBusinessAssets(reloadedSettings);
      if (!mounted) return;
      _assets.assignAll(assets);
      if (assets.isNotEmpty) {
        _selectedAsset.value = assets.first;
        final existing = widget.initialPost;
        if (existing != null) {
          _titleController.text = existing.title;
          _captionController.text = existing.caption ?? '';
          _postType.value = existing.postType.trim().isEmpty
              ? 'feed'
              : existing.postType;
          _scheduleMode.value = existing.status == 'scheduled'
              ? 'schedule'
              : 'now';
          _scheduledAt.value = existing.scheduledAt;
          final existingMedia = existing.mediaUrl?.trim();
          if (existingMedia != null && existingMedia.isNotEmpty) {
            _controller.uploadedFilesPaths.add(existingMedia);
            _mediaUrl.value = existingMedia;
            _mediaType.value =
                existing.mediaType ?? _publishMediaTypeFromUrl(existingMedia);
          } else {
            _mediaType.value = existing.mediaType;
          }
          final existingClient = existing.clientId?.trim();
          _clientId.value =
              (existingClient != null && existingClient.isNotEmpty)
              ? existingClient
              : _noneClient;
          final pset = existing.platforms
              .map((e) => e.toString().toLowerCase())
              .toSet();
          final initialPlatforms = <String>[
            if (pset.contains('facebook')) StorageKeys.platformList[0],
            if (pset.contains('instagram')) StorageKeys.platformList[1],
          ];
          if (initialPlatforms.isNotEmpty) {
            _platforms.assignAll(initialPlatforms);
          }
          for (final a in assets) {
            if (a.pageId == existing.pageId) {
              _selectedAsset.value = a;
              break;
            }
          }
        }
      } else {
        FunHelper.showSnackbarDeduped(
          'error'.tr,
          'publish.no_pages'.tr,
          dedupeKey: 'publish_no_pages',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Get.back();
        return;
      }
    } catch (e) {
      if (!mounted) return;
      FunHelper.showSnackbarDeduped(
        'error'.tr,
        formatMetaPublishFailure(e, Get.locale?.languageCode ?? 'ar'),
        dedupeKey: 'publish_bootstrap_error',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      Get.back();
      return;
    } finally {
      _initialLoading.value = false;
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
      _mediaType.value = _publishMediaTypeFromUrl(url) ?? 'photo';
      _controller.update();
    }
  }

  Future<void> _pickPublishMediaWithSource() async {
    if (_controller.isUploading.value) return;
    final source = await showContentAttachmentSourceDialog(context);
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
    _mediaType.value = _publishMediaTypeFromUrl(url) ?? 'photo';
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
    _mediaType.value = _publishMediaTypeFromUrl(last);
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
    if (asset == null) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

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

    final fs = _normalizePlatformsForFirestore(_platforms);
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
    final nextStatus = _scheduleMode.value == 'schedule'
        ? 'scheduled'
        : 'created';
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
      createdBy: widget.initialPost?.createdBy ?? emp?.id,
      lang: Get.locale?.languageCode ?? 'ar',
      scheduledAt: _scheduleMode.value == 'schedule'
          ? _scheduledAt.value
          : null,
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
              createdBy: post.createdBy,
              lang: post.lang,
              scheduledAt: post.scheduledAt,
            ),
          );
    _controller.uploadedFilesPaths.clear();
    if (!mounted) return;
    if (ok && _scheduleMode.value == 'schedule') {
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
          TextButton(
            onPressed: _controller.isLoading.value ? null : _save,
            child: Text('common.save'.tr),
          ),
        ],
      ),
      body: Obx(() {
        if (_initialLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ListView(
              children: [
                InputText(
                  labelText: 'title'.tr,
                  hintText: 'entertitle'.tr,
                  height: 44,
                  fillColor: Colors.white,
                  controller: _titleController,
                  borderRadius: 8,
                  borderColor: Colors.grey.shade300,
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
                    borderColor: Colors.grey.shade300,
                    height: 44,
                    fillColor: Colors.white,
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
                      ChoiceChip(
                        label: Text('publish.post_type_feed'.tr),
                        selected: _postType.value == 'feed',
                        onSelected: (_) => _postType.value = 'feed',
                      ),
                      ChoiceChip(
                        label: Text('publish.post_type_story'.tr),
                        selected: _postType.value == 'story',
                        onSelected: (_) => _postType.value = 'story',
                      ),
                      ChoiceChip(
                        label: Text('publish.post_type_reel'.tr),
                        selected: _postType.value == 'reel',
                        onSelected: (_) => _postType.value = 'reel',
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
                        selected: _scheduleMode.value == 'now',
                        onSelected: (_) => _scheduleMode.value = 'now',
                      ),
                      ChoiceChip(
                        label: Text('publish.mode_schedule'.tr),
                        selected: _scheduleMode.value == 'schedule',
                        onSelected: (_) => _scheduleMode.value = 'schedule',
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
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                ),
                Obx(() {
                  final files = _controller.uploadedFilesPaths.toList();
                  if (files.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: files.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 96,
                          ),
                      itemBuilder: (_, i) {
                        final fileUrl = files[i].toString();
                        final kind = _publishFileKindFromUrl(fileUrl);
                        return Center(
                          child: SizedBox(
                            width: 88,
                            height: 88,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: kind == 'image'
                                        ? Image.network(
                                            fileUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  color:
                                                      Colors.blueGrey.shade100,
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Colors
                                                        .blueGrey
                                                        .shade700,
                                                  ),
                                                ),
                                          )
                                        : Container(
                                            color: Colors.blueGrey.shade100,
                                            child: Icon(
                                              kind == 'video'
                                                  ? Icons
                                                        .play_circle_fill_rounded
                                                  : Icons.link,
                                              color: Colors.blueGrey.shade700,
                                              size: kind == 'video' ? 40 : 28,
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: () {
                                      _controller.uploadedFilesPaths.remove(
                                        fileUrl,
                                      );
                                      _syncMediaFromUploadedList();
                                      _controller.update();
                                    },
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(10),
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
                  height: 100,
                  fillColor: Colors.white,
                  controller: _captionController,
                  expanded: true,
                  borderRadius: 8,
                  borderColor: Colors.grey.shade300,
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
                    borderColor: Colors.grey.shade300,
                    height: 44,
                    fillColor: Colors.white,
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
                      if (v != null) _clientId.value = v;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                MainButton(
                  title: 'publish.save_draft'.tr,
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
        );
      }),
    );
  }
}
