library point.home_controller;

import 'dart:async';
import 'dart:convert';
import 'package:point/Utils/app_log.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/MetaPostModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/NotificationModel.dart';
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
import 'package:point/Services/push_permissions_helper.dart';
import 'package:point/Services/supabase_storage_binary_upload.dart';
import 'package:point/Services/upload_limits.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/meta/meta_media_util.dart';
import 'package:point/Services/firestore/firestore_task_utils.dart'
    show taskTypeCodeForNormalizedDepartment;
import 'package:point/Services/firestore/migrations/backfill_employee_departments.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/final_deliverable_upload_names.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:point/config/app_config.dart';

import 'package:point/Controller/home_task_filters.dart';

part 'home_controller_rebind.dart';

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
  final supabase = Supabase.instance.client;
  void changeType(String type) {
    selectedTypeNotifications.value = type;
  }

  Map<String, dynamic>? selectedChat;

  void changeIndex(int index) {
    selectedIndex = index;
    update();
  }

  var selectedPriority = ''.obs;
  var selectedStatus = ''.obs;
  var selectedExecutor = ''.obs;
  var searchController = TextEditingController();

  Timer? _employeeDashFilterSaveDebounce;
  Timer? _presenceHeartbeatTimer;
  String? _presenceHeartbeatEmployeeId;
  static const Duration _presenceHeartbeatInterval = Duration(seconds: 75);

  // RxList<TaskModel> allTasks = <TaskModel>[].obs;
  RxList<TaskModel> tasksSearched = <TaskModel>[].obs;

  /// قائمة المهام المنتهية لصفحة سجل المهام
  RxList<TaskModel> tasksHistory = <TaskModel>[].obs;

  void filterTasks() {
    final searchText = searchController.text.trim().toLowerCase();

    // فلتر حالة حسب قسم الموظف (لا نخلط حالات الترويج مع بقية الأقسام)
    if (selectedStatus.value.isNotEmpty &&
        !StorageKeys.isEmployeeDashboardStatusFilterAllowedForDepartment(
          selectedStatus.value,
          employeeDashboardDepartmentFilterArg,
        )) {
      selectedStatus.value = '';
    }

    final empDash = currentEmployee.value;
    final isEmployee =
        empDash != null && empDash.role.trim().toLowerCase() == 'employee';
    final empId = empDash?.id?.trim() ?? '';
    final rejectedFilterActive =
        isEmployee &&
        empId.isNotEmpty &&
        FunHelper.canonicalStoredStatus(selectedStatus.value) ==
            StorageKeys.status_rejected;

    // Employees: rejected tasks only when explicitly filtering by rejected;
    // otherwise ongoing tasks only (same as admins/supervisors).
    late List<TaskModel> baseList;
    if (rejectedFilterActive) {
      baseList = tasks.where((t) {
        if (t.assignedTo.trim() != empId) return false;
        return FunHelper.canonicalStoredStatus(t.status) ==
            StorageKeys.status_rejected;
      }).toList();
    } else {
      baseList = tasks.where((t) => StorageKeys.isTaskOngoing(t)).toList();
    }

    if (isEmployee) {
      final arg = employeeDashboardDepartmentFilterArg;
      if (arg != null && arg.isNotEmpty) {
        final typeCode = taskTypeCodeForNormalizedDepartment(
          StorageKeys.normalizeDepartment(arg),
        );
        // Dept chip = show only tasks for that department's type. Do not OR
        // `assignedTo == me` here: the task stream already includes assigned
        // tasks, and that OR would show e.g. programming tasks under photography.
        if (typeCode != null) {
          baseList = baseList.where((t) => t.type == typeCode).toList();
        }
      }
    }

    // Status filter (skipped when list is already the rejected-only employee view).
    if (selectedStatus.value.isNotEmpty && !rejectedFilterActive) {
      baseList = baseList
          .where(
            (t) => t.status.toLowerCase() == selectedStatus.value.toLowerCase(),
          )
          .toList();
    }

    // إن لم يُختر أي فلتر آخر نعرض النتيجة فوراً
    if (searchText.isEmpty &&
        selectedPriority.value.isEmpty &&
        selectedExecutor.value.isEmpty) {
      tasksSearched.assignAll(baseList);
      return;
    }

    tasksSearched.assignAll(
      filterTasksBySearchPriorityExecutor(
        baseList: baseList,
        searchText: searchText,
        selectedPriority: selectedPriority.value,
        selectedExecutor: selectedExecutor.value,
        employees: employees,
      ),
    );
  }

  /// Firestore employee docs may omit `id` in the payload; prefs must still use the doc id.
  String? _employeeDashboardPrefsEmployeeId() {
    final a = currentEmployee.value?.id?.trim() ?? '';
    if (a.isNotEmpty) return a;
    final b = lastKnownEmployee.value?.id?.trim() ?? '';
    if (b.isNotEmpty) return b;
    return null;
  }

  Future<void> persistEmployeeDashboardTaskFilters() async {
    final id = _employeeDashboardPrefsEmployeeId();
    if (id == null || id.isEmpty) return;
    try {
      final pref = await SharedPreferences.getInstance();
      await pref.setString(
        StorageKeys.prefsEmployeeDashboardTaskFiltersKey(id),
        jsonEncode({
          'priority': selectedPriority.value,
          'status': selectedStatus.value,
        }),
      );
    } catch (_) {}
  }

  void schedulePersistEmployeeDashboardTaskFilters() {
    _employeeDashFilterSaveDebounce?.cancel();
    _employeeDashFilterSaveDebounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(persistEmployeeDashboardTaskFilters()),
    );
  }

  Future<void> restoreEmployeeDashboardTaskFiltersFromPrefs() async {
    final id = _employeeDashboardPrefsEmployeeId();
    if (id == null || id.isEmpty) return;
    try {
      final pref = await SharedPreferences.getInstance();
      final raw = pref.getString(
        StorageKeys.prefsEmployeeDashboardTaskFiltersKey(id),
      );
      if (raw == null || raw.isEmpty) {
        filterTasks();
        return;
      }
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) {
        filterTasks();
        return;
      }
      final p = (map['priority'] as String?)?.trim() ?? '';
      final s = (map['status'] as String?)?.trim() ?? '';
      if (p.isNotEmpty && StorageKeys.priority.contains(p)) {
        selectedPriority.value = p;
      } else {
        selectedPriority.value = '';
      }

      if (s.isNotEmpty &&
          StorageKeys.isEmployeeDashboardStatusFilterAllowedForDepartment(
            s,
            employeeDashboardDepartmentFilterArg,
          )) {
        selectedStatus.value = s;
      } else {
        selectedStatus.value = '';
      }
    } catch (_) {
      // Keep current field values.
    }
    filterTasks();
  }

  Future<void> clearEmployeeDashboardTaskFilters() async {
    searchController.clear();
    selectedPriority.value = '';
    selectedStatus.value = '';
    filterTasks();
    await persistEmployeeDashboardTaskFilters();
  }

  void filterTasksHistory() {
    final searchText = searchController.text.trim().toLowerCase();

    if (selectedStatus.value.isNotEmpty &&
        !StorageKeys.statusListEnded.contains(selectedStatus.value) &&
        selectedStatus.value != StorageKeys.status_promotion_finished) {
      selectedStatus.value = '';
    }

    List<TaskModel> baseList = tasks
        .where((t) => StorageKeys.isTaskEnded(t))
        .toList();

    if (selectedStatus.value.isNotEmpty &&
        (StorageKeys.statusListEnded.contains(selectedStatus.value) ||
            selectedStatus.value == StorageKeys.status_promotion_finished)) {
      baseList = baseList
          .where(
            (t) => t.status.toLowerCase() == selectedStatus.value.toLowerCase(),
          )
          .toList();
    }

    if (searchText.isEmpty &&
        selectedPriority.value.isEmpty &&
        selectedExecutor.value.isEmpty) {
      tasksHistory.assignAll(baseList);
      return;
    }

    tasksHistory.assignAll(
      filterTasksBySearchPriorityExecutor(
        baseList: baseList,
        searchText: searchText,
        selectedPriority: selectedPriority.value,
        selectedExecutor: selectedExecutor.value,
        employees: employees,
      ),
    );
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

  /// يربط تيار العملاء والمهام حسب الدور: العميل لا يستطيع استعلامات المجموعة الكاملة.
  void _rebindClientsAndTasksStreams() {
    if (FirebaseAuth.instance.currentUser == null) {
      clients.bindStream(Stream<List<ClientModel>>.value([]));
      tasks.bindStream(Stream<List<TaskModel>>.value([]));
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
    employeeWebContentStatusFilter.value = '';
    employeeWebContentTypeFilter.value = '';
    employeeWebContentDateFilter.value = null;
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
  }) {
    final linkedClient = clients.firstWhereOrNull(
      (c) => c.id == content.clientId,
    );
    final pageId = (linkedClient?.metaPageId ?? '').trim();
    final pageAccessToken = (linkedClient?.metaPageAccessToken ?? '').trim();
    if (pageId.isEmpty || pageAccessToken.isEmpty) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.publishClientMetaPageRequired.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
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
      status: schedule ? 'scheduled' : 'queued_now',
      clientId: content.clientId,
      createdBy: currentEmployee.value?.id,
      lang: Get.locale?.languageCode ?? 'ar',
      scheduledAt: schedule
          ? content.publishDate?.toUtc()
          : DateTime.now().toUtc(),
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
    final ct = employeeWebContentTypeFilter.value;
    if (ct.isNotEmpty) {
      list = list.where((c) => c.contentType == ct).toList();
    }
    final st = employeeWebContentStatusFilter.value;
    if (st.isNotEmpty) {
      list = list.where((c) => c.status == st).toList();
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

  Future<bool> addContent(ContentModel content) async {
    isLoading.value = true;
    final result = await _service.addContent(content);
    isLoading.value = false;
    return result;
  }

  Future<bool> updateContent(ContentModel content) async {
    isLoading.value = true;
    final result = await _service.updateContent(content);
    isLoading.value = false;
    return result;
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
    final result = await _service.addMetaPost(post);
    isLoading.value = false;
    return result;
  }

  Future<bool> updateMetaPost(MetaPostModel post) async {
    isLoading.value = true;
    final result = await _service.updateMetaPost(post);
    isLoading.value = false;
    return result;
  }

  Future<bool> deleteMetaPost(String id) async {
    isLoading.value = true;
    final result = await _service.deleteMetaPost(id);
    isLoading.value = false;
    return result;
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
    }
    return ok;
  }

  void fetchTasks() {
    _rebindClientsAndTasksStreams();
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
    final result = await _service.addTask(taskWithTimeline);
    isLoading.value = false;
    if (result && task.assignedTo.trim().isNotEmpty) {
      unawaited(
        NotificationService.notifyEmployeeAssignedToTask(
          employeeId: task.assignedTo,
          taskTitle: task.title,
        ),
      );
      unawaited(
        NotificationService.notifyManagersNewTaskInDepartment(
          taskTitle: task.title,
          departmentNameAr: NotificationService.departmentNameFromTaskType(
            task.type,
          ),
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

    if (oldTask.status != newTask.status) {
      if (assigneeId.isNotEmpty) {
        await NotificationService.notifyEmployeeTaskStatusChanged(
          employeeId: assigneeId,
          taskTitle: newTask.title,
          newStatus: newTask.status,
          changedBy: (emp?.name ?? '').trim(),
        );
      }
      if (isUpdateByAssignee) {
        if (newTask.status == StorageKeys.status_processing ||
            newTask.status == StorageKeys.status_promotion_in_progress) {
          await NotificationService.notifyManagersTaskReceivedByEmployee(
            employeeName: assigneeName,
            taskTitle: newTask.title,
          );
        } else if (newTask.status == StorageKeys.status_ready_to_publish ||
            newTask.status == StorageKeys.status_under_revision ||
            newTask.status == StorageKeys.status_promotion_ad_platform_review ||
            newTask.status == StorageKeys.status_task_completed) {
          await NotificationService.notifyManagersTaskCompletedByEmployee(
            employeeName: assigneeName,
            taskTitle: newTask.title,
          );
        }
      }
      if (newTask.status == StorageKeys.status_rejected &&
          assigneeId.isNotEmpty) {
        await NotificationService.notifyEmployeeTaskRejected(
          employeeId: assigneeId,
          taskTitle: newTask.title,
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
        );
      }
      if (oldTask.status != newTask.status &&
          newTask.status == StorageKeys.status_awaiting_manager &&
          emp?.role == 'supervisor') {
        final sn = (emp?.name ?? '').trim();
        await NotificationService.notifyAdminsSupervisorEscalatedTask(
          supervisorName: sn.isEmpty ? 'notify.unknown_actor'.tr : sn,
          taskTitle: newTask.title,
        );
      }
      final wasEnded = StorageKeys.isTaskEnded(oldTask);
      final isNowOngoing = StorageKeys.isTaskOngoing(newTask);
      if (wasEnded && isNowOngoing && assigneeId.isNotEmpty) {
        await NotificationService.notifyEmployeeTaskReopened(
          employeeId: assigneeId,
          taskTitle: newTask.title,
        );
      }
    }

    if (newTask.files.length > oldTask.files.length && assigneeId.isNotEmpty) {
      await NotificationService.notifyEmployeeNewAttachments(
        employeeId: assigneeId,
        taskTitle: newTask.title,
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
      );
    }
    if (oldDe == TaskModel.kDeadlineExtensionPending &&
        newDe == TaskModel.kDeadlineExtensionDenied &&
        assigneeId.isNotEmpty) {
      await NotificationService.notifyEmployeeDeadlineExtensionDenied(
        employeeId: assigneeId,
        taskTitle: newTask.title,
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
      final newNote = newTask.notes.isNotEmpty ? newTask.notes.last.note : '';
      final snippet = newNote.length > _timelineValueMaxLength
          ? '${newNote.substring(0, _timelineValueMaxLength)}...'
          : newNote;
      events.add(
        TaskTimelineEvent(
          type: 'note_added',
          label: 'timeline.comment_added',
          newValue: snippet.isEmpty ? null : snippet,
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

  String getExtension(String fileName) {
    return fileName.split('.').last;
  }

  RxDouble uploadProgress = 0.0.obs;
  RxBool isUploading = false.obs;
  Future<String?> uploadFiles({
    required dynamic filePathOrBytes,
    String? fileName,
    bool useBlockingUploadDialog = true,

    /// When set, Supabase public URL gets `?download=` so browsers save under this name.
    String? friendlyDownloadName,
  }) async {
    final uuid = Uuid();
    var dialogShown = false;
    try {
      final bytes = filePathOrBytes as Uint8List;
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

      if (useBlockingUploadDialog) {
        showUploadDialog();
        dialogShown = true;
      }

      final bucket = supabase.storage.from('point');
      final uniqueName = "${uuid.v1()}.${getExtension(fileName ?? '')}";

      await uploadStorageObjectBinary(
        supabase: supabase,
        bucketId: 'point',
        objectPath: uniqueName,
        data: bytes,
        mimeLookupPath: fileName,
        onProgress: (sent, total) {
          if (total > 0) {
            uploadProgress.value = sent / total;
          }
        },
      );

      uploadProgress.value = 1.0;

      var url = bucket.getPublicUrl(uniqueName);
      if (friendlyDownloadName != null &&
          friendlyDownloadName.trim().isNotEmpty) {
        url = appendSupabaseStorageDownloadQuery(
          url,
          friendlyDownloadName.trim(),
        );
      }

      uploadedFilesPaths.add(url);

      isUploading.value = false;
      if (dialogShown) {
        Get.back();
      }

      return url;
    } catch (e) {
      isUploading.value = false;
      if (dialogShown) {
        Get.back();
      }
      appLog("Error uploading file: $e");
      return null;
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
    syncActiveDepartmentFilterFromEmployee(employee);
    final role = employee.role.trim().toLowerCase();
    if (role == 'admin' || role == 'supervisor') {
      unawaited(BackfillEmployeeDepartments.runIfNeeded(isManager: true));
    }
    fetchEmployees();
    _rebindClientsAndTasksStreams();
    fetchContents();
    fetchMetaPosts();
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
              final base = EmployeeModel.fromJson(snapshot.data()!);
              final employee = base.copyWith(id: empid);
              final previous = currentEmployee.value;
              final profileChanged = !_sameEmployeeProfileCore(
                previous,
                employee,
              );
              if (profileChanged) {
                currentEmployee.value = employee;
                lastKnownEmployee.value = employee;
                syncActiveDepartmentFilterFromEmployee(employee);
                unawaited(FirestoreServices.syncAuthRoleForEmployee(employee));
                _startTotalUnreadStream(empid);
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
  var contents = <ContentModel>[].obs;
  var metaPosts = <MetaPostModel>[].obs;
  var searchedContents = <ContentModel>[].obs;

  /// تصفية قائمة المحتوى في واجهة موظف الويب (مثل شاشة المهام).
  final TextEditingController employeeWebContentSearchController =
      TextEditingController();
  final RxString employeeWebContentStatusFilter = ''.obs;
  final RxString employeeWebContentTypeFilter = ''.obs;
  final Rxn<DateTime> employeeWebContentDateFilter = Rxn<DateTime>();
  final RxSet<String> selectedContentIds = <String>{}.obs;

  RxString selectedDate = ''.obs;
  var notifications = <NotificationModel>[].obs;
  var tasks = <TaskModel>[].obs;
  var isLoading = false.obs;

  /// Total unread messages across all chats (for header badge).
  RxInt totalUnreadMessages = 0.obs;
  StreamSubscription<int>? _totalUnreadSub;
  String? _totalUnreadUserId;
  StreamSubscription<String>? _fcmTokenRefreshSub;
  StreamSubscription<Map<String, DateTime>>? _employeePresenceSub;
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
    if (id.isEmpty) return;
    await _service.syncEmployeePresenceHeartbeat(id);
  }

  void _startPresenceHeartbeatForEmployee(String employeeId) {
    final id = employeeId.trim();
    if (id.isEmpty) return;
    if (_presenceHeartbeatEmployeeId == id && _presenceHeartbeatTimer != null) {
      return;
    }
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
    _presenceHeartbeatEmployeeId = id;
    unawaited(_sendPresenceHeartbeat(id));
    _presenceHeartbeatTimer = Timer.periodic(_presenceHeartbeatInterval, (_) {
      unawaited(_sendPresenceHeartbeat(id));
    });
  }

  void _stopPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
    _presenceHeartbeatEmployeeId = null;
  }

  void handleAppLifecycleResumed() {
    final id = currentEmployee.value?.id?.trim();
    if (id == null || id.isEmpty) return;
    _startPresenceHeartbeatForEmployee(id);
  }

  void _startEmployeePresenceStream() {
    _employeePresenceSub?.cancel();
    _employeePresenceSub = null;
    // employee_presence rules require isSignedIn() && hasAuthRole() — do not
    // subscribe on the login screen (see HomeController.onInit).
    if (FirebaseAuth.instance.currentUser == null) {
      employeePresenceById.clear();
      return;
    }
    _employeePresenceSub = _service.getEmployeePresenceMap().listen(
      (map) {
        employeePresenceById.assignAll(map);
      },
      onError: (Object e, StackTrace st) {
        appLog('employee_presence stream: $e');
        appLog('$st');
      },
    );
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
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Obx(() {
                final p = uploadProgress.value.clamp(0.0, 1.0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: p,
                        minHeight: 8,
                        backgroundColor: AppColors.greylight,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${(p * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryfontColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'common.uploading'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.fontColorGrey,
                      ),
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
    fetchEmployees();
    _rebindClientsAndTasksStreams();
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
    employeeWebContentSearchController.dispose();
    _employeeDocSub?.cancel();
    _employeeDocSub = null;
    _stopPresenceHeartbeat();
    _stopTotalUnreadStream();
    _fcmTokenRefreshSub?.cancel();
    _fcmTokenRefreshSub = null;
    _employeePresenceSub?.cancel();
    _employeePresenceSub = null;
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
    _employeeDocSub?.cancel();
    _employeeDocSub = null;
    _stopPresenceHeartbeat();
    _stopTotalUnreadStream();
    _employeePresenceSub?.cancel();
    _employeePresenceSub = null;
    employeePresenceById.clear();
    employees.bindStream(Stream<List<EmployeeModel>>.value([]));
    clients.bindStream(Stream<List<ClientModel>>.value([]));
    contents.bindStream(Stream<List<ContentModel>>.value([]));
    tasks.bindStream(Stream<List<TaskModel>>.value([]));
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
