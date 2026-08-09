library point.home_controller;

import 'dart:async';
import 'dart:convert';
import 'package:point/Utils/app_log.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';

import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/MetaPostModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/LibraryFileModel.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Models/ProgrammingUpdateModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/AudioService.dart';
import 'package:point/Services/audio_tab_visibility.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/fcm_token_cache.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/notification_email_fields.dart';
import 'package:point/Services/push_permissions_helper.dart';
import 'package:point/Services/r2_storage_upload.dart';
import 'package:point/Services/upload_cancel_token.dart';
import 'package:point/Services/upload_diagnostics.dart';
import 'package:point/Services/upload_limits.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/meta/meta_media_util.dart';
import 'package:point/Services/firestore/firestore_task_utils.dart'
    show taskTypeCodeForNormalizedDepartment;
import 'package:point/Services/firestore/migrations/backfill_employee_departments.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart' show lookupMimeType;
// import 'package:http/http.dart' as http;

import 'package:point/config/app_config.dart';

import 'package:point/Controller/home_task_filters.dart';
import 'package:point/Utils/app_theme_extension.dart';

part 'home_controller_rebind.dart';

enum UploadUiPhase { idle, uploading, finalizing, failed, cancelled }

class HomeController extends GetxController {
  final FirestoreServices _service = FirestoreServices();
  FirestoreServices get service => _service;

  /// يمنع ربطاً مزدوجاً متزامناً لـ clients/tasks عند استدعاء fetchClients وfetchTasks معاً.
  int _clientsTasksRebindGeneration = 0;
  int selectedIndex = 0;

  var clientController = TextEditingController();
  RxString selectedTypeNotifications = 'clients'.obs; // clients, employees, all
  // Channels selection for "Send notifications" dialog.
  // Default true/true to match existing behavior (send push + email).
  RxBool sendPushNotifications = true.obs;
  RxBool sendEmailNotifications = true.obs;
  void changeType(String type) {
    selectedTypeNotifications.value = type;
  }

  Map<String, dynamic>? selectedChat;

  void changeIndex(int index) {
    selectedIndex = index;
    update();
  }

  /// Legacy single-select fields kept only as unused aliases during migration —
  /// prefer [selectedTaskStatuses] / [selectedHistoryStatuses].
  var selectedPriority = ''.obs;
  var selectedStatus = ''.obs;
  var selectedExecutor = ''.obs;
  var searchController = TextEditingController();

  // Ongoing Tasks multi-select filters (approved hidden by default).
  final RxList<String> selectedTaskStatuses = <String>[
    ...StorageKeys.statusListOngoing.where(
      (s) => s != StorageKeys.status_approved,
    ),
  ].obs;
  final RxList<String> selectedTaskPriorities = <String>[].obs;
  final RxList<String> selectedTaskExecutors = <String>[].obs;
  final RxInt taskFiltersRevision = 0.obs;
  String _taskFiltersAppliedType = '';

  // Task History multi-select filters.
  final RxList<String> selectedHistoryStatuses = <String>[].obs;
  final RxList<String> selectedHistoryPriorities = <String>[].obs;
  final RxList<String> selectedHistoryExecutors = <String>[].obs;
  final RxInt historyFiltersRevision = 0.obs;

  Timer? _employeeDashFilterSaveDebounce;
  Timer? _taskFilterSaveDebounce;
  Timer? _historyFilterSaveDebounce;
  Timer? _publishFilterSaveDebounce;
  Timer? _presenceHeartbeatTimer;
  String? _presenceHeartbeatEmployeeId;
  static const Duration _presenceHeartbeatInterval =
      kEmployeePresenceHeartbeatInterval;
  bool _appInForeground = true;

  // RxList<TaskModel> allTasks = <TaskModel>[].obs;
  RxList<TaskModel> tasksSearched = <TaskModel>[].obs;

  /// قائمة المهام المنتهية لصفحة سجل المهام
  RxList<TaskModel> tasksHistory = <TaskModel>[].obs;

  void filterTasks() {
    final searchText = searchController.text.trim().toLowerCase();
    final isEmployeeDash =
        currentEmployee.value?.role.trim().toLowerCase() == 'employee';
    final statusOptions = isEmployeeDash
        ? StorageKeys.employeeDashboardTaskStatusFilterDropdownValuesForDepartment(
            employeeDashboardDepartmentFilterArg,
          )
        : StorageKeys.ongoingStatusFilterDropdownValues(
            _taskFiltersAppliedType.isNotEmpty
                ? _taskFiltersAppliedType
                : selectedIndex.toString(),
          );
    final allowed = statusOptions.toSet();

    // Drop statuses that are invalid for the current department / role.
    final pruned = selectedTaskStatuses
        .where((s) => allowed.contains(s))
        .toList();
    if (pruned.length != selectedTaskStatuses.length) {
      selectedTaskStatuses.assignAll(pruned);
    }

    final empDash = currentEmployee.value;
    final isEmployee =
        empDash != null && empDash.role.trim().toLowerCase() == 'employee';
    final empId = empDash?.id?.trim() ?? '';
    final selectedStatuses = selectedTaskStatuses.toList();
    final rejectedSelected = selectedStatuses.any(
      (s) =>
          FunHelper.canonicalStoredStatus(s) == StorageKeys.status_rejected,
    );

    late List<TaskModel> baseList;
    if (isEmployee && rejectedSelected && empId.isNotEmpty) {
      // Include ongoing (matching selected) + rejected assigned to me when opted in.
      final ongoing = tasks.where((t) => StorageKeys.isTaskOngoing(t)).toList();
      final rejected = tasks.where((t) {
        if (t.assignedTo.trim() != empId) return false;
        return FunHelper.canonicalStoredStatus(t.status) ==
            StorageKeys.status_rejected;
      });
      baseList = [...ongoing, ...rejected];
    } else {
      baseList = tasks.where((t) => StorageKeys.isTaskOngoing(t)).toList();
    }

    if (isEmployee) {
      final arg = employeeDashboardDepartmentFilterArg;
      if (arg != null && arg.isNotEmpty) {
        final typeCode = taskTypeCodeForNormalizedDepartment(
          StorageKeys.normalizeDepartment(arg),
        );
        if (typeCode != null) {
          baseList = baseList.where((t) => t.type == typeCode).toList();
        }
      }
    }

    // Empty status selection = all ongoing (incl. approved). Non-empty = match set.
    if (selectedStatuses.isNotEmpty) {
      final selectedLower =
          selectedStatuses.map((s) => s.toLowerCase()).toSet();
      baseList = baseList
          .where((t) => selectedLower.contains(t.status.toLowerCase()))
          .toList();
    }

    if (searchText.isEmpty &&
        selectedTaskPriorities.isEmpty &&
        selectedTaskExecutors.isEmpty) {
      tasksSearched.assignAll(baseList);
      return;
    }

    tasksSearched.assignAll(
      filterTasksBySearchPriorityExecutor(
        baseList: baseList,
        searchText: searchText,
        selectedPriorities: selectedTaskPriorities.toList(),
        selectedExecutors: selectedTaskExecutors.toList(),
        employees: employees,
      ),
    );
  }

  /// Call when the Tasks department tab changes so status options stay valid.
  void syncTaskFiltersForType(String taskType) {
    if (_taskFiltersAppliedType == taskType &&
        selectedTaskStatuses.isNotEmpty) {
      final allowed =
          StorageKeys.ongoingStatusFilterDropdownValues(taskType).toSet();
      final pruned =
          selectedTaskStatuses.where((s) => allowed.contains(s)).toList();
      if (pruned.isNotEmpty) {
        if (pruned.length != selectedTaskStatuses.length) {
          selectedTaskStatuses.assignAll(pruned);
        }
        filterTasks();
        return;
      }
    }
    selectedTaskStatuses.assignAll(
      StorageKeys.defaultTaskStatusFilters(taskType),
    );
    _taskFiltersAppliedType = taskType;
    taskFiltersRevision.value++;
    filterTasks();
  }

  void setTaskFilterList(RxList<String> target, List<String> next) {
    target.assignAll(next);
    taskFiltersRevision.value++;
    filterTasks();
    schedulePersistTaskFilters();
  }

  String? _taskFiltersPrefsEmployeeId() {
    final a = currentEmployee.value?.id?.trim() ?? '';
    if (a.isNotEmpty) return a;
    final b = lastKnownEmployee.value?.id?.trim() ?? '';
    if (b.isNotEmpty) return b;
    return null;
  }

  Future<void> persistTaskFilters() async {
    final id = _taskFiltersPrefsEmployeeId();
    if (id == null || id.isEmpty) return;
    try {
      final pref = await SharedPreferences.getInstance();
      await pref.setString(
        StorageKeys.prefsTaskFiltersKey(id),
        jsonEncode({
          'statuses': selectedTaskStatuses.toList(),
          'priorities': selectedTaskPriorities.toList(),
          'executors': selectedTaskExecutors.toList(),
          'search': searchController.text,
          'taskType': _taskFiltersAppliedType,
        }),
      );
    } catch (_) {}
  }

  void schedulePersistTaskFilters() {
    _taskFilterSaveDebounce?.cancel();
    _taskFilterSaveDebounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(persistTaskFilters()),
    );
  }

  Future<void> restoreTaskFiltersFromPrefs({String? taskType}) async {
    final isEmployee =
        currentEmployee.value?.role.trim().toLowerCase() == 'employee';
    final type = taskType ?? selectedIndex.toString();
    List<String> defaults() => isEmployee
        ? StorageKeys.defaultEmployeeDashboardTaskStatusFilters(
            employeeDashboardDepartmentFilterArg,
          )
        : StorageKeys.defaultTaskStatusFilters(type);

    final id = _taskFiltersPrefsEmployeeId();
    if (id == null || id.isEmpty) {
      selectedTaskStatuses.assignAll(defaults());
      _taskFiltersAppliedType = type;
      filterTasks();
      taskFiltersRevision.value++;
      return;
    }
    try {
      final pref = await SharedPreferences.getInstance();
      final raw = pref.getString(StorageKeys.prefsTaskFiltersKey(id));
      if (raw == null || raw.isEmpty) {
        selectedTaskStatuses.assignAll(defaults());
        _taskFiltersAppliedType = type;
        filterTasks();
        taskFiltersRevision.value++;
        return;
      }
      final map = jsonDecode(raw);
      if (map is! Map) {
        selectedTaskStatuses.assignAll(defaults());
        _taskFiltersAppliedType = type;
        filterTasks();
        return;
      }
      final statuses = ((map['statuses'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      final priorities = ((map['priorities'] as List?) ?? const [])
          .map((e) => e.toString())
          .where(StorageKeys.priority.contains)
          .toList();
      final executors = ((map['executors'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      final search = (map['search'] as String?) ?? '';
      final allowed = isEmployee
          ? StorageKeys
              .employeeDashboardTaskStatusFilterDropdownValuesForDepartment(
                employeeDashboardDepartmentFilterArg,
              )
              .toSet()
          : StorageKeys.ongoingStatusFilterDropdownValues(type).toSet();
      final restoredStatuses = statuses.where(allowed.contains).toList();
      selectedTaskStatuses.assignAll(
        restoredStatuses.isEmpty ? defaults() : restoredStatuses,
      );
      selectedTaskPriorities.assignAll(priorities);
      selectedTaskExecutors.assignAll(executors);
      if (search.isNotEmpty) searchController.text = search;
      _taskFiltersAppliedType = type;
    } catch (_) {
      selectedTaskStatuses.assignAll(defaults());
      _taskFiltersAppliedType = type;
    }
    filterTasks();
    taskFiltersRevision.value++;
  }

  Future<void> clearTaskFilters({String? taskType}) async {
    searchController.clear();
    selectedTaskPriorities.clear();
    selectedTaskExecutors.clear();
    final type = taskType ?? selectedIndex.toString();
    if (currentEmployee.value?.role.trim().toLowerCase() == 'employee') {
      selectedTaskStatuses.assignAll(
        StorageKeys.defaultEmployeeDashboardTaskStatusFilters(
          employeeDashboardDepartmentFilterArg,
        ),
      );
    } else {
      selectedTaskStatuses.assignAll(
        StorageKeys.defaultTaskStatusFilters(type),
      );
    }
    _taskFiltersAppliedType = type;
    taskFiltersRevision.value++;
    filterTasks();
    await persistTaskFilters();
  }

  /// Firestore employee docs may omit `id` in the payload; prefs must still use the doc id.
  Future<void> persistEmployeeDashboardTaskFilters() async {
    await persistTaskFilters();
  }

  void schedulePersistEmployeeDashboardTaskFilters() {
    schedulePersistTaskFilters();
  }

  Future<void> restoreEmployeeDashboardTaskFiltersFromPrefs() async {
    await restoreTaskFiltersFromPrefs(
      taskType: taskTypeCodeForNormalizedDepartment(
            StorageKeys.normalizeDepartment(
              employeeDashboardDepartmentFilterArg ?? '',
            ),
          ) ??
          selectedIndex.toString(),
    );
  }

  Future<void> clearEmployeeDashboardTaskFilters() async {
    await clearTaskFilters();
  }

  // --- Publish section multi-select filters (persisted) ---

  final RxList<String> selectedPublishStatuses =
      <String>[...StorageKeys.defaultPublishStatusFilters].obs;
  final RxList<String> selectedPublishPlatforms = <String>[].obs;
  final RxList<String> selectedPublishPostTypes = <String>[].obs;
  final RxList<String> selectedPublishMediaTypes = <String>[].obs;
  final RxList<String> selectedPublishPageIds = <String>[].obs;
  final RxList<String> selectedPublishInstagramKeys = <String>[].obs;
  final RxList<String> selectedPublishClientIds = <String>[].obs;
  final RxList<String> selectedPublishCreatedByIds = <String>[].obs;
  final RxList<String> selectedPublishLangs = <String>[].obs;
  final TextEditingController publishSearchController = TextEditingController();
  final RxString publishSearchQuery = ''.obs;
  final Rxn<DateTime> publishDateFrom = Rxn<DateTime>();
  final Rxn<DateTime> publishDateTo = Rxn<DateTime>();
  /// Bumped on restore/clear so filter multi-select widgets rebuild selection.
  final RxInt publishFiltersRevision = 0.obs;

  String? _publishFiltersPrefsEmployeeId() {
    final a = currentEmployee.value?.id?.trim() ?? '';
    if (a.isNotEmpty) return a;
    final b = lastKnownEmployee.value?.id?.trim() ?? '';
    if (b.isNotEmpty) return b;
    return null;
  }

  static String? publishInstagramFilterKey(MetaPostModel p) {
    final id = (p.instagramUserId ?? '').trim();
    if (id.isNotEmpty) return id;
    final name = (p.instagramUserName ?? '').trim();
    if (name.isNotEmpty) return name;
    return null;
  }

  static String publishClientFilterKey(MetaPostModel p) {
    final id = (p.clientId ?? '').trim();
    if (id.isEmpty) return StorageKeys.publishClientFilterNone;
    return id;
  }

  static DateTime publishEffectiveDate(MetaPostModel p) =>
      (p.scheduledAt ?? p.createdAt).toLocal();

  static bool _publishStatusMatches(String rawStatus, List<String> selected) {
    if (selected.isEmpty) return true;
    final s = rawStatus.trim().toLowerCase();
    final normalized = s.isEmpty ? 'created' : s;
    for (final sel in selected) {
      if (sel == 'queued') {
        if (normalized == 'queued' || normalized == 'queued_now') return true;
      } else if (normalized == sel) {
        return true;
      }
    }
    return false;
  }

  List<String> publishPageFilterOptions() {
    final seen = <String>{};
    final out = <String>[];
    for (final p in metaPosts) {
      final id = p.pageId.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      out.add(id);
    }
    out.sort((a, b) {
      final la = publishPageFilterLabel(a).toLowerCase();
      final lb = publishPageFilterLabel(b).toLowerCase();
      return la.compareTo(lb);
    });
    return out;
  }

  String publishPageFilterLabel(String pageId) {
    final match = metaPosts.firstWhereOrNull((p) => p.pageId.trim() == pageId);
    final name = (match?.pageName ?? '').trim();
    if (name.isNotEmpty) return name;
    return pageId;
  }

  List<String> publishInstagramFilterOptions() {
    final seen = <String>{};
    final out = <String>[];
    for (final p in metaPosts) {
      final key = publishInstagramFilterKey(p);
      if (key == null || !seen.add(key)) continue;
      out.add(key);
    }
    out.sort((a, b) =>
        publishInstagramFilterLabel(a).toLowerCase().compareTo(
              publishInstagramFilterLabel(b).toLowerCase(),
            ));
    return out;
  }

  String publishInstagramFilterLabel(String key) {
    final match = metaPosts.firstWhereOrNull(
      (p) => publishInstagramFilterKey(p) == key,
    );
    final name = (match?.instagramUserName ?? '').trim();
    if (name.isNotEmpty) return name;
    return key;
  }

  List<String> publishClientFilterOptions() {
    final seen = <String>{StorageKeys.publishClientFilterNone};
    final out = <String>[StorageKeys.publishClientFilterNone];
    for (final p in metaPosts) {
      final id = (p.clientId ?? '').trim();
      if (id.isEmpty || !seen.add(id)) continue;
      out.add(id);
    }
    out.sort((a, b) {
      if (a == StorageKeys.publishClientFilterNone) return -1;
      if (b == StorageKeys.publishClientFilterNone) return 1;
      return publishClientFilterLabel(a)
          .toLowerCase()
          .compareTo(publishClientFilterLabel(b).toLowerCase());
    });
    return out;
  }

  String publishClientFilterLabel(String clientId) {
    if (clientId == StorageKeys.publishClientFilterNone) {
      return 'publish.client_none'.tr;
    }
    final c = clients.firstWhereOrNull((e) => e.id == clientId);
    final name = (c?.name ?? '').trim();
    if (name.isNotEmpty) return name;
    return clientId;
  }

  List<String> publishCreatedByFilterOptions() {
    final seen = <String>{};
    final out = <String>[];
    for (final p in metaPosts) {
      final id = (p.createdBy ?? '').trim();
      if (id.isEmpty || !seen.add(id)) continue;
      out.add(id);
    }
    out.sort((a, b) =>
        publishCreatedByFilterLabel(a).toLowerCase().compareTo(
              publishCreatedByFilterLabel(b).toLowerCase(),
            ));
    return out;
  }

  String publishCreatedByFilterLabel(String employeeId) {
    final e = employees.firstWhereOrNull((x) => x.id == employeeId);
    final name = (e?.name ?? '').trim();
    if (name.isNotEmpty) return name;
    return employeeId;
  }

  List<String> publishLangFilterOptions() {
    final seen = <String>{};
    final out = <String>[];
    for (final p in metaPosts) {
      final lang = (p.lang ?? '').trim().toLowerCase();
      if (lang.isEmpty || !seen.add(lang)) continue;
      out.add(lang);
    }
    out.sort();
    return out;
  }

  String publishLangFilterLabel(String lang) {
    switch (lang.trim().toLowerCase()) {
      case 'ar':
        return 'publish.filter_lang_ar'.tr;
      case 'en':
        return 'publish.filter_lang_en'.tr;
      default:
        return lang;
    }
  }

  String publishStatusFilterLabel(String status) {
    switch (status) {
      case 'queued':
        return 'publish.queued'.tr;
      case 'scheduled':
        return 'publish.scheduled'.tr;
      case 'published':
        return 'publish.published'.tr;
      case 'failed':
        return 'publish.failed'.tr;
      case 'publishing':
        return 'publish.publishing'.tr;
      case 'cancelled':
        return 'publish.cancelled'.tr;
      case 'created':
      default:
        return 'publish.created'.tr;
    }
  }

  String publishPlatformFilterLabel(String platform) {
    switch (platform.trim().toLowerCase()) {
      case 'facebook':
        return 'platform_facebook'.tr;
      case 'instagram':
        return 'platform_instagram'.tr;
      default:
        return platform;
    }
  }

  String publishPostTypeFilterLabel(String postType) {
    switch (postType.trim().toLowerCase()) {
      case 'reel':
        return 'publish.post_type_reel'.tr;
      case 'story':
        return 'publish.post_type_story'.tr;
      default:
        return 'publish.post_type_feed'.tr;
    }
  }

  String publishMediaTypeFilterLabel(String mediaType) {
    switch (mediaType.trim().toLowerCase()) {
      case 'video':
        return 'publish.filter_media_video'.tr;
      case 'photo':
      default:
        return 'publish.filter_media_photo'.tr;
    }
  }

  List<MetaPostModel> get filteredMetaPosts {
    final statuses = selectedPublishStatuses.toList();
    final platforms = selectedPublishPlatforms
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final postTypes = selectedPublishPostTypes
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final mediaTypes = selectedPublishMediaTypes
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final pageIds = selectedPublishPageIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final igKeys = selectedPublishInstagramKeys
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final clientIds = selectedPublishClientIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final createdByIds = selectedPublishCreatedByIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final langs = selectedPublishLangs
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final search = publishSearchQuery.value.trim().toLowerCase();
    final from = publishDateFrom.value;
    final to = publishDateTo.value;
    DateTime? fromDay;
    DateTime? toDay;
    if (from != null) {
      fromDay = DateTime(from.year, from.month, from.day);
    }
    if (to != null) {
      toDay = DateTime(to.year, to.month, to.day);
    }

    return metaPosts.where((p) {
      if (!_publishStatusMatches(p.status, statuses)) return false;

      if (platforms.isNotEmpty) {
        final postPlatforms = p.platforms
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();
        if (postPlatforms.intersection(platforms).isEmpty) return false;
      }

      if (postTypes.isNotEmpty) {
        final t = p.postType.trim().toLowerCase();
        final normalized = t.isEmpty ? 'feed' : t;
        if (!postTypes.contains(normalized)) return false;
      }

      if (mediaTypes.isNotEmpty) {
        final m = (p.mediaType ?? '').trim().toLowerCase();
        if (m.isEmpty || !mediaTypes.contains(m)) return false;
      }

      if (pageIds.isNotEmpty && !pageIds.contains(p.pageId.trim())) {
        return false;
      }

      if (igKeys.isNotEmpty) {
        final key = publishInstagramFilterKey(p);
        if (key == null || !igKeys.contains(key)) return false;
      }

      if (clientIds.isNotEmpty &&
          !clientIds.contains(publishClientFilterKey(p))) {
        return false;
      }

      if (createdByIds.isNotEmpty) {
        final id = (p.createdBy ?? '').trim();
        if (id.isEmpty || !createdByIds.contains(id)) return false;
      }

      if (langs.isNotEmpty) {
        final lang = (p.lang ?? '').trim().toLowerCase();
        if (lang.isEmpty || !langs.contains(lang)) return false;
      }

      if (search.isNotEmpty) {
        final title = p.title.toLowerCase();
        final caption = (p.caption ?? '').toLowerCase();
        if (!title.contains(search) && !caption.contains(search)) {
          return false;
        }
      }

      if (fromDay != null || toDay != null) {
        final d = publishEffectiveDate(p);
        final day = DateTime(d.year, d.month, d.day);
        if (fromDay != null && day.isBefore(fromDay)) return false;
        if (toDay != null && day.isAfter(toDay)) return false;
      }

      return true;
    }).toList();
  }

  Map<String, dynamic> _publishFiltersToJson() {
    return {
      'statuses': selectedPublishStatuses.toList(),
      'platforms': selectedPublishPlatforms.toList(),
      'postTypes': selectedPublishPostTypes.toList(),
      'mediaTypes': selectedPublishMediaTypes.toList(),
      'pageIds': selectedPublishPageIds.toList(),
      'instagramKeys': selectedPublishInstagramKeys.toList(),
      'clientIds': selectedPublishClientIds.toList(),
      'createdByIds': selectedPublishCreatedByIds.toList(),
      'langs': selectedPublishLangs.toList(),
      'search': publishSearchQuery.value,
      'dateFrom': publishDateFrom.value?.toIso8601String(),
      'dateTo': publishDateTo.value?.toIso8601String(),
    };
  }

  List<String> _sanitizePublishFilterList(
    dynamic raw,
    Set<String> allowed, {
    bool allowAny = false,
  }) {
    if (raw is! List) return <String>[];
    final out = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      final s = item?.toString().trim() ?? '';
      if (s.isEmpty || !seen.add(s)) continue;
      if (!allowAny && allowed.isNotEmpty && !allowed.contains(s)) continue;
      out.add(s);
    }
    return out;
  }

  Future<void> persistPublishFilters() async {
    final id = _publishFiltersPrefsEmployeeId();
    if (id == null || id.isEmpty) return;
    try {
      final pref = await SharedPreferences.getInstance();
      await pref.setString(
        StorageKeys.prefsPublishFiltersKey(id),
        jsonEncode(_publishFiltersToJson()),
      );
    } catch (_) {}
  }

  void schedulePersistPublishFilters() {
    _publishFilterSaveDebounce?.cancel();
    _publishFilterSaveDebounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(persistPublishFilters()),
    );
  }

  void onPublishSearchChanged(String value) {
    publishSearchQuery.value = value;
    schedulePersistPublishFilters();
  }

  void setPublishFilterList(RxList<String> target, List<String> next) {
    target.assignAll(next);
    unawaited(persistPublishFilters());
  }

  void setPublishDateFrom(DateTime? value) {
    publishDateFrom.value = value;
    unawaited(persistPublishFilters());
  }

  void setPublishDateTo(DateTime? value) {
    publishDateTo.value = value;
    unawaited(persistPublishFilters());
  }

  void _applyDefaultPublishFilters({bool bumpRevision = true}) {
    selectedPublishStatuses.assignAll(StorageKeys.defaultPublishStatusFilters);
    selectedPublishPlatforms.clear();
    selectedPublishPostTypes.clear();
    selectedPublishMediaTypes.clear();
    selectedPublishPageIds.clear();
    selectedPublishInstagramKeys.clear();
    selectedPublishClientIds.clear();
    selectedPublishCreatedByIds.clear();
    selectedPublishLangs.clear();
    publishSearchController.clear();
    publishSearchQuery.value = '';
    publishDateFrom.value = null;
    publishDateTo.value = null;
    if (bumpRevision) {
      publishFiltersRevision.value++;
    }
  }

  Future<void> restorePublishFiltersFromPrefs() async {
    final id = _publishFiltersPrefsEmployeeId();
    if (id == null || id.isEmpty) {
      _applyDefaultPublishFilters();
      return;
    }
    try {
      final pref = await SharedPreferences.getInstance();
      final raw = pref.getString(StorageKeys.prefsPublishFiltersKey(id));
      if (raw == null || raw.isEmpty) {
        _applyDefaultPublishFilters();
        return;
      }
      final map = jsonDecode(raw);
      if (map is! Map) {
        _applyDefaultPublishFilters();
        return;
      }
      final m = Map<String, dynamic>.from(map);

      final statuses = _sanitizePublishFilterList(
        m['statuses'],
        StorageKeys.publishStatusFilterOptions.toSet(),
      );
      selectedPublishStatuses.assignAll(
        statuses.isEmpty ? StorageKeys.defaultPublishStatusFilters : statuses,
      );
      selectedPublishPlatforms.assignAll(
        _sanitizePublishFilterList(
          m['platforms'],
          StorageKeys.publishPlatformFilterOptions.toSet(),
        ),
      );
      selectedPublishPostTypes.assignAll(
        _sanitizePublishFilterList(
          m['postTypes'],
          StorageKeys.publishPostTypeFilterOptions.toSet(),
        ),
      );
      selectedPublishMediaTypes.assignAll(
        _sanitizePublishFilterList(
          m['mediaTypes'],
          StorageKeys.publishMediaTypeFilterOptions.toSet(),
        ),
      );
      // Dynamic ids: keep any non-empty string (stale ids ignored at filter time).
      selectedPublishPageIds.assignAll(
        _sanitizePublishFilterList(m['pageIds'], const {}, allowAny: true),
      );
      selectedPublishInstagramKeys.assignAll(
        _sanitizePublishFilterList(
          m['instagramKeys'],
          const {},
          allowAny: true,
        ),
      );
      selectedPublishClientIds.assignAll(
        _sanitizePublishFilterList(m['clientIds'], const {}, allowAny: true),
      );
      selectedPublishCreatedByIds.assignAll(
        _sanitizePublishFilterList(
          m['createdByIds'],
          const {},
          allowAny: true,
        ),
      );
      selectedPublishLangs.assignAll(
        _sanitizePublishFilterList(m['langs'], const {}, allowAny: true),
      );

      final search = (m['search'] as String?)?.toString() ?? '';
      publishSearchController.text = search;
      publishSearchQuery.value = search;

      DateTime? parseDate(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        if (s.isEmpty) return null;
        return DateTime.tryParse(s);
      }

      publishDateFrom.value = parseDate(m['dateFrom']);
      publishDateTo.value = parseDate(m['dateTo']);
      publishFiltersRevision.value++;
    } catch (_) {
      _applyDefaultPublishFilters();
    }
  }

  Future<void> clearPublishFilters() async {
    _applyDefaultPublishFilters();
    await persistPublishFilters();
  }

  void filterTasksHistory() {
    final searchText = searchController.text.trim().toLowerCase();

    final allowed = <String>{
      ...StorageKeys.statusListEnded,
      StorageKeys.status_promotion_finished,
    };
    final pruned = selectedHistoryStatuses
        .where((s) => allowed.contains(s))
        .toList();
    if (pruned.length != selectedHistoryStatuses.length) {
      selectedHistoryStatuses.assignAll(pruned);
    }

    List<TaskModel> baseList =
        tasks.where((t) => StorageKeys.isTaskEnded(t)).toList();

    if (selectedHistoryStatuses.isNotEmpty) {
      final selectedLower =
          selectedHistoryStatuses.map((s) => s.toLowerCase()).toSet();
      baseList = baseList
          .where((t) => selectedLower.contains(t.status.toLowerCase()))
          .toList();
    }

    if (searchText.isEmpty &&
        selectedHistoryPriorities.isEmpty &&
        selectedHistoryExecutors.isEmpty) {
      tasksHistory.assignAll(baseList);
      return;
    }

    tasksHistory.assignAll(
      filterTasksBySearchPriorityExecutor(
        baseList: baseList,
        searchText: searchText,
        selectedPriorities: selectedHistoryPriorities.toList(),
        selectedExecutors: selectedHistoryExecutors.toList(),
        employees: employees,
      ),
    );
  }

  void setHistoryFilterList(RxList<String> target, List<String> next) {
    target.assignAll(next);
    historyFiltersRevision.value++;
    filterTasksHistory();
    schedulePersistHistoryFilters();
  }

  Future<void> persistHistoryFilters() async {
    final id = _taskFiltersPrefsEmployeeId();
    if (id == null || id.isEmpty) return;
    try {
      final pref = await SharedPreferences.getInstance();
      await pref.setString(
        StorageKeys.prefsHistoryTaskFiltersKey(id),
        jsonEncode({
          'statuses': selectedHistoryStatuses.toList(),
          'priorities': selectedHistoryPriorities.toList(),
          'executors': selectedHistoryExecutors.toList(),
          'search': searchController.text,
        }),
      );
    } catch (_) {}
  }

  void schedulePersistHistoryFilters() {
    _historyFilterSaveDebounce?.cancel();
    _historyFilterSaveDebounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(persistHistoryFilters()),
    );
  }

  Future<void> restoreHistoryFiltersFromPrefs() async {
    final id = _taskFiltersPrefsEmployeeId();
    if (id == null || id.isEmpty) {
      filterTasksHistory();
      return;
    }
    try {
      final pref = await SharedPreferences.getInstance();
      final raw = pref.getString(StorageKeys.prefsHistoryTaskFiltersKey(id));
      if (raw == null || raw.isEmpty) {
        filterTasksHistory();
        return;
      }
      final map = jsonDecode(raw);
      if (map is! Map) {
        filterTasksHistory();
        return;
      }
      final allowed = <String>{
        ...StorageKeys.statusListEnded,
        StorageKeys.status_promotion_finished,
      };
      selectedHistoryStatuses.assignAll(
        ((map['statuses'] as List?) ?? const [])
            .map((e) => e.toString())
            .where(allowed.contains),
      );
      selectedHistoryPriorities.assignAll(
        ((map['priorities'] as List?) ?? const [])
            .map((e) => e.toString())
            .where(StorageKeys.priority.contains),
      );
      selectedHistoryExecutors.assignAll(
        ((map['executors'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty),
      );
      final search = (map['search'] as String?) ?? '';
      if (search.isNotEmpty) searchController.text = search;
    } catch (_) {}
    filterTasksHistory();
    historyFiltersRevision.value++;
  }

  Future<void> clearHistoryFilters() async {
    searchController.clear();
    selectedHistoryStatuses.clear();
    selectedHistoryPriorities.clear();
    selectedHistoryExecutors.clear();
    historyFiltersRevision.value++;
    filterTasksHistory();
    await persistHistoryFilters();
  }

  String taskExecutorFilterLabel(String employeeId) {
    final match = employees.firstWhereOrNull((e) => e.id == employeeId);
    final name = (match?.name ?? '').trim();
    if (name.isNotEmpty) {
      return name.split(' ').take(2).join(' ');
    }
    return employeeId;
  }

  List<String> taskExecutorFilterOptions() {
    final out = <String>[];
    for (final e in employees) {
      final id = (e.id ?? '').trim();
      if (id.isEmpty) continue;
      out.add(id);
    }
    out.sort(
      (a, b) => taskExecutorFilterLabel(a)
          .toLowerCase()
          .compareTo(taskExecutorFilterLabel(b).toLowerCase()),
    );
    return out;
  }

  fetchEmployees() {
    if (FirebaseAuth.instance.currentUser == null) {
      employees.bindStream(Stream<List<EmployeeModel>>.value([]));
      update();
      return;
    }
    employees.bindStream(_service.getEmployees());

    update();
  }

  void fetchClients() {
    _rebindClientsAndTasksStreams();
  }

  /// Awaitable rebind used after login so navigation does not race an empty
  /// clients list from a too-early permission-denied listener.
  Future<void> rebindClientsAndTasksStreamsAndWait() async {
    if (FirebaseAuth.instance.currentUser == null) {
      clients.bindStream(Stream<List<ClientModel>>.value([]));
      tasks.bindStream(Stream<List<TaskModel>>.value([]));
      libraryFiles.bindStream(Stream<List<LibraryFileModel>>.value([]));
      libraryBrowseTasks.bindStream(Stream<List<TaskModel>>.value([]));
      update();
      return;
    }
    final gen = ++_clientsTasksRebindGeneration;
    await homeRebindClientsAndTasksStreamsAsync(this, gen);
  }

  /// Sync [authRoles], confirm it is readable from the server, seed clients
  /// with a one-shot get, then bind live streams.
  Future<void> syncAuthRoleAndRefreshDataStreams(EmployeeModel employee) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    for (var attempt = 0; attempt < 4; attempt++) {
      final synced = await FirestoreServices.syncAuthRoleForEmployee(employee);
      if (!synced) {
        await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        continue;
      }
      if (uid == null || uid.isEmpty) break;
      try {
        final snap = await FirebaseFirestore.instance
            .collection('authRoles')
            .doc(uid)
            .get(const GetOptions(source: Source.server));
        if (snap.exists) break;
      } catch (e) {
        appLog('syncAuthRoleAndRefreshDataStreams authRoles get: $e');
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
    }

    final role = employee.role.trim().toLowerCase();
    final needsClients = role == 'admin' ||
        role == 'supervisor' ||
        role == 'employee';

    if (needsClients) {
      // Seed immediately so navigating to Clients is not empty while the
      // snapshot listener attaches (and survives a later bindStream cancel).
      for (var attempt = 0; attempt < 4; attempt++) {
        try {
          final list = await _service.getClientsOnce();
          clients.assignAll(list);
          if (list.isNotEmpty || attempt == 3) break;
        } catch (e) {
          appLog('syncAuthRoleAndRefreshDataStreams getClientsOnce: $e');
          await FirestoreServices.syncAuthRoleForEmployee(employee);
          await Future<void>.delayed(
            Duration(milliseconds: 300 * (attempt + 1)),
          );
        }
      }
    }

    await rebindClientsAndTasksStreamsAndWait();
    fetchContents();
    if (role == 'admin' || role == 'supervisor') {
      fetchMetaPosts();
    }
  }

  /// يربط تيار العملاء والمهام حسب الدور: العميل لا يستطيع استعلامات المجموعة الكاملة.
  void _rebindClientsAndTasksStreams() {
    if (FirebaseAuth.instance.currentUser == null) {
      clients.bindStream(Stream<List<ClientModel>>.value([]));
      tasks.bindStream(Stream<List<TaskModel>>.value([]));
      libraryFiles.bindStream(Stream<List<LibraryFileModel>>.value([]));
      libraryBrowseTasks.bindStream(Stream<List<TaskModel>>.value([]));
      update();
      return;
    }
    final gen = ++_clientsTasksRebindGeneration;
    unawaited(homeRebindClientsAndTasksStreamsAsync(this, gen));
  }

  Future<bool> addEmployee(
    EmployeeModel employee, {
    required String password,
  }) async {
    final emailToCheck = (employee.email ?? '').trim().toLowerCase();
    if (emailToCheck.isNotEmpty) {
      final emailUsed = await _service.isEmailUsedAcrossUsers(emailToCheck);
      if (emailUsed) {
        FunHelper.showSnackbar(
          'error'.tr,
          'client.errors.email_in_use_cross'.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    }
    isLoading.value = true;
    final result = await _service.createEmployeeWithAuth(
      employee: employee,
      password: password,
    );
    if (result && (employee.role == 'admin' || employee.role == 'supervisor')) {
      await addToGroups(employee.id!);
    }
    isLoading.value = false;
    return result;
  }

  addToGroups(String userId) async {
    for (var group in StorageKeys.departments) {
      final groupRef = FirebaseFirestore.instance
          .collection('chats')
          .doc('group_$group');

      await groupRef.update({
        'participants': FieldValue.arrayUnion([userId]),
      });
    }
  }

  Future<bool> updateEmployee(
    EmployeeModel employee, {
    String? newPassword,
  }) async {
    final emailToCheck = (employee.email ?? '').trim().toLowerCase();
    if (emailToCheck.isNotEmpty) {
      final emailUsed = await _service.isEmailUsedAcrossUsers(
        emailToCheck,
        excludeEmployeeId: employee.id,
      );
      if (emailUsed) {
        FunHelper.showSnackbar(
          'error'.tr,
          'client.errors.email_in_use_cross'.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    }
    isLoading.value = true;
    // نحتاج النسخة القديمة للمقارنة وتمريرها للـ service
    final existing = employees.firstWhereOrNull((e) => e.id == employee.id);
    final result = existing == null
        ? await _service.updateEmployee(employee)
        : await _service.updateEmployeeWithAuth(
            existing: existing,
            updated: employee,
            newPassword: newPassword,
          );
    if (result && (employee.role == 'admin' || employee.role == 'supervisor')) {
      await addToGroups(employee.id!);
    }
    isLoading.value = false;
    return result;
  }

  Future<bool> setEmployeeLibraryAccess({
    required String employeeId,
    required bool enabled,
  }) async {
    final result = await _service.setEmployeeLibraryAccess(
      employeeId: employeeId,
      enabled: enabled,
    );
    if (result && effectiveEmployee?.id == employeeId) {
      _rebindClientsAndTasksStreams();
    }
    return result;
  }

  /// Tasks stream for Library page and attachment picker (full archive when granted).
  List<TaskModel> get tasksForLibraryBrowse {
    if (libraryBrowseTasks.isNotEmpty) return libraryBrowseTasks;
    return tasks;
  }

  /// تحديث الاسم/الصورة للمستخدم الحالي (لوحة الموظف) دون الاعتماد على قائمة [employees].
  Future<bool> updateMyProfile({required String name, String? imageUrl}) async {
    final existing = currentEmployee.value;
    if (existing == null ||
        existing.id == null ||
        existing.id!.trim().isEmpty) {
      FunHelper.showSnackbar(
        'error'.tr,
        'employee.profile.error_no_session'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      FunHelper.showSnackbar(
        'error'.tr,
        'employee.profile.error_name_empty'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
    isLoading.value = true;
    final result = await _service.updateEmployeeProfileFields(
      employeeId: existing.id!,
      name: trimmed,
      imageUrl: imageUrl ?? existing.image,
    );
    isLoading.value = false;
    if (result) {
      FunHelper.showSnackbar(
        'success'.tr,
        'employee.profile.saved'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      FunHelper.showSnackbar(
        'error'.tr,
        'employee.profile.save_failed'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    return result;
  }

  Future<bool> deleteEmployee(String id) async {
    final trimmed = id.trim();
    final meId = currentEmployee.value?.id?.trim();
    if (meId != null &&
        meId.isNotEmpty &&
        trimmed.isNotEmpty &&
        trimmed == meId) {
      FunHelper.showSnackbar(
        'error'.tr,
        'employees.cannot_delete_self'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
    isLoading.value = true;
    final result = await _service.deleteEmployee(id);
    isLoading.value = false;
    return result;
  }

  EmployeeModel? getEmployeeById(String? id) {
    return employees.firstWhereOrNull((a) => a.id == id);
  }

  Future<bool> addClient(ClientModel client, {required String password}) async {
    final emailToCheck = (client.email ?? '').trim().toLowerCase();
    if (emailToCheck.isNotEmpty) {
      final emailUsed = await _service.isEmailUsedAcrossUsers(emailToCheck);
      if (emailUsed) {
        FunHelper.showSnackbar(
          'error'.tr,
          'client.errors.email_in_use_cross'.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    }
    isLoading.value = true;
    final result = await _service.createClientWithAuth(
      client: client,
      password: password,
    );
    isLoading.value = false;
    return result;
  }

  Future<bool> updateClient(ClientModel client, {String? newPassword}) async {
    final emailToCheck = (client.email ?? '').trim().toLowerCase();
    if (emailToCheck.isNotEmpty) {
      final emailUsed = await _service.isEmailUsedAcrossUsers(
        emailToCheck,
        excludeClientId: client.id,
      );
      if (emailUsed) {
        FunHelper.showSnackbar(
          'error'.tr,
          'client.errors.email_in_use_cross'.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    }
    isLoading.value = true;
    final existing = clients.firstWhereOrNull((c) => c.id == client.id);
    final result = existing == null
        ? await _service.updateClient(client)
        : await _service.updateClientWithAuth(
            existing: existing,
            updated: client,
            newPassword: newPassword,
          );
    isLoading.value = false;
    return result;
  }

  Future<bool> deleteClient(String id) async {
    isLoading.value = true;
    final result = await _service.deleteClient(id);
    isLoading.value = false;
    if (result) {
      clients.removeWhere((c) => c.id == id);
      if (clientController.text.trim() == id) {
        clientController.clear();
        selectedDate.value = '';
        searchedContents.assignAll(List<ContentModel>.from(contents));
      }
      update();
    }
    return result;
  }

  void fetchContents() {
    if (FirebaseAuth.instance.currentUser == null) {
      contents.bindStream(Stream<List<ContentModel>>.value([]));
      return;
    }
    final emp = effectiveEmployee;
    if (emp == null) {
      contents.bindStream(Stream<List<ContentModel>>.value([]));
      return;
    }
    final r = emp.role;
    if (r == 'admin' || r == 'supervisor') {
      contents.bindStream(_service.getContents());
      return;
    }
    if (r == 'employee') {
      final depts = emp.departments;
      if (depts.contains(StorageKeys.departmentPromotion) ||
          depts.contains(StorageKeys.departmentPublishing)) {
        contents.bindStream(_service.getContents());
        return;
      }
    }
    contents.bindStream(Stream<List<ContentModel>>.value([]));
  }

  void fetchMetaPosts() {
    if (FirebaseAuth.instance.currentUser == null) {
      metaPosts.bindStream(Stream<List<MetaPostModel>>.value([]));
      return;
    }
    final emp = effectiveEmployee;
    if (emp == null) {
      metaPosts.bindStream(Stream<List<MetaPostModel>>.value([]));
      return;
    }
    final r = emp.role;
    if (r == 'admin' || r == 'supervisor') {
      metaPosts.bindStream(_service.getMetaPosts());
      return;
    }
    metaPosts.bindStream(Stream<List<MetaPostModel>>.value([]));
  }

  void clearEmployeeWebContentFilters() {
    employeeWebContentSearchController.clear();
    employeeWebContentStatusFilters.clear();
    employeeWebContentTypeFilters.clear();
    employeeWebContentDateFilter.value = null;
    employeeWebContentFiltersRevision.value++;
    update(['employeeWebContent']);
  }

  void setEmployeeWebContentFilterList(RxList<String> target, List<String> next) {
    target.assignAll(next);
    employeeWebContentFiltersRevision.value++;
    update(['employeeWebContent']);
  }

  void toggleContentSelection(String contentId, {bool? selected}) {
    if (contentId.trim().isEmpty) return;
    final shouldSelect = selected ?? !selectedContentIds.contains(contentId);
    if (shouldSelect) {
      selectedContentIds.add(contentId);
    } else {
      selectedContentIds.remove(contentId);
    }
    selectedContentIds.refresh();
    update(['employeeWebContent']);
  }

  void clearSelectedContentIds() {
    selectedContentIds.clear();
    selectedContentIds.refresh();
    update(['employeeWebContent']);
  }

  void toggleSelectAllVisibleContents(List<ContentModel> visibleContents) {
    final ids = visibleContents
        .map((c) => c.id?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;
    final allSelected = ids.every(selectedContentIds.contains);
    if (allSelected) {
      selectedContentIds.removeAll(ids);
    } else {
      selectedContentIds.addAll(ids);
    }
    selectedContentIds.refresh();
    update(['employeeWebContent']);
  }

  Future<bool> approveSelectedContents() async {
    final selected = contents
        .where(
          (c) =>
              c.id != null &&
              selectedContentIds.contains(c.id!) &&
              c.status != StorageKeys.status_approved,
        )
        .toList();
    if (selected.isEmpty) return false;
    var ok = true;
    for (final content in selected) {
      final updated = await updateContent(
        content.copyWith(status: StorageKeys.status_approved),
      );
      ok = ok && updated;
    }
    if (ok) {
      clearSelectedContentIds();
      refreshFilteredContents();
    }
    return ok;
  }

  MetaPostModel? buildMetaDraftFromContent(
    ContentModel content, {
    required bool schedule,
    bool asPendingDraft = false,
    bool silent = false,
  }) {
    final linkedClient = clients.firstWhereOrNull(
      (c) => c.id == content.clientId,
    );
    final pageId = (linkedClient?.metaPageId ?? '').trim();
    final pageAccessToken = (linkedClient?.metaPageAccessToken ?? '').trim();
    if (pageId.isEmpty || pageAccessToken.isEmpty) {
      if (!silent) {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.publishClientMetaPageRequired.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
      return null;
    }
    final contentType = content.contentType.toLowerCase();
    final bool isReel = contentType.contains('reel');
    final bool isStory = contentType.contains('story');
    final List<dynamic>? dedicatedRaw = isReel
        ? content.reelAttachments
        : (isStory ? content.storyAttachments : content.postAttachments);
    String? mediaUrl;
    for (final file in (dedicatedRaw ?? []).whereType<String>()) {
      final trimmed = file.trim();
      if (trimmed.isEmpty) continue;
      mediaUrl = trimmed;
      break;
    }
    final String status;
    final DateTime? scheduledAt;
    if (asPendingDraft) {
      status = 'created';
      scheduledAt = content.publishDate?.toUtc();
    } else if (schedule) {
      status = 'scheduled';
      scheduledAt = content.publishDate?.toUtc();
    } else {
      status = 'queued_now';
      scheduledAt = DateTime.now().toUtc();
    }
    return MetaPostModel(
      title: content.title,
      pageId: pageId,
      pageAccessToken: pageAccessToken,
      pageName: linkedClient?.metaPageName,
      instagramUserId: linkedClient?.metaInstagramUserId,
      instagramUserName: linkedClient?.metaInstagramUserName,
      postType: isReel ? 'reel' : (isStory ? 'story' : 'feed'),
      mediaType: mediaUrl == null ? null : publishMediaTypeFromUrl(mediaUrl),
      mediaUrl: mediaUrl,
      caption: content.caption,
      platforms: normalizeMetaPlatformsForFirestore(content.platform),
      status: status,
      clientId: content.clientId,
      contentId: content.id,
      createdBy: currentEmployee.value?.id,
      lang: Get.locale?.languageCode ?? 'ar',
      scheduledAt: scheduledAt,
      createdAt: DateTime.now(),
    );
  }

  MetaPostModel? buildScheduledMetaDraftFromContent(ContentModel content) {
    final publishDate = content.publishDate;
    if (publishDate == null ||
        publishDate.toUtc().isBefore(DateTime.now().toUtc())) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.publishFutureDateRequired.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
    return buildMetaDraftFromContent(content, schedule: true);
  }

  static bool _sameUtcMoment(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.toUtc().millisecondsSinceEpoch == b.toUtc().millisecondsSinceEpoch;
  }

  /// When Content gets a publish date, ensure a Draft Meta publish row exists
  /// so the Publish section can decide queue / schedule / edit next.
  Future<void> ensurePendingMetaPostForContent(ContentModel content) async {
    final contentId = content.id?.trim();
    if (contentId == null || contentId.isEmpty) return;
    if (content.publishDate == null) return;

    const openStatuses = {'created', 'scheduled'};
    final existing = metaPosts.firstWhereOrNull(
      (p) =>
          (p.contentId?.trim() ?? '') == contentId &&
          openStatuses.contains(p.status),
    );

    final draft = buildMetaDraftFromContent(
      content,
      schedule: false,
      asPendingDraft: true,
      silent: true,
    );
    if (draft == null) {
      if (existing == null) {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.publishClientMetaPageRequired.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
      return;
    }

    if (existing != null) {
      await _service.updateMetaPost(
        existing.copyWith(
          title: draft.title,
          pageId: draft.pageId,
          pageAccessToken: draft.pageAccessToken,
          pageName: draft.pageName,
          instagramUserId: draft.instagramUserId,
          instagramUserName: draft.instagramUserName,
          postType: draft.postType,
          mediaType: draft.mediaType,
          mediaUrl: draft.mediaUrl,
          caption: draft.caption,
          platforms: draft.platforms,
          clientId: draft.clientId,
          contentId: contentId,
          lang: draft.lang,
          scheduledAt: draft.scheduledAt,
        ),
      );
      return;
    }

    await _service.addMetaPost(draft.copyWith(contentId: contentId));
  }

  Future<bool> addContent(ContentModel content) async {
    isLoading.value = true;
    final id = await _service.addContent(content);
    isLoading.value = false;
    if (id != null && content.publishDate != null) {
      await ensurePendingMetaPostForContent(content.copyWith(id: id));
    }
    return id != null;
  }

  Future<bool> updateContent(ContentModel content) async {
    final previous = contents.firstWhereOrNull((c) => c.id == content.id);
    isLoading.value = true;
    final result = await _service.updateContent(content);
    isLoading.value = false;
    if (result &&
        content.publishDate != null &&
        !_sameUtcMoment(previous?.publishDate, content.publishDate)) {
      await ensurePendingMetaPostForContent(content);
    }
    return result;
  }

  Future<bool> deleteSelectedContents() async {
    final ids = selectedContentIds.toList();
    if (ids.isEmpty) return false;
    var allOk = true;
    for (final id in ids) {
      final deleted = await deleteContent(id);
      allOk = allOk && deleted;
      if (deleted) {
        selectedContentIds.remove(id);
      }
    }
    selectedContentIds.refresh();
    update(['employeeWebContent']);
    return allOk;
  }

  List<ContentModel> filteredContentsForEmployeeWeb() {
    var list = searchedContents.toList();
    final q = employeeWebContentSearchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) => c.title.toLowerCase().contains(q)).toList();
    }
    final ct = employeeWebContentTypeFilters.toList();
    if (ct.isNotEmpty) {
      final set = ct.toSet();
      list = list.where((c) => set.contains(c.contentType)).toList();
    }
    final st = employeeWebContentStatusFilters.toList();
    if (st.isNotEmpty) {
      final set = st.toSet();
      list = list.where((c) => set.contains(c.status)).toList();
    }
    final filterDate = employeeWebContentDateFilter.value;
    if (filterDate != null) {
      list = list.where((c) {
        final d = c.publishDate;
        if (d == null) return false;
        return d.year == filterDate.year &&
            d.month == filterDate.month &&
            d.day == filterDate.day;
      }).toList();
    }
    return list;
  }

  void refreshFilteredContents({String? clientId, bool onlyUpcoming = false}) {
    final selectedClientId = (clientId ?? clientController.text).trim();
    if (selectedClientId.isEmpty) {
      searchedContents.clear();
      clearEmployeeWebContentFilters();
      return;
    }

    final now = DateTime.now();
    searchedContents.assignAll(
      contents.where((content) {
        if (content.clientId != selectedClientId) return false;
        if (!onlyUpcoming) return true;
        final publishDate = content.publishDate;
        if (publishDate == null) return false;
        return publishDate.year > now.year ||
            (publishDate.year == now.year && publishDate.month >= now.month);
      }).toList(),
    );
    update(['employeeWebContent']);
  }

  fetchNotification(String? id) {
    final uid = id?.trim();
    if (FirebaseAuth.instance.currentUser == null ||
        uid == null ||
        uid.isEmpty) {
      notifications.bindStream(Stream<List<NotificationModel>>.value([]));
      return;
    }
    notifications.bindStream(
      _service.getNotifications(uid, 'all').handleError((
        Object e,
        StackTrace st,
      ) {
        // تسجيل خروج أو انتهاء الجلسة: قد يُرفض الاستعلام — لا نُعيد رمي الخطأ (RethrownDartError).
        appLog('⚠️ notifications stream: $e');
      }),
    );
  }

  Future<bool> updateContentPromotionField(
    String contentId,
    String promotion,
  ) async {
    isLoading.value = true;
    final result = await _service.updateContentPromotionField(
      contentId,
      promotion,
    );
    isLoading.value = false;
    return result;
  }

  Future<bool> deleteContent(String id) async {
    isLoading.value = true;
    final result = await _service.deleteContent(id);
    isLoading.value = false;
    if (result) {
      contents.removeWhere((c) => c.id == id);
      searchedContents.removeWhere((c) => c.id == id);
      refreshFilteredContents();
    }
    return result;
  }

  Future<bool> addMetaPost(MetaPostModel post) async {
    isLoading.value = true;
    try {
      return await _service.addMetaPost(post);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateMetaPost(MetaPostModel post) async {
    isLoading.value = true;
    try {
      return await _service.updateMetaPost(post);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteMetaPost(String id) async {
    isLoading.value = true;
    try {
      return await _service.deleteMetaPost(id);
    } finally {
      isLoading.value = false;
    }
  }

  /// Queue a saved [MetaPostModel] row for bot-worker publishing.
  /// No direct Meta Graph call from Flutter.
  Future<bool> publishMetaPost(String id) async {
    final post = metaPosts.firstWhereOrNull((p) => p.id == id);
    if (post == null) return false;
    final nowUtc = DateTime.now().toUtc();
    final queued = post.copyWith(
      status: 'queued_now',
      scheduledAt: nowUtc,
      lastError: null,
      metaResponse: null,
      lang: Get.locale?.languageCode ?? post.lang ?? 'ar',
    );
    final ok = await updateMetaPost(queued);
    if (ok) {
      FunHelper.showSnackbar(
        'common.save'.tr,
        'publish.queued_now'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      FunHelper.showSnackbar(
        'error'.tr,
        'publish.queue_failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    return ok;
  }

  void fetchTasks() {
    _rebindClientsAndTasksStreams();
  }

  void fetchProgrammingUpdates() {
    final emp = currentEmployee.value ?? lastKnownEmployee.value;
    if (emp == null) {
      programmingUpdates.bindStream(
        Stream<List<ProgrammingUpdateModel>>.value(const []),
      );
      return;
    }
    final role = emp.role.trim().toLowerCase();
    final isManager = role == 'admin' || role == 'supervisor';
    final isProgramming = emp.hasDepartment(StorageKeys.departmentProgramming);
    if (isManager || isProgramming) {
      programmingUpdates.bindStream(_service.getProgrammingUpdatesStream());
    } else {
      programmingUpdates.bindStream(
        Stream<List<ProgrammingUpdateModel>>.value(const []),
      );
    }
  }

  Future<bool> addProgrammingUpdate(ProgrammingUpdateModel update) async {
    isLoading.value = true;
    final emp = currentEmployee.value;
    final withMeta = update.copyWith(
      createdBy: emp?.id ?? '',
      status: StorageKeys.programmingUpdateStatusPending,
    );
    final id = await _service.addProgrammingUpdate(withMeta);
    isLoading.value = false;
    return id != null;
  }

  Future<bool> updateProgrammingUpdate(ProgrammingUpdateModel update) async {
    isLoading.value = true;
    final result = await _service.updateProgrammingUpdate(update);
    isLoading.value = false;
    return result;
  }

  Future<bool> deleteProgrammingUpdate(String id) async {
    isLoading.value = true;
    final result = await _service.deleteProgrammingUpdate(id);
    isLoading.value = false;
    return result;
  }

  Future<bool> markProgrammingUpdatesConverted(
    List<String> updateIds,
    String taskId,
  ) async {
    return _service.markProgrammingUpdatesConverted(updateIds, taskId);
  }

  /// بعد دفع صامت أو استئناف التطبيق — إعادة ربط تدفقات البيانات.
  void refreshAfterSilentPush() {
    fetchClients();
    fetchTasks();
    fetchContents();
    fetchMetaPosts();
  }

  Future<bool> addTask(TaskModel task) async {
    isLoading.value = true;
    final emp = currentEmployee.value;
    final createdEvent = TaskTimelineEvent(
      type: 'created',
      label: 'تم إنشاء المهمة',
      byUserId: emp?.id ?? '',
      byUserName: emp?.name ?? 'system.user',
      timestamp: DateTime.now(),
    );
    final taskWithTimeline = task.copyWith(timelineEvents: [createdEvent]);
    final newId = await _service.addTask(taskWithTimeline);
    final result = newId != null;
    if (result && task.sourceUpdateIds.isNotEmpty && newId.isNotEmpty) {
      unawaited(
        markProgrammingUpdatesConverted(task.sourceUpdateIds, newId),
      );
    }
    isLoading.value = false;
    if (result && task.assignedTo.trim().isNotEmpty) {
      final ctx = _taskEmailContext(task);
      unawaited(
        NotificationService.notifyEmployeeAssignedToTask(
          employeeId: task.assignedTo,
          taskTitle: task.title,
          taskContext: ctx,
        ),
      );
      unawaited(
        NotificationService.notifyManagersNewTaskInDepartment(
          taskTitle: task.title,
          departmentNameAr: NotificationService.departmentNameFromTaskType(
            task.type,
          ),
          dueDate: ctx.dueDate,
          clientName: ctx.clientName,
        ),
      );
    }
    return result;
  }

  Future<bool> updateTask(TaskModel task) async {
    isLoading.value = true;
    final oldTask = tasks.firstWhereOrNull((t) => t.id == task.id);
    TaskModel taskToSave = task;
    if (oldTask != null) {
      final newEvents = _buildTimelineEvents(oldTask, task);
      // دمج أحداث التايم لاين دائماً للحفاظ عليها (حتى لو لم يُضف حدث جديد،
      // لأن النموذج قد يرسل مهمة جديدة بدون timelineEvents فيُمسح الجدول)
      final merged = [...oldTask.timelineEvents, ...newEvents];
      taskToSave = task.copyWith(timelineEvents: merged);
    }
    final result = await _service.updateTask(taskToSave);
    isLoading.value = false;
    if (!result) {
      FunHelper.showSnackbar(
        'error'.tr,
        'errors.forbidden'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    if (result && oldTask != null) {
      unawaited(_triggerTaskNotifications(oldTask, taskToSave));
    }
    return result;
  }

  TaskEmailContext _taskEmailContext(
    TaskModel task, {
    String? actorName,
    String? commentPreview,
    int? attachmentCount,
    String? newDueDate,
    String? newStatus,
    String? commenterName,
  }) {
    final priority = task.priority.trim();
    final client = task.clientName.trim();
    return TaskEmailContext(
      taskTitle: task.title,
      department: NotificationService.departmentNameFromTaskType(task.type),
      dueDate: FunHelper.formatdate(task.toDate),
      startDate: FunHelper.formatdate(task.fromDate),
      priority: priority.isEmpty ? null : priority,
      clientName: client.isEmpty ? null : client,
      editMessage: task.managementEditRequestMessage.trim().isEmpty
          ? null
          : task.managementEditRequestMessage,
      requestedBy: actorName,
      rejectionReason: task.rejectionMessage.trim().isEmpty
          ? null
          : task.rejectionMessage,
      rejectedBy: actorName,
      commentPreview: commentPreview,
      extensionReason: task.deadlineExtensionReason.trim().isEmpty
          ? null
          : task.deadlineExtensionReason,
      newDueDate: newDueDate ?? FunHelper.formatdate(task.deadlineExtensionRequestedTo),
      denialNote: task.deadlineExtensionDeniedNote.trim().isEmpty
          ? null
          : task.deadlineExtensionDeniedNote,
      attachmentCount: attachmentCount,
      addedBy: actorName,
      changedBy: actorName,
      newStatus: newStatus,
      commenterName: commenterName,
    );
  }

  String? _latestNoteText(TaskModel task) {
    if (task.notes.isEmpty) return null;
    final last = task.notes.last;
    final t = last.note.trim();
    if (t.isNotEmpty) return t;
    if (last.hasVoice) return 'tasks.form.voice_record'.tr;
    return null;
  }

  Future<void> _triggerTaskNotifications(
    TaskModel oldTask,
    TaskModel newTask,
  ) async {
    final emp = currentEmployee.value;
    final assigneeId = newTask.assignedTo.trim();
    final assigneeName =
        employees.firstWhereOrNull((e) => e.id == assigneeId)?.name ??
        assigneeId;
    final isUpdateByAssignee = emp?.id == assigneeId;

    final actorName = (emp?.name ?? '').trim().isEmpty
        ? null
        : (emp?.name ?? '').trim();

    if (oldTask.status != newTask.status) {
      if (assigneeId.isNotEmpty) {
        await NotificationService.notifyEmployeeTaskStatusChanged(
          employeeId: assigneeId,
          taskTitle: newTask.title,
          newStatus: newTask.status,
          changedBy: actorName ?? '',
          taskContext: _taskEmailContext(
            newTask,
            actorName: actorName,
            newStatus: NotificationService.statusLabelAr(newTask.status),
          ),
        );
      }
      if (isUpdateByAssignee) {
        if (newTask.status == StorageKeys.status_processing ||
            newTask.status == StorageKeys.status_promotion_in_progress) {
          await NotificationService.notifyManagersTaskReceivedByEmployee(
            employeeName: assigneeName,
            taskTitle: newTask.title,
            taskContext: _taskEmailContext(newTask, actorName: assigneeName),
          );
        } else if (newTask.status == StorageKeys.status_ready_to_publish ||
            newTask.status == StorageKeys.status_under_revision ||
            newTask.status == StorageKeys.status_promotion_ad_platform_review ||
            newTask.status == StorageKeys.status_task_completed) {
          await NotificationService.notifyManagersTaskCompletedByEmployee(
            employeeName: assigneeName,
            taskTitle: newTask.title,
            taskContext: _taskEmailContext(newTask, actorName: assigneeName),
          );
        }
      }
      if (newTask.status == StorageKeys.status_rejected &&
          assigneeId.isNotEmpty) {
        await NotificationService.notifyEmployeeTaskRejected(
          employeeId: assigneeId,
          taskTitle: newTask.title,
          taskContext: _taskEmailContext(newTask, actorName: actorName),
        );
      }
      if (assigneeId.isNotEmpty &&
          (newTask.status == StorageKeys.status_edit_requested ||
              (newTask.type == '0' &&
                  oldTask.status ==
                      StorageKeys.status_promotion_ad_platform_review &&
                  newTask.status ==
                      StorageKeys.status_promotion_in_progress))) {
        await NotificationService.notifyEmployeeEditRequestedByManagement(
          employeeId: assigneeId,
          taskTitle: newTask.title,
          taskContext: _taskEmailContext(newTask, actorName: actorName),
        );
      }
      if (oldTask.status != newTask.status &&
          newTask.status == StorageKeys.status_awaiting_manager &&
          emp?.role == 'supervisor') {
        final sn = (emp?.name ?? '').trim();
        await NotificationService.notifyAdminsSupervisorEscalatedTask(
          supervisorName: sn.isEmpty ? 'notify.unknown_actor'.tr : sn,
          taskTitle: newTask.title,
          taskContext: _taskEmailContext(newTask),
        );
      }
      final wasEnded = StorageKeys.isTaskEnded(oldTask);
      final isNowOngoing = StorageKeys.isTaskOngoing(newTask);
      if (wasEnded && isNowOngoing && assigneeId.isNotEmpty) {
        await NotificationService.notifyEmployeeTaskReopened(
          employeeId: assigneeId,
          taskTitle: newTask.title,
          taskContext: _taskEmailContext(newTask),
        );
      }
    }

    if (newTask.files.length > oldTask.files.length && assigneeId.isNotEmpty) {
      await NotificationService.notifyEmployeeNewAttachments(
        employeeId: assigneeId,
        taskTitle: newTask.title,
        taskContext: _taskEmailContext(
          newTask,
          actorName: actorName,
          attachmentCount: newTask.files.length - oldTask.files.length,
        ),
      );
    }

    if (isUpdateByAssignee &&
        oldTask.status == newTask.status &&
        (newTask.notes.length > oldTask.notes.length ||
            newTask.files.length > oldTask.files.length)) {
      final addedNotes = newTask.notes.length > oldTask.notes.length;
      final addedFiles = newTask.files.length > oldTask.files.length;
      final editKind = addedNotes && addedFiles
          ? ManagerTaskEditKind.both
          : addedNotes
          ? ManagerTaskEditKind.comment
          : ManagerTaskEditKind.attachment;
      await NotificationService.notifyManagersEmployeeEditedTask(
        employeeName: assigneeName,
        taskTitle: newTask.title,
        kind: editKind,
        taskContext: _taskEmailContext(newTask, actorName: assigneeName),
        commentPreview: addedNotes ? _latestNoteText(newTask) : null,
      );
    }

    if (!isUpdateByAssignee &&
        assigneeId.isNotEmpty &&
        oldTask.status == newTask.status &&
        newTask.notes.length > oldTask.notes.length) {
      final rawName = (emp?.name ?? '').trim();
      final commenterName = rawName.isNotEmpty
          ? rawName
          : 'notify.unknown_actor'.tr;
      await NotificationService.notifyEmployeeTaskNewComment(
        employeeId: assigneeId,
        commenterName: commenterName,
        taskTitle: newTask.title,
        taskContext: _taskEmailContext(
          newTask,
          commenterName: commenterName,
          commentPreview: _latestNoteText(newTask),
        ),
      );
    }

    if (isUpdateByAssignee && assigneeId.isNotEmpty) {
      final oldNorm = _normalizeProgressStep(oldTask.progress);
      final newNorm = _normalizeProgressStep(newTask.progress);
      if (oldNorm != newNorm) {
        await NotificationService.notifyManagersTaskProgressUpdated(
          employeeName: assigneeName,
          taskTitle: newTask.title,
          progressPercent: ((newNorm ?? 0) * 100).round(),
        );
      }
    }

    final oldDe = oldTask.deadlineExtensionStatus.trim();
    final newDe = newTask.deadlineExtensionStatus.trim();
    if (oldDe != TaskModel.kDeadlineExtensionPending &&
        newDe == TaskModel.kDeadlineExtensionPending) {
      await NotificationService.notifyManagersDeadlineExtensionRequested(
        employeeName: assigneeName,
        taskTitle: newTask.title,
        taskContext: _taskEmailContext(newTask, actorName: assigneeName),
      );
    }
    if (oldDe == TaskModel.kDeadlineExtensionPending &&
        newDe.isEmpty &&
        newTask.toDate != oldTask.toDate &&
        assigneeId.isNotEmpty) {
      final fmt = FunHelper.formatdate(newTask.toDate);
      await NotificationService.notifyEmployeeDeadlineExtensionApproved(
        employeeId: assigneeId,
        taskTitle: newTask.title,
        newDueLabel: fmt ?? newTask.toDate.toIso8601String(),
        taskContext: _taskEmailContext(
          newTask,
          newDueDate: fmt,
        ),
      );
    }
    if (oldDe == TaskModel.kDeadlineExtensionPending &&
        newDe == TaskModel.kDeadlineExtensionDenied &&
        assigneeId.isNotEmpty) {
      await NotificationService.notifyEmployeeDeadlineExtensionDenied(
        employeeId: assigneeId,
        taskTitle: newTask.title,
        taskContext: _taskEmailContext(newTask),
      );
    }
  }

  static const int _timelineValueMaxLength = 80;

  String _formatTimelineValue(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return FunHelper.formatdate(value) ?? value.toIso8601String();
    }
    if (value is num) return value.toString();
    if (value is List) {
      final parts = value.map((e) => _formatTimelineValue(e)).toList();
      final s = parts.join('، ');
      return s.length > _timelineValueMaxLength
          ? '${s.substring(0, _timelineValueMaxLength)}...'
          : s;
    }
    final s = value.toString();
    return s.length > _timelineValueMaxLength
        ? '${s.substring(0, _timelineValueMaxLength)}...'
        : s;
  }

  bool _valuesEqual(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a is DateTime && b is DateTime) return a.isAtSameMomentAs(b);
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_valuesEqual(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  double? _normalizeProgressStep(double? value) {
    if (value == null) return null;
    const int stepsCount = 5; // 0, 25, 50, 75, 100
    const int segments = stepsCount - 1;
    const double stepSize = 1 / segments;
    final snapped = (value.clamp(0.0, 1.0) / stepSize).round() * stepSize;
    return snapped.clamp(0.0, 1.0);
  }

  void _addIfChanged(
    List<TaskTimelineEvent> events,
    String label,
    dynamic oldVal,
    dynamic newVal,
    String userId,
    String userName,
    DateTime now, {
    String? fieldKey,
  }) {
    if (_valuesEqual(oldVal, newVal)) return;
    events.add(
      TaskTimelineEvent(
        type: 'field_changed',
        label: label,
        oldValue: _formatTimelineValue(oldVal).isEmpty
            ? null
            : _formatTimelineValue(oldVal),
        newValue: _formatTimelineValue(newVal).isEmpty
            ? null
            : _formatTimelineValue(newVal),
        byUserId: userId,
        byUserName: userName,
        timestamp: now,
        fieldKey: fieldKey,
      ),
    );
  }

  List<TaskTimelineEvent> _buildTimelineEvents(
    TaskModel oldTask,
    TaskModel newTask,
  ) {
    final emp = currentEmployee.value;
    final userId = emp?.id ?? '';
    final userName = emp?.name ?? 'system.user';
    final baseNow = DateTime.now();
    var tsSeq = 0;
    DateTime ts() => baseNow.add(Duration(microseconds: ++tsSeq));
    final List<TaskTimelineEvent> events = [];

    // --- الحقول الأساسية للمهمة ---
    if (oldTask.assignedTo != newTask.assignedTo) {
      final oldName =
          employees.firstWhereOrNull((e) => e.id == oldTask.assignedTo)?.name ??
          oldTask.assignedTo;
      final newName =
          employees.firstWhereOrNull((e) => e.id == newTask.assignedTo)?.name ??
          newTask.assignedTo;
      events.add(
        TaskTimelineEvent(
          type: 'executor_changed',
          label: 'تم تغيير المنفذ',
          oldValue: oldName,
          newValue: newName,
          byUserId: userId,
          byUserName: userName,
          timestamp: ts(),
        ),
      );
    }
    _addIfChanged(
      events,
      'تم تغيير العنوان',
      oldTask.title,
      newTask.title,
      userId,
      userName,
      ts(),
      fieldKey: 'title',
    );
    _addIfChanged(
      events,
      'تم تغيير الوصف',
      oldTask.description,
      newTask.description,
      userId,
      userName,
      ts(),
      fieldKey: 'description',
    );
    final normalizedOldProgress = _normalizeProgressStep(oldTask.progress);
    final normalizedNewProgress = _normalizeProgressStep(newTask.progress);
    if (normalizedOldProgress != normalizedNewProgress) {
      final oldP = normalizedOldProgress != null
          ? '${(normalizedOldProgress * 100).round()}%'
          : '';
      final newP = normalizedNewProgress != null
          ? '${(normalizedNewProgress * 100).round()}%'
          : '';
      _addIfChanged(
        events,
        'تم تغيير التقدم',
        oldP,
        newP,
        userId,
        userName,
        ts(),
        fieldKey: 'progress',
      );
    }
    _addIfChanged(
      events,
      'تم تغيير اسم العميل',
      oldTask.clientName,
      newTask.clientName,
      userId,
      userName,
      ts(),
      fieldKey: 'clientName',
    );
    _addIfChanged(
      events,
      'تم تغيير نص الإجراء',
      oldTask.actionText,
      newTask.actionText,
      userId,
      userName,
      ts(),
      fieldKey: 'actionText',
    );
    _addIfChanged(
      events,
      'تم تغيير النوع',
      oldTask.type,
      newTask.type,
      userId,
      userName,
      ts(),
      fieldKey: 'type',
    );
    if (oldTask.fromDate != newTask.fromDate) {
      events.add(
        TaskTimelineEvent(
          type: 'from_date_changed',
          label: 'تم تغيير تاريخ البداية',
          oldValue: _formatTimelineValue(oldTask.fromDate),
          newValue: _formatTimelineValue(newTask.fromDate),
          byUserId: userId,
          byUserName: userName,
          timestamp: ts(),
        ),
      );
    }
    if (oldTask.toDate != newTask.toDate) {
      events.add(
        TaskTimelineEvent(
          type: 'to_date_changed',
          label: 'تم تغيير تاريخ النهاية',
          oldValue: _formatTimelineValue(oldTask.toDate),
          newValue: _formatTimelineValue(newTask.toDate),
          byUserId: userId,
          byUserName: userName,
          timestamp: ts(),
        ),
      );
    }
    if (oldTask.priority != newTask.priority) {
      events.add(
        TaskTimelineEvent(
          type: 'priority_changed',
          label: 'تم تغيير الأولوية',
          oldValue: oldTask.priority,
          newValue: newTask.priority,
          byUserId: userId,
          byUserName: userName,
          timestamp: ts(),
        ),
      );
    }
    if (oldTask.status != newTask.status) {
      events.add(
        TaskTimelineEvent(
          type: 'status_changed',
          label: 'تم تغيير الحالة',
          oldValue: oldTask.status,
          newValue: newTask.status,
          byUserId: userId,
          byUserName: userName,
          timestamp: ts(),
        ),
      );
    }
    if (newTask.notes.length > oldTask.notes.length) {
      final addedNote = newTask.notes.isNotEmpty ? newTask.notes.last : null;
      final noteText = addedNote?.note.trim() ?? '';
      final snippet = noteText.length > _timelineValueMaxLength
          ? '${noteText.substring(0, _timelineValueMaxLength)}...'
          : noteText;
      final voices = addedNote?.voiceRecords
              .where((e) => e.url.trim().isNotEmpty)
              .toList() ??
          const [];
      events.add(
        TaskTimelineEvent(
          type: 'note_added',
          label: 'timeline.comment_added',
          // Keep text snippet only; voice is rendered via [voiceRecords].
          newValue: snippet.isEmpty ? null : snippet,
          voiceRecords: voices,
          byUserId: userId,
          byUserName: userName,
          timestamp: ts(),
        ),
      );
    }
    if (newTask.files.length > oldTask.files.length) {
      final oldCounter = <String, int>{};
      for (final f in oldTask.files) {
        final key = f.toString();
        oldCounter[key] = (oldCounter[key] ?? 0) + 1;
      }
      final addedFiles = <String>[];
      for (final f in newTask.files) {
        final key = f.toString();
        final remaining = oldCounter[key] ?? 0;
        if (remaining > 0) {
          oldCounter[key] = remaining - 1;
        } else {
          addedFiles.add(key);
        }
      }
      for (final file in addedFiles) {
        events.add(
          TaskTimelineEvent(
            type: 'attachment_added',
            label: 'تم إضافة مرفق',
            newValue: file.isEmpty ? null : file,
            byUserId: userId,
            byUserName: userName,
            timestamp: ts(),
          ),
        );
      }
    }

    _addIfChanged(
      events,
      'tasks.timeline_final_deliverable_text_updated',
      oldTask.finalDeliverableText,
      newTask.finalDeliverableText,
      userId,
      userName,
      ts(),
      fieldKey: 'finalDeliverableText',
    );

    if (newTask.finalDeliverableFileUrls.length >
        oldTask.finalDeliverableFileUrls.length) {
      final oldCounter = <String, int>{};
      for (final f in oldTask.finalDeliverableFileUrls) {
        final key = f.toString();
        oldCounter[key] = (oldCounter[key] ?? 0) + 1;
      }
      final addedFiles = <String>[];
      for (final f in newTask.finalDeliverableFileUrls) {
        final key = f.toString();
        final remaining = oldCounter[key] ?? 0;
        if (remaining > 0) {
          oldCounter[key] = remaining - 1;
        } else {
          addedFiles.add(key);
        }
      }
      for (final file in addedFiles) {
        events.add(
          TaskTimelineEvent(
            type: 'final_deliverable_attachment_added',
            label: 'tasks.timeline_final_deliverable_file_added',
            newValue: file.isEmpty ? null : file,
            byUserId: userId,
            byUserName: userName,
            timestamp: ts(),
          ),
        );
      }
    }

    // --- DesignTaskModel ---
    final oldD = oldTask.designDetails;
    final newD = newTask.designDetails;
    if (oldD != null || newD != null) {
      _addIfChanged(
        events,
        'تم تغيير نوع المهمة (التصميم)',
        oldD?.taskType,
        newD?.taskType,
        userId,
        userName,
        ts(),
        fieldKey: 'designDetails.taskType',
      );
      _addIfChanged(
        events,
        'تم تغيير المنصة (التصميم)',
        oldD?.platform,
        newD?.platform,
        userId,
        userName,
        ts(),
        fieldKey: 'designDetails.platform',
      );
      _addIfChanged(
        events,
        'تم تغيير نوع التصميم',
        oldD?.designType,
        newD?.designType,
        userId,
        userName,
        ts(),
        fieldKey: 'designDetails.designType',
      );
      _addIfChanged(
        events,
        'تم تغيير عدد التصاميم (التصميم)',
        oldD?.designCount,
        newD?.designCount,
        userId,
        userName,
        ts(),
        fieldKey: 'designDetails.designCount',
      );
      _addIfChanged(
        events,
        'تم تغيير القياسات (التصميم)',
        oldD?.designsDimensions,
        newD?.designsDimensions,
        userId,
        userName,
        ts(),
        fieldKey: 'designDetails.designsDimensions',
      );
    }

    // --- ContentWriteModel ---
    final oldCw = oldTask.contentWriteModel;
    final newCw = newTask.contentWriteModel;
    if (oldCw != null || newCw != null) {
      _addIfChanged(
        events,
        'تم تغيير المنصة (المحتوى)',
        oldCw?.platform,
        newCw?.platform,
        userId,
        userName,
        ts(),
        fieldKey: 'contentWriteModel.platform',
      );
      _addIfChanged(
        events,
        'تم تغيير نوع المحتوى',
        oldCw?.contenttype,
        newCw?.contenttype,
        userId,
        userName,
        ts(),
        fieldKey: 'contentWriteModel.contenttype',
      );
      _addIfChanged(
        events,
        'تم تغيير عدد التصاميم (المحتوى)',
        oldCw?.designCount,
        newCw?.designCount,
        userId,
        userName,
        ts(),
        fieldKey: 'contentWriteModel.designCount',
      );
      _addIfChanged(
        events,
        'تم تغيير القياسات (المحتوى)',
        oldCw?.designsDimensions,
        newCw?.designsDimensions,
        userId,
        userName,
        ts(),
        fieldKey: 'contentWriteModel.designsDimensions',
      );
    }

    // --- PhotographyModel ---
    final oldPh = oldTask.photoGrapghyModel;
    final newPh = newTask.photoGrapghyModel;
    if (oldPh != null || newPh != null) {
      _addIfChanged(
        events,
        'تم تغيير نوع التصوير',
        oldPh?.shootingtype,
        newPh?.shootingtype,
        userId,
        userName,
        ts(),
        fieldKey: 'photoGrapghyModel.shootingtype',
      );
      _addIfChanged(
        events,
        'تم تغيير المنصة (التصوير)',
        oldPh?.platform,
        newPh?.platform,
        userId,
        userName,
        ts(),
        fieldKey: 'photoGrapghyModel.platform',
      );
      _addIfChanged(
        events,
        'تم تغيير موقع التصوير',
        oldPh?.shootinglocation,
        newPh?.shootinglocation,
        userId,
        userName,
        ts(),
        fieldKey: 'photoGrapghyModel.shootinglocation',
      );
      _addIfChanged(
        events,
        'تم تغيير عدد التصاميم (التصوير)',
        oldPh?.designCount,
        newPh?.designCount,
        userId,
        userName,
        ts(),
        fieldKey: 'photoGrapghyModel.designCount',
      );
      _addIfChanged(
        events,
        'تم تغيير المدة (التصوير)',
        oldPh?.duration,
        newPh?.duration,
        userId,
        userName,
        ts(),
        fieldKey: 'photoGrapghyModel.duration',
      );
    }

    // --- MonatageModel ---
    final oldMo = oldTask.monatageModel;
    final newMo = newTask.monatageModel;
    if (oldMo != null || newMo != null) {
      _addIfChanged(
        events,
        'تم تغيير التصنيف (المونتاج)',
        oldMo?.category,
        newMo?.category,
        userId,
        userName,
        ts(),
        fieldKey: 'monatageModel.category',
      );
      _addIfChanged(
        events,
        'تم تغيير المنصة (المونتاج)',
        oldMo?.platform,
        newMo?.platform,
        userId,
        userName,
        ts(),
        fieldKey: 'monatageModel.platform',
      );
      _addIfChanged(
        events,
        'تم تغيير الأبعاد (المونتاج)',
        oldMo?.dimentioans,
        newMo?.dimentioans,
        userId,
        userName,
        ts(),
        fieldKey: 'monatageModel.dimentioans',
      );
      _addIfChanged(
        events,
        'تم تغيير رابط المرفق (المونتاج)',
        oldMo?.attachementurl,
        newMo?.attachementurl,
        userId,
        userName,
        ts(),
        fieldKey: 'monatageModel.attachementurl',
      );
      _addIfChanged(
        events,
        'تم تغيير المدة (المونتاج)',
        oldMo?.duration,
        newMo?.duration,
        userId,
        userName,
        ts(),
        fieldKey: 'monatageModel.duration',
      );
    }

    // --- PublishModel ---
    final oldPu = oldTask.publishModel;
    final newPu = newTask.publishModel;
    if (oldPu != null || newPu != null) {
      _addIfChanged(
        events,
        'تم تغيير رابط المحتوى (النشر)',
        oldPu?.contenturl,
        newPu?.contenturl,
        userId,
        userName,
        ts(),
        fieldKey: 'publishModel.contenturl',
      );
      _addIfChanged(
        events,
        'تم تغيير المنصة (النشر)',
        oldPu?.platform,
        newPu?.platform,
        userId,
        userName,
        ts(),
        fieldKey: 'publishModel.platform',
      );
      _addIfChanged(
        events,
        'تم تغيير التصنيف (النشر)',
        oldPu?.category,
        newPu?.category,
        userId,
        userName,
        ts(),
        fieldKey: 'publishModel.category',
      );
      _addIfChanged(
        events,
        'تم تغيير رابط الملف (النشر)',
        oldPu?.fileurl,
        newPu?.fileurl,
        userId,
        userName,
        ts(),
        fieldKey: 'publishModel.fileurl',
      );
      _addIfChanged(
        events,
        'تم تغيير القياسات (النشر)',
        oldPu?.designsDimensions,
        newPu?.designsDimensions,
        userId,
        userName,
        ts(),
        fieldKey: 'publishModel.designsDimensions',
      );
    }

    // --- ProgrammingModel ---
    final oldPr = oldTask.programmingModel;
    final newPr = newTask.programmingModel;
    if (oldPr != null || newPr != null) {
      _addIfChanged(
        events,
        'تم تغيير رابط المحتوى (البرمجة)',
        oldPr?.contenturl,
        newPr?.contenturl,
        userId,
        userName,
        ts(),
        fieldKey: 'programmingModel.contenturl',
      );
      _addIfChanged(
        events,
        'تم تغيير التصنيف (البرمجة)',
        oldPr?.category,
        newPr?.category,
        userId,
        userName,
        ts(),
        fieldKey: 'programmingModel.category',
      );
      _addIfChanged(
        events,
        'تم تغيير رابط الملف (البرمجة)',
        oldPr?.fileurl,
        newPr?.fileurl,
        userId,
        userName,
        ts(),
        fieldKey: 'programmingModel.fileurl',
      );
      _addIfChanged(
        events,
        'تم تغيير القياسات (البرمجة)',
        oldPr?.designsDimensions,
        newPr?.designsDimensions,
        userId,
        userName,
        ts(),
        fieldKey: 'programmingModel.designsDimensions',
      );
      _addIfChanged(
        events,
        'تم تغيير وصف المهمة (البرمجة)',
        oldPr?.aboutTask,
        newPr?.aboutTask,
        userId,
        userName,
        ts(),
        fieldKey: 'programmingModel.aboutTask',
      );
    }

    // --- AdministrationTaskModel ---
    final oldAd = oldTask.administrationModel;
    final newAd = newTask.administrationModel;
    if (oldAd != null || newAd != null) {
      _addIfChanged(
        events,
        'تم تغيير الحقول الإضافية (الإداري)',
        jsonEncode(oldAd?.extra ?? {}),
        jsonEncode(newAd?.extra ?? {}),
        userId,
        userName,
        ts(),
        fieldKey: 'administrationDetails.extra',
      );
    }

    // --- PromotionModel (كل الحقول) ---
    final oldPromo = oldTask.promotionModel;
    final newPromo = newTask.promotionModel;
    if (oldPromo != null || newPromo != null) {
      _addIfChanged(
        events,
        'تم تغيير الاسم (الترويج)',
        oldPromo?.name,
        newPromo?.name,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.name',
      );
      _addIfChanged(
        events,
        'تم تغيير الهدف (الترويج)',
        oldPromo?.target,
        newPromo?.target,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.target',
      );
      _addIfChanged(
        events,
        'تم تغيير اسم الحملة',
        oldPromo?.campaignName,
        newPromo?.campaignName,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.campaignName',
      );
      _addIfChanged(
        events,
        'تم تغيير النوع (الترويج)',
        oldPromo?.type,
        newPromo?.type,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.type',
      );
      _addIfChanged(
        events,
        'تم تغيير الأولوية (الترويج)',
        oldPromo?.priority,
        newPromo?.priority,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.priority',
      );
      _addIfChanged(
        events,
        'تم تغيير الحالة (الترويج)',
        oldPromo?.status,
        newPromo?.status,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.status',
      );
      _addIfChanged(
        events,
        'تم تغيير الوصف (الترويج)',
        oldPromo?.description,
        newPromo?.description,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.description',
      );
      _addIfChanged(
        events,
        'تم تغيير المنفذ (الترويج)',
        oldPromo?.executorId,
        newPromo?.executorId,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.executorId',
      );
      _addIfChanged(
        events,
        'تم تغيير تاريخ البداية (الترويج)',
        oldPromo?.startDate,
        newPromo?.startDate,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.startDate',
      );
      _addIfChanged(
        events,
        'تم تغيير تاريخ النهاية (الترويج)',
        oldPromo?.endDate,
        newPromo?.endDate,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.endDate',
      );
      _addIfChanged(
        events,
        'تم تغيير المدة (الترويج)',
        oldPromo?.duration,
        newPromo?.duration,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.duration',
      );
      _addIfChanged(
        events,
        'tasks.timeline.promotion_campaign_budget_changed',
        oldPromo?.campaignBudget,
        newPromo?.campaignBudget,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.campaignBudget',
      );
      _addIfChanged(
        events,
        'تم تغيير العلامات (الترويج)',
        oldPromo?.tags,
        newPromo?.tags,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.tags',
      );
      _addIfChanged(
        events,
        'تم تغيير المنصات (الترويج)',
        oldPromo?.platforms,
        newPromo?.platforms,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.platforms',
      );
      _addIfChanged(
        events,
        'تم تغيير الاهتمامات',
        oldPromo?.interests,
        newPromo?.interests,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.interests',
      );
      _addIfChanged(
        events,
        'تم تغيير المدن',
        oldPromo?.cities,
        newPromo?.cities,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.cities',
      );
      _addIfChanged(
        events,
        'تم تغيير الدول',
        oldPromo?.countries,
        newPromo?.countries,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.countries',
      );
      _addIfChanged(
        events,
        'تم تغيير التخصصات',
        oldPromo?.specializations,
        newPromo?.specializations,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.specializations',
      );
      _addIfChanged(
        events,
        'تم تغيير الفئات العمرية',
        oldPromo?.ageRanges,
        newPromo?.ageRanges,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.ageRanges',
      );
      _addIfChanged(
        events,
        'تم تغيير الملاحظات (الترويج)',
        oldPromo?.notes,
        newPromo?.notes,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.notes',
      );
      _addIfChanged(
        events,
        'تم تغيير رابط المرفق (الترويج)',
        oldPromo?.attachementurl,
        newPromo?.attachementurl,
        userId,
        userName,
        ts(),
        fieldKey: 'promotionModel.attachementurl',
      );
    }

    final editMsgChanged =
        oldTask.managementEditRequestMessage.trim() !=
        newTask.managementEditRequestMessage.trim();
    final editFilesChanged = !_valuesEqual(
      oldTask.managementEditRequestFileUrls,
      newTask.managementEditRequestFileUrls,
    );
    if ((editMsgChanged || editFilesChanged) &&
        (newTask.managementEditRequestMessage.trim().isNotEmpty ||
            newTask.managementEditRequestFileUrls.isNotEmpty)) {
      final snippet = newTask.managementEditRequestMessage.trim();
      final clip = snippet.length > _timelineValueMaxLength
          ? '${snippet.substring(0, _timelineValueMaxLength)}...'
          : snippet;
      events.add(
        TaskTimelineEvent(
          type: 'management_edit_request',
          label: 'tasks.timeline.management_edit_request',
          newValue: clip.isEmpty ? null : clip,
          byUserId: userId,
          byUserName: userName,
          timestamp: ts(),
        ),
      );
    }

    final rejMsgChanged =
        oldTask.rejectionMessage.trim() != newTask.rejectionMessage.trim();
    final rejFilesChanged = !_valuesEqual(
      oldTask.rejectionFileUrls,
      newTask.rejectionFileUrls,
    );
    if (newTask.status == StorageKeys.status_rejected &&
        (rejMsgChanged || rejFilesChanged) &&
        (newTask.rejectionMessage.trim().isNotEmpty ||
            newTask.rejectionFileUrls.isNotEmpty)) {
      final snippet = newTask.rejectionMessage.trim();
      final clip = snippet.length > _timelineValueMaxLength
          ? '${snippet.substring(0, _timelineValueMaxLength)}...'
          : snippet;
      events.add(
        TaskTimelineEvent(
          type: 'rejection_feedback',
          label: 'tasks.timeline.rejection_feedback',
          newValue: clip.isEmpty ? null : clip,
          byUserId: userId,
          byUserName: userName,
          timestamp: ts(),
        ),
      );
    }

    final oldExt = oldTask.deadlineExtensionStatus.trim();
    final newExt = newTask.deadlineExtensionStatus.trim();
    if (oldExt != TaskModel.kDeadlineExtensionPending &&
        newExt == TaskModel.kDeadlineExtensionPending) {
      final toStr = newTask.deadlineExtensionRequestedTo != null
          ? _formatTimelineValue(newTask.deadlineExtensionRequestedTo!)
          : '';
      events.add(
        TaskTimelineEvent(
          type: 'deadline_extension_requested',
          label: 'tasks.timeline.deadline_extension_requested',
          oldValue: _formatTimelineValue(oldTask.toDate),
          newValue: toStr.isEmpty ? null : toStr,
          byUserId: userId,
          byUserName: userName,
          timestamp: ts(),
        ),
      );
    } else if (oldExt == TaskModel.kDeadlineExtensionPending &&
        newExt.isEmpty &&
        newTask.toDate != oldTask.toDate) {
      events.add(
        TaskTimelineEvent(
          type: 'deadline_extension_approved',
          label: 'tasks.timeline.deadline_extension_approved',
          oldValue: _formatTimelineValue(oldTask.toDate),
          newValue: _formatTimelineValue(newTask.toDate),
          byUserId: userId,
          byUserName: userName,
          timestamp: ts(),
        ),
      );
    } else if (oldExt == TaskModel.kDeadlineExtensionPending &&
        newExt == TaskModel.kDeadlineExtensionDenied) {
      events.add(
        TaskTimelineEvent(
          type: 'deadline_extension_denied',
          label: 'tasks.timeline.deadline_extension_denied',
          newValue: newTask.deadlineExtensionDeniedNote.trim().isEmpty
              ? null
              : (newTask.deadlineExtensionDeniedNote.trim().length >
                        _timelineValueMaxLength
                    ? '${newTask.deadlineExtensionDeniedNote.trim().substring(0, _timelineValueMaxLength)}...'
                    : newTask.deadlineExtensionDeniedNote.trim()),
          byUserId: userId,
          byUserName: userName,
          timestamp: ts(),
        ),
      );
    }

    return events;
  }

  Future<bool> deleteTask(String id) async {
    isLoading.value = true;
    final result = await _service.deleteTask(id);
    isLoading.value = false;
    if (!result) {
      FunHelper.showSnackbar(
        'error'.tr,
        'errors.forbidden'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    return result;
  }

  Future<bool> addLibraryFile(LibraryFileModel file) async {
    final id = await _service.addLibraryFile(file);
    if (id == null) {
      FunHelper.showSnackbar(
        'error'.tr,
        'library.upload_failed'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
    return true;
  }

  Future<bool> deleteLibraryFile(String id) async {
    final result = await _service.deleteLibraryFile(id);
    if (!result) {
      FunHelper.showSnackbar(
        'error'.tr,
        'errors.forbidden'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    return result;
  }

  RxList<dynamic> uploadedFilesPaths = [].obs;
  Future<List<PlatformFile>> pickMultiFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    appLog('Picked files: ${result?.files.map((e) => e.name).toList()}');

    if (result != null && result.files.isNotEmpty) {
      return result.files;
    } else {
      return [];
    }
  }

  Future<List<PlatformFile>> pickoneImage() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.image,
    );
    appLog('Picked files: ${result?.files.map((e) => e.name).toList()}');

    if (result != null && result.files.isNotEmpty) {
      return result.files;
    } else {
      return [];
    }
  }

  /// صورة أو فيديو من المعرض (زر المعرض في الدردشة).
  Future<List<PlatformFile>> pickOneChatGalleryMedia() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.media,
    );
    appLog(
      'Picked gallery media: ${result?.files.map((e) => e.name).toList()}',
    );
    if (result != null && result.files.isNotEmpty) {
      return result.files;
    }
    return [];
  }

  /// Camera photo for chat (Android/iOS only).
  Future<({Uint8List bytes, String fileName})?> pickChatCameraImageBytes() async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    try {
      final xFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (xFile == null) return null;
      final bytes = await xFile.readAsBytes();
      if (bytes.isEmpty) return null;
      return (
        bytes: bytes,
        fileName: 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    } catch (e, st) {
      appLog('pickChatCameraImageBytes failed: $e\n$st');
      return null;
    }
  }

  /// ملف واحد لأي نوع (مرفقات الدردشة).
  Future<List<PlatformFile>> pickOneChatFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      return result.files;
    }
    return [];
  }

  RxDouble uploadProgress = 0.0.obs;
  RxBool isUploading = false.obs;
  Rx<UploadUiPhase> uploadPhase = UploadUiPhase.idle.obs;
  RxString uploadErrorMessage = ''.obs;
  RxnString activeChatUploadId = RxnString();
  UploadCancelToken? _activeUploadCancelToken;

  bool isChatUploadActiveFor(String chatId) =>
      isUploading.value && activeChatUploadId.value == chatId;

  void cancelActiveUpload() {
    final token = _activeUploadCancelToken;
    if (token == null || token.isCancelled) return;
    token.cancel();
    _finishCancelledUploadUi();
  }

  void _finishCancelledUploadUi() {
    isUploading.value = false;
    uploadProgress.value = 0.0;
    uploadPhase.value = UploadUiPhase.idle;
    uploadErrorMessage.value = '';
    activeChatUploadId.value = null;
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  void dismissUploadDialog() {
    uploadPhase.value = UploadUiPhase.idle;
    uploadProgress.value = 0.0;
    uploadErrorMessage.value = '';
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  String _friendlyUploadErrorMessage(Object error) {
    appLog('Upload error detail: $error');
    return AppLocaleKeys.commonUploadFailed.tr;
  }

  Future<String?> uploadFiles({
    required dynamic filePathOrBytes,
    String? fileName,
    bool useBlockingUploadDialog = true,

    /// When set, the R2 presign worker adds `Content-Disposition: attachment` with this name.
    String? friendlyDownloadName,

    /// When false, the returned URL is not pushed to [uploadedFilesPaths] (e.g. content
    /// post/story/reel fields that store URLs only in their own text controllers).
    bool addToUploadedFilesPathsList = true,

    /// When set with [useBlockingUploadDialog] false, inline chat upload UI is scoped
    /// to this chat id (progress banner + composer busy state).
    String? chatScopeId,
  }) async {
    var dialogShown = false;
    final uploadStopwatch = Stopwatch()..start();
    var uploadFileSize = 0;
    String? uploadFileName;
    try {
      final bytes = filePathOrBytes as Uint8List;
      uploadFileSize = bytes.length;
      uploadFileName = fileName;
      if (bytes.length > kMaxUploadBytes) {
        appLog(
          'Upload rejected: ${bytes.length} bytes exceeds $kMaxUploadBytes',
        );
        FunHelper.showSnackbar(
          AppLocaleKeys.errorTitle.tr,
          AppLocaleKeys.commonUploadMaxSizeExceeded.trParams({
            'maxMb': '$kMaxUploadMegabytes',
          }),
          backgroundColor: Colors.deepOrange,
        );
        return null;
      }

      isUploading.value = true;
      uploadProgress.value = 0.0;
      uploadPhase.value = UploadUiPhase.uploading;
      uploadErrorMessage.value = '';
      _activeUploadCancelToken = UploadCancelToken();
      final cancelToken = _activeUploadCancelToken!;

      if (useBlockingUploadDialog) {
        showUploadDialog();
        dialogShown = true;
      } else if (chatScopeId != null && chatScopeId.isNotEmpty) {
        activeChatUploadId.value = chatScopeId;
      }

      final signer = AppConfig.r2SignerUrl.trim();
      if (signer.isEmpty) {
        FunHelper.showSnackbar(
          AppLocaleKeys.errorTitle.tr,
          AppLocaleKeys.errorsR2NotConfigured.tr,
          backgroundColor: Colors.deepOrange,
        );
        isUploading.value = false;
        uploadPhase.value = UploadUiPhase.idle;
        activeChatUploadId.value = null;
        _activeUploadCancelToken = null;
        if (dialogShown) {
          Get.back();
        }
        return null;
      }

      final ct =
          lookupMimeType(fileName ?? '') ?? 'application/octet-stream';
      final url = await uploadObjectToR2(
        data: bytes,
        fileName: fileName ?? 'file.bin',
        contentType: ct,
        friendlyDownloadName: friendlyDownloadName,
        cancelToken: cancelToken,
        onProgress: (sent, total) {
          if (total > 0) {
            uploadProgress.value = sent / total;
            if (sent >= total) {
              uploadPhase.value = UploadUiPhase.finalizing;
            }
          }
        },
      );

      uploadProgress.value = 1.0;

      if (addToUploadedFilesPathsList) {
        uploadedFilesPaths.add(url);
      }

      isUploading.value = false;
      uploadPhase.value = UploadUiPhase.idle;
      activeChatUploadId.value = null;
      if (dialogShown) {
        Get.back();
      }

      return url;
    } on UploadCancelledException {
      _finishCancelledUploadUi();
      return null;
    } catch (e) {
      isUploading.value = false;
      activeChatUploadId.value = null;
      appLog("Error uploading file: $e");
      if (e is! UploadCancelledException) {
        unawaited(
          UploadDiagnostics.logFailure(
            error: e,
            fileSizeBytes: uploadFileSize,
            fileName: uploadFileName,
            durationMs: uploadStopwatch.elapsedMilliseconds,
            context: chatScopeId != null && chatScopeId.isNotEmpty ? 'chat' : null,
            employeeId: currentEmployee.value?.id,
          ),
        );
      }
      if (dialogShown) {
        uploadPhase.value = UploadUiPhase.failed;
        uploadErrorMessage.value = _friendlyUploadErrorMessage(e);
      } else {
        uploadPhase.value = UploadUiPhase.idle;
        uploadProgress.value = 0.0;
        FunHelper.showSnackbar(
          AppLocaleKeys.errorTitle.tr,
          '${AppLocaleKeys.commonUploadFailed.tr} ${AppLocaleKeys.commonUploadFailedHint.tr}',
          backgroundColor: Colors.deepOrange,
        );
      }
      return null;
    } finally {
      _activeUploadCancelToken = null;
      if (!isUploading.value) {
        activeChatUploadId.value = null;
      }
    }
  }

  static bool _isEmployeeRoleForDashboard(String role) =>
      role.trim().toLowerCase() == 'employee';

  /// يملأ حالة الموظف والبثوث فورًا (تسجيل دخول صامت / استعادة جلسة) حتى يعمل [AuthMiddleware].
  ///
  /// على الويب يجب انتظار [restoreEmployeeDashboardTaskFiltersFromPrefs] قبل التنقل،
  /// وإلا تُبنى لوحة الموظف قبل اكتمال قراءة SharedPreferences.
  Future<void> applyEmployeeSessionAfterAuthRestore(
    EmployeeModel employee,
  ) async {
    if (employee.id == null || employee.id!.isEmpty) return;
    currentEmployee.value = employee;
    lastKnownEmployee.value = employee;
    FirestoreServices.setSessionEmployeeId(employee.id);
    syncActiveDepartmentFilterFromEmployee(employee);
    await syncAuthRoleAndRefreshDataStreams(employee);
    final role = employee.role.trim().toLowerCase();
    if (role == 'admin' || role == 'supervisor') {
      unawaited(BackfillEmployeeDepartments.runIfNeeded(isManager: true));
    }
    if (role == 'admin' || role == 'supervisor' || role == 'employee') {
      fetchEmployees();
    } else {
      employees.bindStream(Stream<List<EmployeeModel>>.value([]));
    }
    fetchProgrammingUpdates();
    if (role != 'admin' && role != 'supervisor') {
      metaPosts.bindStream(Stream<List<MetaPostModel>>.value([]));
    }
    _startEmployeePresenceStream();
    _startTotalUnreadStream(employee.id!);
    _startPresenceHeartbeatForEmployee(employee.id!);
    listenToClient(employee.id!);
    fetchNotification(employee.id);
    if (_isEmployeeRoleForDashboard(employee.role)) {
      await restoreEmployeeDashboardTaskFiltersFromPrefs();
    }
  }

  Future<EmployeeModel?> loginClient(email, pass) async {
    isLoading.value = true;
    try {
      final result = await _service.loginEmployee(email, pass);
      // يجب تعبئة الجلسة هنا فورًا: AuthMiddleware يعتمد على currentemployee قبل التنقل،
      // بينما listenToClient يحدّثه فقط عند وصول أول snapshot من Firestore (متأخر عن أول إطار).
      if (result != null && result.id != null) {
        await applyEmployeeSessionAfterAuthRestore(result);
      }
      return result;
    } finally {
      isLoading.value = false;
    }
  }

  final _clientCollection = FirebaseFirestore.instance.collection("employees");
  Rxn<EmployeeModel> currentEmployee = Rxn<EmployeeModel>();
  Rxn<EmployeeModel> lastKnownEmployee = Rxn<EmployeeModel>();

  /// Employee dashboard: empty string = all departments; otherwise a slug from [StorageKeys.departmentSlugs].
  final RxString activeDepartmentFilter = ''.obs;

  /// Pass to [StorageKeys.isEmployeeDashboardStatusFilterAllowedForDepartment] / dropdown helpers.
  String? get employeeDashboardDepartmentFilterArg {
    final e = currentEmployee.value;
    if (e == null || e.role.trim().toLowerCase() != 'employee') return null;
    final v = activeDepartmentFilter.value.trim();
    if (v.isEmpty) return null;
    return v;
  }

  void syncActiveDepartmentFilterFromEmployee(EmployeeModel? e) {
    if (e == null || e.role.trim().toLowerCase() != 'employee') {
      activeDepartmentFilter.value = '';
      return;
    }
    if (e.departments.isEmpty) {
      activeDepartmentFilter.value = '';
      return;
    }
    if (e.departments.length == 1) {
      activeDepartmentFilter.value = e.departments.first;
      return;
    }
    final cur = activeDepartmentFilter.value.trim();
    if (cur.isNotEmpty && e.departments.contains(cur)) {
      return;
    }
    activeDepartmentFilter.value = '';
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _employeeDocSub;
  EmployeeModel? get effectiveEmployee =>
      currentEmployee.value ?? lastKnownEmployee.value;

  void listenToClient(String empid) async {
    _employeeDocSub?.cancel();
    _employeeDocSub = _clientCollection
        .doc(empid)
        .snapshots()
        .listen(
          (snapshot) async {
            if (snapshot.exists && snapshot.data() != null) {
              final employee = EmployeeModel.fromFirestoreMap(
                snapshot.data(),
                id: empid,
              );
              final previous = currentEmployee.value;
              final profileChanged = !_sameEmployeeProfileCore(
                previous,
                employee,
              );
              if (!profileChanged) return;

              currentEmployee.value = employee;
              lastKnownEmployee.value = employee;
              FirestoreServices.setSessionEmployeeId(employee.id);
              syncActiveDepartmentFilterFromEmployee(employee);
              unawaited(FirestoreServices.syncAuthRoleForEmployee(employee));
              _startTotalUnreadStream(empid);

              // Only rebind data streams when role/departments change.
              // Rebinding on every profile field (image, authUid, …) cancels an
              // in-flight clients listener right after login and leaves [].
              final roleOrDeptsChanged = previous == null ||
                  previous.role.trim().toLowerCase() !=
                      employee.role.trim().toLowerCase() ||
                  previous.departments.length != employee.departments.length ||
                  previous.departments.asMap().entries.any(
                    (e) => employee.departments[e.key] != e.value,
                  );
              if (roleOrDeptsChanged) {
                await syncAuthRoleAndRefreshDataStreams(employee);
              }
            }
          },
          onError: (e, s) {
            appLog('listenToClient stream error for $empid: $e');
          },
        );
    fetchContents();
    // fetchnotification(currentemployee.value?.id);
  }

  var employees = <EmployeeModel>[].obs;
  var clients = <ClientModel>[].obs;
  var libraryFiles = <LibraryFileModel>[].obs;
  /// Full archive tasks for Library browse / picker (employees with libraryAccess).
  var libraryBrowseTasks = <TaskModel>[].obs;
  var contents = <ContentModel>[].obs;
  var metaPosts = <MetaPostModel>[].obs;
  var searchedContents = <ContentModel>[].obs;

  /// تصفية قائمة المحتوى في واجهة موظف الويب (مثل شاشة المهام).
  final TextEditingController employeeWebContentSearchController =
      TextEditingController();
  final RxList<String> employeeWebContentStatusFilters = <String>[].obs;
  final RxList<String> employeeWebContentTypeFilters = <String>[].obs;
  final Rxn<DateTime> employeeWebContentDateFilter = Rxn<DateTime>();
  final RxInt employeeWebContentFiltersRevision = 0.obs;
  final RxSet<String> selectedContentIds = <String>{}.obs;

  RxString selectedDate = ''.obs;
  var notifications = <NotificationModel>[].obs;
  var tasks = <TaskModel>[].obs;
  var programmingUpdates = <ProgrammingUpdateModel>[].obs;
  var isLoading = false.obs;

  /// Total unread messages across all chats (for header badge).
  RxInt totalUnreadMessages = 0.obs;
  StreamSubscription<int>? _totalUnreadSub;
  String? _totalUnreadUserId;
  StreamSubscription<String>? _fcmTokenRefreshSub;
  StreamSubscription<Map<String, DateTime>>? _employeePresenceSub;
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _presenceDocSubs = {};
  Set<String> _presenceWatchIds = const {};
  bool _useFullPresenceStream = false;
  final RxMap<String, DateTime> employeePresenceById = <String, DateTime>{}.obs;
  bool _fcmSetupInProgress = false;

  static bool _sameEmployeeProfileCore(EmployeeModel? a, EmployeeModel b) {
    if (a == null) return false;
    final sameDepartments =
        a.departments.length == b.departments.length &&
        a.departments.asMap().entries.every(
          (entry) => b.departments[entry.key] == entry.value,
        );
    return a.id == b.id &&
        a.name == b.name &&
        a.email == b.email &&
        a.role == b.role &&
        a.status == b.status &&
        a.image == b.image &&
        a.authUid == b.authUid &&
        a.authStatus == b.authStatus &&
        sameDepartments;
  }

  void _startTotalUnreadStream(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    if (_totalUnreadUserId == id && _totalUnreadSub != null) return;
    _totalUnreadSub?.cancel();
    _totalUnreadUserId = id;
    _totalUnreadSub = _service
        .getTotalUnreadMessagesStream(
          id,
          onPerChatUnreadIncrease: (chatId) {
            if (!kIsWeb) return;
            // Web: unread aggregate also fires when a message arrives; skip the
            // notification ding if this thread is already open (page or popup).
            if (!isBrowserTabHidden &&
                ChatAudioFocus.incomingTreatAsInChat(chatId)) {
              return;
            }
            unawaited(
              AudioService.instance.playNotificationSound(chatId: chatId),
            );
          },
        )
        .listen(
          (count) => totalUnreadMessages.value = count,
          onError: (Object e, StackTrace st) {
            // بعد تسجيل الخروج قد تُرفض استعلامات chats/messages — لا نُعيد رمي الخطأ.
            if (FirebaseAuth.instance.currentUser == null) {
              totalUnreadMessages.value = 0;
              return;
            }
            appLog('⚠️ totalUnread stream: $e');
            totalUnreadMessages.value = 0;
          },
        );
  }

  void _stopTotalUnreadStream() {
    _totalUnreadSub?.cancel();
    _totalUnreadSub = null;
    _totalUnreadUserId = null;
    totalUnreadMessages.value = 0;
  }

  Future<void> _sendPresenceHeartbeat(String employeeId) async {
    final id = employeeId.trim();
    if (id.isEmpty || !_appInForeground) return;
    await _service.syncEmployeePresenceHeartbeat(id);
  }

  void _startPresenceHeartbeatForEmployee(String employeeId) {
    final id = employeeId.trim();
    if (id.isEmpty || !_appInForeground) return;
    if (_presenceHeartbeatEmployeeId == id && _presenceHeartbeatTimer != null) {
      return;
    }
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
    _presenceHeartbeatEmployeeId = id;
    unawaited(_sendPresenceHeartbeat(id));
    _presenceHeartbeatTimer = Timer.periodic(_presenceHeartbeatInterval, (_) {
      if (!_appInForeground) return;
      unawaited(_sendPresenceHeartbeat(id));
    });
  }

  void _stopPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
    _presenceHeartbeatEmployeeId = null;
  }

  void handleAppLifecycleResumed() {
    _appInForeground = true;
    final id = currentEmployee.value?.id?.trim();
    if (id == null || id.isEmpty) return;
    _startPresenceHeartbeatForEmployee(id);
  }

  void handleAppLifecyclePaused() {
    _appInForeground = false;
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
  }

  void _startEmployeePresenceStream() {
    _employeePresenceSub?.cancel();
    _employeePresenceSub = null;
    _stopTargetedPresenceDocListeners();

    if (FirebaseAuth.instance.currentUser == null) {
      employeePresenceById.clear();
      _useFullPresenceStream = false;
      return;
    }

    final emp = effectiveEmployee;
    final role = emp?.role.trim().toLowerCase() ?? '';

    if (role == 'admin' || role == 'supervisor') {
      _useFullPresenceStream = true;
      _employeePresenceSub = _service.getEmployeePresenceMap().listen(
        (map) {
          employeePresenceById.assignAll(map);
        },
        onError: (Object e, StackTrace st) {
          appLog('employee_presence stream: $e');
          appLog('$st');
        },
      );
      return;
    }

    if (role == 'employee') {
      _useFullPresenceStream = false;
      employeePresenceById.clear();
      _rebindTargetedPresenceDocListeners();
      return;
    }

    _useFullPresenceStream = false;
    employeePresenceById.clear();
  }

  /// Targeted presence reads for regular employees (chat list + open chat).
  void setPresenceWatchIds(Set<String> ids) {
    final emp = effectiveEmployee;
    final role = emp?.role.trim().toLowerCase() ?? '';
    if (role != 'employee' || _useFullPresenceStream) return;

    final selfId = emp?.id?.trim() ?? '';
    final capped = ids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != selfId)
        .take(kEmployeePresenceWatchIdCap)
        .toSet();

    if (_presenceWatchIds.length == capped.length &&
        capped.every(_presenceWatchIds.contains)) {
      return;
    }
    _presenceWatchIds = capped;
    _rebindTargetedPresenceDocListeners();
  }

  void _stopTargetedPresenceDocListeners() {
    for (final sub in _presenceDocSubs.values) {
      sub.cancel();
    }
    _presenceDocSubs.clear();
    _presenceWatchIds = const {};
  }

  void _rebindTargetedPresenceDocListeners() {
    if (_useFullPresenceStream) return;

    final next = _presenceWatchIds;
    final toRemove =
        _presenceDocSubs.keys.where((id) => !next.contains(id)).toList();
    for (final id in toRemove) {
      _presenceDocSubs.remove(id)?.cancel();
      employeePresenceById.remove(id);
    }

    for (final id in next) {
      if (_presenceDocSubs.containsKey(id)) continue;
      _presenceDocSubs[id] = _service.watchEmployeePresenceDoc(
        id,
        (employeeId, lastSeenAt) {
          if (lastSeenAt == null) {
            employeePresenceById.remove(employeeId);
          } else {
            employeePresenceById[employeeId] = lastSeenAt;
          }
        },
      );
    }
  }

  DateTime? employeeLastSeenAt(String? employeeId) {
    final id = employeeId?.trim() ?? '';
    if (id.isEmpty) return null;
    return employeePresenceById[id];
  }

  setupFCM(userId) async {
    if (_fcmSetupInProgress) return;
    final uid = userId?.toString().trim() ?? currentEmployee.value?.id;
    if (uid == null || uid.isEmpty) return;

    _fcmSetupInProgress = true;
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings;
      if (kIsWeb) {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } else {
        settings = await PushPermissionsHelper.ensurePushPermissionsFlow();
      }

      final isAllowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (isAllowed) {
        appLog('User granted permission');

        String? token;
        if (kIsWeb) {
          const isTest = bool.fromEnvironment(
            'USE_FIREBASE_TEST',
            defaultValue: false,
          );
          token = await messaging.getToken(
            vapidKey: isTest
                ? AppConfig.fcmVapidKeyTest
                : AppConfig.fcmVapidKeyProd,
          );
        } else {
          token = await messaging.getToken();
        }
        if (token != null && currentEmployee.value != null) {
          final empId = currentEmployee.value!.id ?? userId;
          for (var attempt = 0; attempt < 3; attempt++) {
            try {
              await FirestoreServices.addEmployeeFcmToken(
                employeeId: empId,
                token: token,
              );
              await FcmTokenCache.rememberSuccess(
                token: token,
                role: 'employee',
                userId: empId.toString(),
              );
              await LanguageController.syncPersistedLocaleToFirestore();
              break;
            } catch (e) {
              if (attempt == 2) {
                appLog('addEmployeeFcmToken failed after retries: $e');
              } else {
                await Future<void>.delayed(
                  Duration(milliseconds: 350 * (attempt + 1)),
                );
              }
            }
          }
          appLog("FCM Registration Token: ${kIsWeb ? 'Web' : ''} $token");
        }

        _fcmTokenRefreshSub?.cancel();
        _fcmTokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
          refreshedToken,
        ) async {
          final employeeId = currentEmployee.value?.id ?? userId;
          if (employeeId == null || employeeId.toString().trim().isEmpty)
            return;
          final idStr = employeeId.toString();
          for (var attempt = 0; attempt < 3; attempt++) {
            try {
              await FirestoreServices.addEmployeeFcmToken(
                employeeId: idStr,
                token: refreshedToken,
              );
              await FcmTokenCache.rememberSuccess(
                token: refreshedToken,
                role: 'employee',
                userId: idStr,
              );
              await LanguageController.syncPersistedLocaleToFirestore();
              appLog('FCM token refreshed for employee $idStr');
              return;
            } catch (e) {
              if (attempt == 2) {
                appLog('FCM onTokenRefresh failed after retries: $e');
              } else {
                await Future<void>.delayed(
                  Duration(milliseconds: 350 * (attempt + 1)),
                );
              }
            }
          }
        });
      } else {
        appLog('User declined or has not yet granted permission');
        throw StateError(
          'NOTIFICATION_PERMISSION_${settings.authorizationStatus.name.toUpperCase()}',
        );
      }
    } catch (e) {
      // على الويب: token-subscribe-failed شائع لغياب OAuth/Service Worker
      appLog('setupFCM: $e');
      if (kIsWeb)
        appDebugPrint('FCM on web may need service worker / OAuth: $e');
    } finally {
      _fcmSetupInProgress = false;
    }
  }

  void showUploadDialog() {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: resolveAppTheme().cardSurface,
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Obx(() {
                final phase = uploadPhase.value;
                if (phase == UploadUiPhase.failed) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 44,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        uploadErrorMessage.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: resolveAppTheme().primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocaleKeys.commonUploadFailedHint.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: resolveAppTheme().secondaryText,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: dismissUploadDialog,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(AppLocaleKeys.appClose.tr),
                      ),
                    ],
                  );
                }

                final p = uploadProgress.value.clamp(0.0, 1.0);
                final statusText =
                    phase == UploadUiPhase.finalizing
                        ? AppLocaleKeys.commonUploadFinalizing.tr
                        : 'common.uploading'.tr;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: resolveAppTheme().accentText,
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: p,
                        minHeight: 8,
                        backgroundColor: resolveAppTheme().border,
                        color: resolveAppTheme().accentText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${(p * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: resolveAppTheme().primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: resolveAppTheme().secondaryText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: cancelActiveUpload,
                      child: Text(AppLocaleKeys.commonCancel.tr),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
      barrierColor: Colors.black54,
    );
  }

  RxList<OpenChatModel> openChats = <OpenChatModel>[].obs;

  void openChat(OpenChatModel chat) {
    if (!openChats.any((c) => c.id == chat.id)) {
      if (openChats.length == 3) {
        openChats.removeAt(0);
      }
      openChats.add(chat);
    } else {
      toggleMinimize(chat.id, false);
    }
  }

  void closeChat(String id) {
    openChats.removeWhere((c) => c.id == id);
  }

  void toggleMinimize(String id, bool value) {
    final index = openChats.indexWhere((c) => c.id == id);
    if (index != -1) {
      openChats[index].minimized = value;
      update();
    }
  }

  void increaseUnread(String id) {
    final chat = openChats.firstWhereOrNull((c) => c.id == id);
    if (chat != null && chat.minimized) {
      chat.unreadCount++;
      update();
    }
  }

  void clearUnread(String id) {
    final chat = openChats.firstWhereOrNull((c) => c.id == id);
    if (chat != null) {
      chat.unreadCount = 0;
      update();
    }
  }

  @override
  void onInit() {
    // currentemployee.value?.id = '3';
    _rebindClientsAndTasksStreams();
    fetchProgrammingUpdates();
    fetchContents();
    ever(contents, (_) => refreshFilteredContents());
    ever(tasks, (_) {
      filterTasks();
      filterTasksHistory();
    });
    _restoreEmployeeSessionIfNeeded();
    _startEmployeePresenceStream();
    super.onInit();
  }

  @override
  void onClose() {
    _employeeDashFilterSaveDebounce?.cancel();
    _employeeDashFilterSaveDebounce = null;
    _publishFilterSaveDebounce?.cancel();
    _publishFilterSaveDebounce = null;
    publishSearchController.dispose();
    employeeWebContentSearchController.dispose();
    _employeeDocSub?.cancel();
    _employeeDocSub = null;
    _stopPresenceHeartbeat();
    _stopTotalUnreadStream();
    _fcmTokenRefreshSub?.cancel();
    _fcmTokenRefreshSub = null;
    _employeePresenceSub?.cancel();
    _employeePresenceSub = null;
    _stopTargetedPresenceDocListeners();
    super.onClose();
  }

  Future<void> _restoreEmployeeSessionIfNeeded() async {
    // Avoid re-login when already hydrated (normal in-app navigation).
    if (effectiveEmployee != null) return;

    // الويب: التحميل البارد يمرّ بـ [WebAuthSplashDecider] وـ attemptSilentLogin.
    if (kIsWeb) return;

    try {
      final pref = await SharedPreferences.getInstance();
      final isLoggedIn = (pref.getBool('isLoggedIn') ?? false) == true;
      if (!isLoggedIn) return;

      final employee = await _service.getCurrentEmployeeByAuth();
      if (employee == null || employee.id == null) return;
      if (employee.status != 'active') return;

      await applyEmployeeSessionAfterAuthRestore(employee);
      unawaited(setupFCM(employee.id));
    } catch (e, s) {
      appLog('restoreEmployeeSessionIfNeeded error: $e');
      appLog('StackTrace: $s');
    }
  }

  void clearEmployeeSession() {
    currentEmployee.value = null;
    lastKnownEmployee.value = null;
    FirestoreServices.setSessionEmployeeId(null);
    _employeeDocSub?.cancel();
    _employeeDocSub = null;
    _stopPresenceHeartbeat();
    _stopTotalUnreadStream();
    _employeePresenceSub?.cancel();
    _employeePresenceSub = null;
    _stopTargetedPresenceDocListeners();
    employeePresenceById.clear();
    employees.bindStream(Stream<List<EmployeeModel>>.value([]));
    clients.bindStream(Stream<List<ClientModel>>.value([]));
    contents.bindStream(Stream<List<ContentModel>>.value([]));
    tasks.bindStream(Stream<List<TaskModel>>.value([]));
    programmingUpdates.bindStream(
      Stream<List<ProgrammingUpdateModel>>.value(const []),
    );
    notifications.bindStream(Stream<List<NotificationModel>>.value([]));
    searchedContents.clear();
    clearEmployeeWebContentFilters();
    openChats.clear();
  }
}

class OpenChatModel {
  final String id;
  final String name;
  final String avatar;
  final bool isGroup;
  bool minimized;
  int unreadCount;

  OpenChatModel({
    required this.id,
    required this.name,
    required this.avatar,
    this.isGroup = false,
    this.minimized = false,
    this.unreadCount = 0,
  });
}
