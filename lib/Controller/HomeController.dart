import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/AudioService.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class HomeController extends GetxController {
  final FirestoreServices _service = FirestoreServices();
  FirestoreServices get service => _service;
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

  // RxList<TaskModel> allTasks = <TaskModel>[].obs;
  RxList<TaskModel> tasksSearched = <TaskModel>[].obs;

  /// قائمة المهام المنتهية لصفحة سجل المهام
  RxList<TaskModel> tasksHistory = <TaskModel>[].obs;

  void filterTasks() {
    final searchText = searchController.text.trim().toLowerCase();

    // إن كانت الحالة المختارة منتهية (غير موجودة في قائمة الجارية) نُعيدها فارغة
    if (selectedStatus.value.isNotEmpty &&
        !StorageKeys.statusListOngoing.contains(selectedStatus.value)) {
      selectedStatus.value = '';
    }

    // نعرض فقط المهام الجارية دائماً
    List<TaskModel> baseList =
        tasks.where((t) => StorageKeys.isOngoingStatus(t.status)).toList();

    // إن وُجد فلتر حالة محددة (إحدى الحالات الجارية) نطبّقها
    if (selectedStatus.value.isNotEmpty) {
      baseList =
          baseList
              .where(
                (t) =>
                    t.status.toLowerCase() ==
                    selectedStatus.value.toLowerCase(),
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

    // تطبيق فلتر المنفذ (تحويل الاسم إلى id إن لزم)
    String? executorId;
    if (selectedExecutor.value.isNotEmpty) {
      final matchUser = employees.firstWhereOrNull(
        (u) => u.name!.toLowerCase() == selectedExecutor.value.toLowerCase(),
      );
      executorId = matchUser?.id;
    }

    tasksSearched.assignAll(
      baseList.where((task) {
        final title = (task.title).toLowerCase();
        final assigned = (task.assignedTo).toLowerCase();
        final priority = (task.priority).toLowerCase();

        final matchSearch =
            searchText.isEmpty
                ? true
                : (title.contains(searchText) ||
                    employees.any(
                      (u) =>
                          u.name!.toLowerCase().contains(searchText) &&
                          u.id == task.assignedTo,
                    ));

        final matchPriority =
            selectedPriority.value.isEmpty
                ? true
                : priority == selectedPriority.value.toLowerCase();

        final matchExecutor =
            selectedExecutor.value.isEmpty
                ? true
                : assigned == executorId?.toLowerCase();

        return matchSearch && matchPriority && matchExecutor;
      }).toList(),
    );
  }

  void filterTasksHistory() {
    final searchText = searchController.text.trim().toLowerCase();

    List<TaskModel> baseList =
        tasks.where((t) => StorageKeys.isEndedStatus(t.status)).toList();

    if (selectedStatus.value.isNotEmpty &&
        StorageKeys.statusListEnded.contains(selectedStatus.value)) {
      baseList =
          baseList
              .where(
                (t) =>
                    t.status.toLowerCase() ==
                    selectedStatus.value.toLowerCase(),
              )
              .toList();
    }

    if (searchText.isEmpty &&
        selectedPriority.value.isEmpty &&
        selectedExecutor.value.isEmpty) {
      tasksHistory.assignAll(baseList);
      return;
    }

    String? executorId;
    if (selectedExecutor.value.isNotEmpty) {
      final matchUser = employees.firstWhereOrNull(
        (u) => u.name!.toLowerCase() == selectedExecutor.value.toLowerCase(),
      );
      executorId = matchUser?.id;
    }

    tasksHistory.assignAll(
      baseList.where((task) {
        final title = (task.title).toLowerCase();
        final assigned = (task.assignedTo).toLowerCase();
        final priority = (task.priority).toLowerCase();

        final matchSearch =
            searchText.isEmpty
                ? true
                : (title.contains(searchText) ||
                    employees.any(
                      (u) =>
                          u.name!.toLowerCase().contains(searchText) &&
                          u.id == task.assignedTo,
                    ));

        final matchPriority =
            selectedPriority.value.isEmpty
                ? true
                : priority == selectedPriority.value.toLowerCase();

        final matchExecutor =
            selectedExecutor.value.isEmpty
                ? true
                : assigned == executorId?.toLowerCase();

        return matchSearch && matchPriority && matchExecutor;
      }).toList(),
    );
  }

  fetchEmployees() {
    employees.bindStream(_service.getEmployees());

    update();
  }

  fetchClients() {
    clients.bindStream(_service.getClientsStream());

    update();
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
    final result =
        existing == null
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

  Future<bool> deleteEmployee(String id) async {
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
    final result =
        existing == null
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
    }
    return result;
  }

  void fetchContents() {
    contents.bindStream(_service.getContents());
  }

  void refreshFilteredContents({String? clientId, bool onlyUpcoming = false}) {
    final selectedClientId = (clientId ?? clientController.text).trim();
    if (selectedClientId.isEmpty) {
      searchedContents.clear();
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
  }

  fetchnotification(String? id) {
    notifications.bindStream(
      _service.getNotifications(id ?? currentemployee.value!.id!, 'all'),
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

  void fetchTasks() {
    tasks.bindStream(_service.getTasks());
    update();
  }

  Future<bool> addTask(TaskModel task) async {
    isLoading.value = true;
    final emp = currentemployee.value;
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
    if (result && oldTask != null) {
      unawaited(_triggerTaskNotifications(oldTask, taskToSave));
    }
    return result;
  }

  Future<void> _triggerTaskNotifications(
    TaskModel oldTask,
    TaskModel newTask,
  ) async {
    final emp = currentemployee.value;
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
        );
      }
      if (isUpdateByAssignee) {
        if (newTask.status == StorageKeys.status_processing) {
          await NotificationService.notifyManagersTaskReceivedByEmployee(
            employeeName: assigneeName,
            taskTitle: newTask.title,
          );
        } else if (newTask.status == StorageKeys.status_ready_to_publish ||
            newTask.status == StorageKeys.status_under_revision) {
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
      if (newTask.status == StorageKeys.status_edit_requested &&
          assigneeId.isNotEmpty) {
        await NotificationService.notifyEmployeeEditRequestedByManagement(
          employeeId: assigneeId,
          taskTitle: newTask.title,
        );
      }
      final wasEnded = StorageKeys.isEndedStatus(oldTask.status);
      final isNowOngoing = StorageKeys.isOngoingStatus(newTask.status);
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
      final addedNotes =
          newTask.notes.length > oldTask.notes.length;
      final addedFiles =
          newTask.files.length > oldTask.files.length;
      final editKind =
          addedNotes && addedFiles
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
        oldValue:
            _formatTimelineValue(oldVal).isEmpty
                ? null
                : _formatTimelineValue(oldVal),
        newValue:
            _formatTimelineValue(newVal).isEmpty
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
    final emp = currentemployee.value;
    final userId = emp?.id ?? '';
    final userName = emp?.name ?? 'system.user';
    final now = DateTime.now();
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
          timestamp: now,
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
      now,
      fieldKey: 'title',
    );
    _addIfChanged(
      events,
      'تم تغيير الوصف',
      oldTask.description,
      newTask.description,
      userId,
      userName,
      now,
      fieldKey: 'description',
    );
    final normalizedOldProgress = _normalizeProgressStep(oldTask.progress);
    final normalizedNewProgress = _normalizeProgressStep(newTask.progress);
    if (normalizedOldProgress != normalizedNewProgress) {
      final oldP =
          normalizedOldProgress != null
              ? '${(normalizedOldProgress * 100).round()}%'
              : '';
      final newP =
          normalizedNewProgress != null
              ? '${(normalizedNewProgress * 100).round()}%'
              : '';
      _addIfChanged(
        events,
        'تم تغيير التقدم',
        oldP,
        newP,
        userId,
        userName,
        now,
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
      now,
      fieldKey: 'clientName',
    );
    _addIfChanged(
      events,
      'تم تغيير نص الإجراء',
      oldTask.actionText,
      newTask.actionText,
      userId,
      userName,
      now,
      fieldKey: 'actionText',
    );
    _addIfChanged(
      events,
      'تم تغيير النوع',
      oldTask.type,
      newTask.type,
      userId,
      userName,
      now,
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
          timestamp: now,
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
          timestamp: now,
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
          timestamp: now,
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
          timestamp: now,
        ),
      );
    }
    if (newTask.notes.length > oldTask.notes.length) {
      final newNote = newTask.notes.isNotEmpty ? newTask.notes.last.note : '';
      final snippet =
          newNote.length > _timelineValueMaxLength
              ? '${newNote.substring(0, _timelineValueMaxLength)}...'
              : newNote;
      events.add(
        TaskTimelineEvent(
          type: 'note_added',
          label: 'تم إضافة ملاحظة',
          newValue: snippet.isEmpty ? null : snippet,
          byUserId: userId,
          byUserName: userName,
          timestamp: now,
        ),
      );
    }
    if (newTask.files.length > oldTask.files.length) {
      final lastFile =
          newTask.files.isNotEmpty ? newTask.files.last.toString() : '';
      events.add(
        TaskTimelineEvent(
          type: 'attachment_added',
          label: 'تم إضافة مرفق',
          newValue: lastFile.isEmpty ? null : lastFile,
          byUserId: userId,
          byUserName: userName,
          timestamp: now,
        ),
      );
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
        now,
        fieldKey: 'designDetails.taskType',
      );
      _addIfChanged(
        events,
        'تم تغيير المنصة (التصميم)',
        oldD?.platform,
        newD?.platform,
        userId,
        userName,
        now,
        fieldKey: 'designDetails.platform',
      );
      _addIfChanged(
        events,
        'تم تغيير نوع التصميم',
        oldD?.designType,
        newD?.designType,
        userId,
        userName,
        now,
        fieldKey: 'designDetails.designType',
      );
      _addIfChanged(
        events,
        'تم تغيير عدد التصاميم (التصميم)',
        oldD?.designCount,
        newD?.designCount,
        userId,
        userName,
        now,
        fieldKey: 'designDetails.designCount',
      );
      _addIfChanged(
        events,
        'تم تغيير القياسات (التصميم)',
        oldD?.designsDimensions,
        newD?.designsDimensions,
        userId,
        userName,
        now,
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
        now,
        fieldKey: 'contentWriteModel.platform',
      );
      _addIfChanged(
        events,
        'تم تغيير نوع المحتوى',
        oldCw?.contenttype,
        newCw?.contenttype,
        userId,
        userName,
        now,
        fieldKey: 'contentWriteModel.contenttype',
      );
      _addIfChanged(
        events,
        'تم تغيير عدد التصاميم (المحتوى)',
        oldCw?.designCount,
        newCw?.designCount,
        userId,
        userName,
        now,
        fieldKey: 'contentWriteModel.designCount',
      );
      _addIfChanged(
        events,
        'تم تغيير القياسات (المحتوى)',
        oldCw?.designsDimensions,
        newCw?.designsDimensions,
        userId,
        userName,
        now,
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
        now,
        fieldKey: 'photoGrapghyModel.shootingtype',
      );
      _addIfChanged(
        events,
        'تم تغيير المنصة (التصوير)',
        oldPh?.platform,
        newPh?.platform,
        userId,
        userName,
        now,
        fieldKey: 'photoGrapghyModel.platform',
      );
      _addIfChanged(
        events,
        'تم تغيير موقع التصوير',
        oldPh?.shootinglocation,
        newPh?.shootinglocation,
        userId,
        userName,
        now,
        fieldKey: 'photoGrapghyModel.shootinglocation',
      );
      _addIfChanged(
        events,
        'تم تغيير عدد التصاميم (التصوير)',
        oldPh?.designCount,
        newPh?.designCount,
        userId,
        userName,
        now,
        fieldKey: 'photoGrapghyModel.designCount',
      );
      _addIfChanged(
        events,
        'تم تغيير المدة (التصوير)',
        oldPh?.duration,
        newPh?.duration,
        userId,
        userName,
        now,
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
        now,
        fieldKey: 'monatageModel.category',
      );
      _addIfChanged(
        events,
        'تم تغيير المنصة (المونتاج)',
        oldMo?.platform,
        newMo?.platform,
        userId,
        userName,
        now,
        fieldKey: 'monatageModel.platform',
      );
      _addIfChanged(
        events,
        'تم تغيير الأبعاد (المونتاج)',
        oldMo?.dimentioans,
        newMo?.dimentioans,
        userId,
        userName,
        now,
        fieldKey: 'monatageModel.dimentioans',
      );
      _addIfChanged(
        events,
        'تم تغيير رابط المرفق (المونتاج)',
        oldMo?.attachementurl,
        newMo?.attachementurl,
        userId,
        userName,
        now,
        fieldKey: 'monatageModel.attachementurl',
      );
      _addIfChanged(
        events,
        'تم تغيير المدة (المونتاج)',
        oldMo?.duration,
        newMo?.duration,
        userId,
        userName,
        now,
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
        now,
        fieldKey: 'publishModel.contenturl',
      );
      _addIfChanged(
        events,
        'تم تغيير المنصة (النشر)',
        oldPu?.platform,
        newPu?.platform,
        userId,
        userName,
        now,
        fieldKey: 'publishModel.platform',
      );
      _addIfChanged(
        events,
        'تم تغيير التصنيف (النشر)',
        oldPu?.category,
        newPu?.category,
        userId,
        userName,
        now,
        fieldKey: 'publishModel.category',
      );
      _addIfChanged(
        events,
        'تم تغيير رابط الملف (النشر)',
        oldPu?.fileurl,
        newPu?.fileurl,
        userId,
        userName,
        now,
        fieldKey: 'publishModel.fileurl',
      );
      _addIfChanged(
        events,
        'تم تغيير القياسات (النشر)',
        oldPu?.designsDimensions,
        newPu?.designsDimensions,
        userId,
        userName,
        now,
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
        now,
        fieldKey: 'programmingModel.contenturl',
      );
      _addIfChanged(
        events,
        'تم تغيير التصنيف (البرمجة)',
        oldPr?.category,
        newPr?.category,
        userId,
        userName,
        now,
        fieldKey: 'programmingModel.category',
      );
      _addIfChanged(
        events,
        'تم تغيير رابط الملف (البرمجة)',
        oldPr?.fileurl,
        newPr?.fileurl,
        userId,
        userName,
        now,
        fieldKey: 'programmingModel.fileurl',
      );
      _addIfChanged(
        events,
        'تم تغيير القياسات (البرمجة)',
        oldPr?.designsDimensions,
        newPr?.designsDimensions,
        userId,
        userName,
        now,
        fieldKey: 'programmingModel.designsDimensions',
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
        now,
        fieldKey: 'promotionModel.name',
      );
      _addIfChanged(
        events,
        'تم تغيير الهدف (الترويج)',
        oldPromo?.target,
        newPromo?.target,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.target',
      );
      _addIfChanged(
        events,
        'تم تغيير اسم الحملة',
        oldPromo?.campaignName,
        newPromo?.campaignName,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.campaignName',
      );
      _addIfChanged(
        events,
        'تم تغيير النوع (الترويج)',
        oldPromo?.type,
        newPromo?.type,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.type',
      );
      _addIfChanged(
        events,
        'تم تغيير الأولوية (الترويج)',
        oldPromo?.priority,
        newPromo?.priority,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.priority',
      );
      _addIfChanged(
        events,
        'تم تغيير الحالة (الترويج)',
        oldPromo?.status,
        newPromo?.status,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.status',
      );
      _addIfChanged(
        events,
        'تم تغيير الوصف (الترويج)',
        oldPromo?.description,
        newPromo?.description,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.description',
      );
      _addIfChanged(
        events,
        'تم تغيير المنفذ (الترويج)',
        oldPromo?.executorId,
        newPromo?.executorId,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.executorId',
      );
      _addIfChanged(
        events,
        'تم تغيير تاريخ البداية (الترويج)',
        oldPromo?.startDate,
        newPromo?.startDate,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.startDate',
      );
      _addIfChanged(
        events,
        'تم تغيير تاريخ النهاية (الترويج)',
        oldPromo?.endDate,
        newPromo?.endDate,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.endDate',
      );
      _addIfChanged(
        events,
        'تم تغيير المدة (الترويج)',
        oldPromo?.duration,
        newPromo?.duration,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.duration',
      );
      _addIfChanged(
        events,
        'تم تغيير العلامات (الترويج)',
        oldPromo?.tags,
        newPromo?.tags,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.tags',
      );
      _addIfChanged(
        events,
        'تم تغيير المنصات (الترويج)',
        oldPromo?.platforms,
        newPromo?.platforms,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.platforms',
      );
      _addIfChanged(
        events,
        'تم تغيير الاهتمامات',
        oldPromo?.interests,
        newPromo?.interests,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.interests',
      );
      _addIfChanged(
        events,
        'تم تغيير المدن',
        oldPromo?.cities,
        newPromo?.cities,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.cities',
      );
      _addIfChanged(
        events,
        'تم تغيير الدول',
        oldPromo?.countries,
        newPromo?.countries,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.countries',
      );
      _addIfChanged(
        events,
        'تم تغيير التخصصات',
        oldPromo?.specializations,
        newPromo?.specializations,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.specializations',
      );
      _addIfChanged(
        events,
        'تم تغيير الفئات العمرية',
        oldPromo?.ageRanges,
        newPromo?.ageRanges,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.ageRanges',
      );
      _addIfChanged(
        events,
        'تم تغيير الملاحظات (الترويج)',
        oldPromo?.notes,
        newPromo?.notes,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.notes',
      );
      _addIfChanged(
        events,
        'تم تغيير رابط المرفق (الترويج)',
        oldPromo?.attachementurl,
        newPromo?.attachementurl,
        userId,
        userName,
        now,
        fieldKey: 'promotionModel.attachementurl',
      );
    }

    return events;
  }

  Future<bool> deleteTask(String id) async {
    isLoading.value = true;
    final result = await _service.deleteTask(id);
    isLoading.value = false;
    return result;
  }

  RxList<dynamic> uploadedFilesPaths = [].obs;
  Future<List<PlatformFile>> pickMultiFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    log('Picked files: ${result?.files.map((e) => e.name).toList()}');

    if (result != null && result.files.isNotEmpty) {
      return result.files;
    } else {
      return [];
    }
  }

  Future<List<PlatformFile>> pickoneImage() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.image,
    );
    log('Picked files: ${result?.files.map((e) => e.name).toList()}');

    if (result != null && result.files.isNotEmpty) {
      return result.files;
    } else {
      return [];
    }
  }

  String getExtension(String fileName) {
    return fileName.split('.').last;
  }

  RxDouble uploadProgress = 0.0.obs;
  RxBool isUploading = false.obs;
  Future<String?> uploadFiles({
    required dynamic filePathOrBytes,
    String? fileName,
  }) async {
    final uuid = Uuid();
    Timer? uploadProgressTimer;
    try {
      isUploading.value = true;
      uploadProgress.value = 0.0;

      showUploadDialog();

      final bucket = supabase.storage.from('point');
      final uniqueName = "${uuid.v1()}.${getExtension(fileName ?? '')}";

      final bytes = filePathOrBytes as Uint8List;

      // حركة تقدم تقريبية أثناء الرفع (Supabase لا يعرض progress حقيقي)
      uploadProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) {
        if (uploadProgress.value >= 0.95) {
          timer.cancel();
        } else {
          uploadProgress.value += 0.05;
        }
      });

      await bucket.uploadBinary(uniqueName, bytes);

      uploadProgress.value = 1.0;

      final url = bucket.getPublicUrl(uniqueName);

      uploadedFilesPaths.add(url);

      isUploading.value = false;
      Get.back();

      return url;
    } catch (e) {
      isUploading.value = false;
      Get.back();
      log("Error uploading file: $e");
      return null;
    } finally {
      uploadProgressTimer?.cancel();
    }
  }

  Future<EmployeeModel?> loginClient(email, pass) async {
    isLoading.value = true;
    final result = await _service.loginEmployee(email, pass);
    // يجب تعبئة الجلسة هنا فورًا: AuthMiddleware يعتمد على currentemployee قبل التنقل،
    // بينما listenToClient يحدّثه فقط عند وصول أول snapshot من Firestore (متأخر عن أول إطار).
    if (result != null && result.id != null) {
      currentemployee.value = result;
      lastKnownEmployee.value = result;
      _startTotalUnreadStream(result.id!);
      listenToClient(result.id!);
      fetchnotification(result.id);
    }
    isLoading.value = false;
    return result;
  }

  final _clientCollection = FirebaseFirestore.instance.collection("employees");
  Rxn<EmployeeModel> currentemployee = Rxn<EmployeeModel>();
  Rxn<EmployeeModel> lastKnownEmployee = Rxn<EmployeeModel>();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _employeeDocSub;
  EmployeeModel? get effectiveEmployee =>
      currentemployee.value ?? lastKnownEmployee.value;

  void listenToClient(String empid) async {
    _employeeDocSub?.cancel();
    _employeeDocSub = _clientCollection.doc(empid).snapshots().listen(
      (snapshot) async {
        if (snapshot.exists && snapshot.data() != null) {
          final employee = EmployeeModel.fromJson(snapshot.data()!);
          currentemployee.value = employee;
          lastKnownEmployee.value = employee;
          _startTotalUnreadStream(empid);
        }
      },
      onError: (e, s) {
        log('listenToClient stream error for $empid: $e');
      },
    );
    fetchContents();
    // fetchnotification(currentemployee.value?.id);
  }

  var employees = <EmployeeModel>[].obs;
  var clients = <ClientModel>[].obs;
  var contents = <ContentModel>[].obs;
  var searchedContents = <ContentModel>[].obs;
  RxString selectedDate = ''.obs;
  var notifications = <NotificationModel>[].obs;
  var tasks = <TaskModel>[].obs;
  var isLoading = false.obs;

  /// Total unread messages across all chats (for header badge).
  RxInt totalUnreadMessages = 0.obs;
  StreamSubscription<int>? _totalUnreadSub;

  void _startTotalUnreadStream(String userId) {
    _totalUnreadSub?.cancel();
    _totalUnreadSub = _service
        .getTotalUnreadMessagesStream(
          userId,
          onPerChatUnreadIncrease: (chatId) {
            unawaited(
              AudioService.instance.playNotificationSound(chatId: chatId),
            );
          },
        )
        .listen((count) => totalUnreadMessages.value = count);
  }

  void _stopTotalUnreadStream() {
    _totalUnreadSub?.cancel();
    _totalUnreadSub = null;
    totalUnreadMessages.value = 0;
  }

  setupFCM(userId) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. طلب الإذن
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');

        // 2. الحصول على التوكن (على الويب قد يفشل لغياب Service Worker / إعدادات المشروع)
        // لا نستخدم VAPID — getToken بدون vapidKey
        String? token = await messaging.getToken();
        if (token != null && currentemployee.value != null) {
          updateEmployee(currentemployee.value!.copyWith(fcmToken: token));
          print("FCM Registration Token: ${kIsWeb ? 'Web' : ''} $token");
        }

        // 3. الاستماع لرسائل المقدمة (عندما يكون التطبيق مفتوحًا)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('Got a message whilst in the foreground!');
        });
      } else {
        print('User declined or has not yet granted permission');
      }
    } catch (e) {
      // على الويب: token-subscribe-failed شائع لغياب OAuth/Service Worker
      log('setupFCM: $e');
      if (kIsWeb) debugPrint('FCM on web may need service worker / OAuth: $e');
      // #endregion
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
    fetchClients();
    fetchContents();
    ever(contents, (_) => refreshFilteredContents());
    fetchTasks();
    ever(tasks, (_) {
      filterTasks();
      filterTasksHistory();
    });
    _restoreEmployeeSessionIfNeeded();
    super.onInit();
  }

  @override
  void onClose() {
    _employeeDocSub?.cancel();
    _employeeDocSub = null;
    _stopTotalUnreadStream();
    super.onClose();
  }

  Future<void> _restoreEmployeeSessionIfNeeded() async {
    // Avoid re-login when already hydrated (normal in-app navigation).
    if (effectiveEmployee != null) return;

    try {
      final pref = await SharedPreferences.getInstance();
      final isLoggedIn = (pref.getBool('isLoggedIn') ?? false) == true;
      if (!isLoggedIn) return;

      // على الويب تُستعاد جلسة Firebase من IndexedDB بشكل غير متزامن؛
      // استدعاء getCurrentEmployeeByAuth() مباشرة بعد التحديث غالبًا يجد currentUser == null.
      if (kIsWeb) {
        await _waitForFirebaseAuthHydrationOnWeb();
      }

      final employee = await _service.getCurrentEmployeeByAuth();
      if (employee == null || employee.id == null) return;
      if (employee.status != 'active') return;

      // Keep employee state alive after browser refresh/deep-link.
      currentemployee.value = employee;
      lastKnownEmployee.value = employee;
      _startTotalUnreadStream(employee.id!);
      fetchnotification(employee.id);
      listenToClient(employee.id!);
      unawaited(setupFCM(employee.id));

      // بعد التحديث المسار الابتدائي للويب هو /auth/login حتى مع جلسة صالحة.
      if (kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeNavigateWebToDashboardAfterRestore(employee);
        });
      }
    } catch (e, s) {
      log('restoreEmployeeSessionIfNeeded error: $e');
      log('StackTrace: $s');
    }
  }

  /// انتظار اكتمال تهيئة Firebase Auth بعد تحديث الصفحة (ويب فقط).
  Future<void> _waitForFirebaseAuthHydrationOnWeb() async {
    if (FirebaseAuth.instance.currentUser != null) return;
    try {
      await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 1));
    } catch (_) {
      // نكمل بالاستعلام عن currentUser أدناه.
    }
    for (var i = 0; i < 80; i++) {
      if (FirebaseAuth.instance.currentUser != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void _maybeNavigateWebToDashboardAfterRestore(EmployeeModel employee) {
    final route = Get.currentRoute;
    if (route == '/' || route == '/employeeDashboard') return;
    _offAllNamedToRoleHome(employee);
  }

  void _offAllNamedToRoleHome(EmployeeModel employee) {
    final role = employee.role;
    if (role == 'employee') {
      Get.offAllNamed('/employeeDashboard');
    } else {
      Get.offAllNamed('/');
    }
  }

  void clearEmployeeSession() {
    currentemployee.value = null;
    lastKnownEmployee.value = null;
    _stopTotalUnreadStream();
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
