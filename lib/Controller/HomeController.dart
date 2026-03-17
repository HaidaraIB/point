import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/NotificationService.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class HomeController extends GetxController {
  final FirestoreServices _service = FirestoreServices();
  int selectedIndex = 0;

  var clientController = TextEditingController();
  RxString selectedTypeNotifications = 'clients'.obs; // clients, employees, all
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
      baseList = baseList
          .where((t) =>
              t.status.toLowerCase() == selectedStatus.value.toLowerCase())
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

    tasksSearched.assignAll(baseList.where((task) {
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
    }).toList());
  }

  void filterTasksHistory() {
    final searchText = searchController.text.trim().toLowerCase();

    List<TaskModel> baseList =
        tasks.where((t) => StorageKeys.isEndedStatus(t.status)).toList();

    if (selectedStatus.value.isNotEmpty &&
        StorageKeys.statusListEnded.contains(selectedStatus.value)) {
      baseList = baseList
          .where((t) =>
              t.status.toLowerCase() == selectedStatus.value.toLowerCase())
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

    tasksHistory.assignAll(baseList.where((task) {
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
    }).toList());
  }

  fetchEmployees() {
    employees.bindStream(_service.getEmployees());

    update();
  }

  fetchClients() {
    clients.bindStream(_service.getClientsStream());

    update();
  }

  Future<bool> addEmployee(EmployeeModel employee) async {
    isLoading.value = true;
    final result = await _service.addEmployee(employee);
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

  Future<bool> updateEmployee(EmployeeModel employee) async {
    isLoading.value = true;
    final result = await _service.updateEmployee(employee);
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

  Future<bool> addClient(ClientModel client) async {
    isLoading.value = true;
    final result = await _service.addClient(client);
    isLoading.value = false;
    return result;
  }

  Future<bool> updateClient(ClientModel client) async {
    isLoading.value = true;
    final result = await _service.updateClient(client);
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
      byUserName: emp?.name ?? 'نظام',
      timestamp: DateTime.now(),
    );
    final taskWithTimeline = task.copyWith(
      timelineEvents: [createdEvent],
    );
    final result = await _service.addTask(taskWithTimeline);
    isLoading.value = false;
    if (result && task.assignedTo.trim().isNotEmpty) {
      unawaited(NotificationService.notifyEmployeeAssignedToTask(
        employeeId: task.assignedTo,
        taskTitle: task.title,
      ));
      unawaited(NotificationService.notifyManagersNewTaskInDepartment(
        taskTitle: task.title,
        departmentNameAr: NotificationService.departmentNameFromTaskType(task.type),
      ));
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

  Future<void> _triggerTaskNotifications(TaskModel oldTask, TaskModel newTask) async {
    final emp = currentemployee.value;
    final assigneeId = newTask.assignedTo.trim();
    final assigneeName = employees.firstWhereOrNull((e) => e.id == assigneeId)?.name ?? assigneeId;
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
      if (newTask.status == StorageKeys.status_rejected && assigneeId.isNotEmpty) {
        await NotificationService.notifyEmployeeTaskRejected(
          employeeId: assigneeId,
          taskTitle: newTask.title,
        );
      }
      if (newTask.status == StorageKeys.status_edit_requested && assigneeId.isNotEmpty) {
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
      await NotificationService.notifyManagersEmployeeEditedTask(
        employeeName: assigneeName,
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
    events.add(TaskTimelineEvent(
      type: 'field_changed',
      label: label,
      oldValue: _formatTimelineValue(oldVal).isEmpty ? null : _formatTimelineValue(oldVal),
      newValue: _formatTimelineValue(newVal).isEmpty ? null : _formatTimelineValue(newVal),
      byUserId: userId,
      byUserName: userName,
      timestamp: now,
      fieldKey: fieldKey,
    ));
  }

  List<TaskTimelineEvent> _buildTimelineEvents(TaskModel oldTask, TaskModel newTask) {
    final emp = currentemployee.value;
    final userId = emp?.id ?? '';
    final userName = emp?.name ?? 'نظام';
    final now = DateTime.now();
    final List<TaskTimelineEvent> events = [];

    // --- الحقول الأساسية للمهمة ---
    if (oldTask.assignedTo != newTask.assignedTo) {
      final oldName = employees.firstWhereOrNull((e) => e.id == oldTask.assignedTo)?.name ?? oldTask.assignedTo;
      final newName = employees.firstWhereOrNull((e) => e.id == newTask.assignedTo)?.name ?? newTask.assignedTo;
      events.add(TaskTimelineEvent(
        type: 'executor_changed',
        label: 'تم تغيير المنفذ',
        oldValue: oldName,
        newValue: newName,
        byUserId: userId,
        byUserName: userName,
        timestamp: now,
      ));
    }
    _addIfChanged(events, 'تم تغيير العنوان', oldTask.title, newTask.title, userId, userName, now, fieldKey: 'title');
    _addIfChanged(events, 'تم تغيير الوصف', oldTask.description, newTask.description, userId, userName, now, fieldKey: 'description');
    if (oldTask.progress != newTask.progress) {
      final oldP = oldTask.progress != null ? '${(oldTask.progress! * 100).round()}%' : '';
      final newP = newTask.progress != null ? '${(newTask.progress! * 100).round()}%' : '';
      _addIfChanged(events, 'تم تغيير التقدم', oldP, newP, userId, userName, now, fieldKey: 'progress');
    }
    _addIfChanged(events, 'تم تغيير اسم العميل', oldTask.clientName, newTask.clientName, userId, userName, now, fieldKey: 'clientName');
    _addIfChanged(events, 'تم تغيير نص الإجراء', oldTask.actionText, newTask.actionText, userId, userName, now, fieldKey: 'actionText');
    _addIfChanged(events, 'تم تغيير النوع', oldTask.type, newTask.type, userId, userName, now, fieldKey: 'type');
    if (oldTask.fromDate != newTask.fromDate) {
      events.add(TaskTimelineEvent(
        type: 'from_date_changed',
        label: 'تم تغيير تاريخ البداية',
        oldValue: _formatTimelineValue(oldTask.fromDate),
        newValue: _formatTimelineValue(newTask.fromDate),
        byUserId: userId,
        byUserName: userName,
        timestamp: now,
      ));
    }
    if (oldTask.toDate != newTask.toDate) {
      events.add(TaskTimelineEvent(
        type: 'to_date_changed',
        label: 'تم تغيير تاريخ النهاية',
        oldValue: _formatTimelineValue(oldTask.toDate),
        newValue: _formatTimelineValue(newTask.toDate),
        byUserId: userId,
        byUserName: userName,
        timestamp: now,
      ));
    }
    if (oldTask.priority != newTask.priority) {
      events.add(TaskTimelineEvent(
        type: 'priority_changed',
        label: 'تم تغيير الأولوية',
        oldValue: oldTask.priority,
        newValue: newTask.priority,
        byUserId: userId,
        byUserName: userName,
        timestamp: now,
      ));
    }
    if (oldTask.status != newTask.status) {
      events.add(TaskTimelineEvent(
        type: 'status_changed',
        label: 'تم تغيير الحالة',
        oldValue: oldTask.status,
        newValue: newTask.status,
        byUserId: userId,
        byUserName: userName,
        timestamp: now,
      ));
    }
    if (newTask.notes.length > oldTask.notes.length) {
      final newNote = newTask.notes.isNotEmpty ? newTask.notes.last.note : '';
      final snippet = newNote.length > _timelineValueMaxLength
          ? '${newNote.substring(0, _timelineValueMaxLength)}...'
          : newNote;
      events.add(TaskTimelineEvent(
        type: 'note_added',
        label: 'تم إضافة ملاحظة',
        newValue: snippet.isEmpty ? null : snippet,
        byUserId: userId,
        byUserName: userName,
        timestamp: now,
      ));
    }
    if (newTask.files.length > oldTask.files.length) {
      final lastFile = newTask.files.isNotEmpty ? newTask.files.last.toString() : '';
      events.add(TaskTimelineEvent(
        type: 'attachment_added',
        label: 'تم إضافة مرفق',
        newValue: lastFile.isEmpty ? null : lastFile,
        byUserId: userId,
        byUserName: userName,
        timestamp: now,
      ));
    }

    // --- DesignTaskModel ---
    final oldD = oldTask.designDetails;
    final newD = newTask.designDetails;
    if (oldD != null || newD != null) {
      _addIfChanged(events, 'تم تغيير نوع المهمة (التصميم)', oldD?.taskType, newD?.taskType, userId, userName, now, fieldKey: 'designDetails.taskType');
      _addIfChanged(events, 'تم تغيير المنصة (التصميم)', oldD?.platform, newD?.platform, userId, userName, now, fieldKey: 'designDetails.platform');
      _addIfChanged(events, 'تم تغيير نوع التصميم', oldD?.designType, newD?.designType, userId, userName, now, fieldKey: 'designDetails.designType');
      _addIfChanged(events, 'تم تغيير عدد التصاميم (التصميم)', oldD?.designCount, newD?.designCount, userId, userName, now, fieldKey: 'designDetails.designCount');
      _addIfChanged(events, 'تم تغيير القياسات (التصميم)', oldD?.designsDimensions, newD?.designsDimensions, userId, userName, now, fieldKey: 'designDetails.designsDimensions');
    }

    // --- ContentWriteModel ---
    final oldCw = oldTask.contentWriteModel;
    final newCw = newTask.contentWriteModel;
    if (oldCw != null || newCw != null) {
      _addIfChanged(events, 'تم تغيير المنصة (المحتوى)', oldCw?.platform, newCw?.platform, userId, userName, now, fieldKey: 'contentWriteModel.platform');
      _addIfChanged(events, 'تم تغيير نوع المحتوى', oldCw?.contenttype, newCw?.contenttype, userId, userName, now, fieldKey: 'contentWriteModel.contenttype');
      _addIfChanged(events, 'تم تغيير عدد التصاميم (المحتوى)', oldCw?.designCount, newCw?.designCount, userId, userName, now, fieldKey: 'contentWriteModel.designCount');
      _addIfChanged(events, 'تم تغيير القياسات (المحتوى)', oldCw?.designsDimensions, newCw?.designsDimensions, userId, userName, now, fieldKey: 'contentWriteModel.designsDimensions');
    }

    // --- PhotographyModel ---
    final oldPh = oldTask.photoGrapghyModel;
    final newPh = newTask.photoGrapghyModel;
    if (oldPh != null || newPh != null) {
      _addIfChanged(events, 'تم تغيير نوع التصوير', oldPh?.shootingtype, newPh?.shootingtype, userId, userName, now, fieldKey: 'photoGrapghyModel.shootingtype');
      _addIfChanged(events, 'تم تغيير المنصة (التصوير)', oldPh?.platform, newPh?.platform, userId, userName, now, fieldKey: 'photoGrapghyModel.platform');
      _addIfChanged(events, 'تم تغيير موقع التصوير', oldPh?.shootinglocation, newPh?.shootinglocation, userId, userName, now, fieldKey: 'photoGrapghyModel.shootinglocation');
      _addIfChanged(events, 'تم تغيير عدد التصاميم (التصوير)', oldPh?.designCount, newPh?.designCount, userId, userName, now, fieldKey: 'photoGrapghyModel.designCount');
      _addIfChanged(events, 'تم تغيير المدة (التصوير)', oldPh?.duration, newPh?.duration, userId, userName, now, fieldKey: 'photoGrapghyModel.duration');
    }

    // --- MonatageModel ---
    final oldMo = oldTask.monatageModel;
    final newMo = newTask.monatageModel;
    if (oldMo != null || newMo != null) {
      _addIfChanged(events, 'تم تغيير التصنيف (المونتاج)', oldMo?.category, newMo?.category, userId, userName, now, fieldKey: 'monatageModel.category');
      _addIfChanged(events, 'تم تغيير المنصة (المونتاج)', oldMo?.platform, newMo?.platform, userId, userName, now, fieldKey: 'monatageModel.platform');
      _addIfChanged(events, 'تم تغيير الأبعاد (المونتاج)', oldMo?.dimentioans, newMo?.dimentioans, userId, userName, now, fieldKey: 'monatageModel.dimentioans');
      _addIfChanged(events, 'تم تغيير رابط المرفق (المونتاج)', oldMo?.attachementurl, newMo?.attachementurl, userId, userName, now, fieldKey: 'monatageModel.attachementurl');
      _addIfChanged(events, 'تم تغيير المدة (المونتاج)', oldMo?.duration, newMo?.duration, userId, userName, now, fieldKey: 'monatageModel.duration');
    }

    // --- PublishModel ---
    final oldPu = oldTask.publishModel;
    final newPu = newTask.publishModel;
    if (oldPu != null || newPu != null) {
      _addIfChanged(events, 'تم تغيير رابط المحتوى (النشر)', oldPu?.contenturl, newPu?.contenturl, userId, userName, now, fieldKey: 'publishModel.contenturl');
      _addIfChanged(events, 'تم تغيير المنصة (النشر)', oldPu?.platform, newPu?.platform, userId, userName, now, fieldKey: 'publishModel.platform');
      _addIfChanged(events, 'تم تغيير التصنيف (النشر)', oldPu?.category, newPu?.category, userId, userName, now, fieldKey: 'publishModel.category');
      _addIfChanged(events, 'تم تغيير رابط الملف (النشر)', oldPu?.fileurl, newPu?.fileurl, userId, userName, now, fieldKey: 'publishModel.fileurl');
      _addIfChanged(events, 'تم تغيير القياسات (النشر)', oldPu?.designsDimensions, newPu?.designsDimensions, userId, userName, now, fieldKey: 'publishModel.designsDimensions');
    }

    // --- ProgrammingModel ---
    final oldPr = oldTask.programmingModel;
    final newPr = newTask.programmingModel;
    if (oldPr != null || newPr != null) {
      _addIfChanged(events, 'تم تغيير رابط المحتوى (البرمجة)', oldPr?.contenturl, newPr?.contenturl, userId, userName, now, fieldKey: 'programmingModel.contenturl');
      _addIfChanged(events, 'تم تغيير التصنيف (البرمجة)', oldPr?.category, newPr?.category, userId, userName, now, fieldKey: 'programmingModel.category');
      _addIfChanged(events, 'تم تغيير رابط الملف (البرمجة)', oldPr?.fileurl, newPr?.fileurl, userId, userName, now, fieldKey: 'programmingModel.fileurl');
      _addIfChanged(events, 'تم تغيير القياسات (البرمجة)', oldPr?.designsDimensions, newPr?.designsDimensions, userId, userName, now, fieldKey: 'programmingModel.designsDimensions');
    }

    // --- PromotionModel (كل الحقول) ---
    final oldPromo = oldTask.promotionModel;
    final newPromo = newTask.promotionModel;
    if (oldPromo != null || newPromo != null) {
      _addIfChanged(events, 'تم تغيير الاسم (الترويج)', oldPromo?.name, newPromo?.name, userId, userName, now, fieldKey: 'promotionModel.name');
      _addIfChanged(events, 'تم تغيير الهدف (الترويج)', oldPromo?.target, newPromo?.target, userId, userName, now, fieldKey: 'promotionModel.target');
      _addIfChanged(events, 'تم تغيير اسم الحملة', oldPromo?.campaignName, newPromo?.campaignName, userId, userName, now, fieldKey: 'promotionModel.campaignName');
      _addIfChanged(events, 'تم تغيير النوع (الترويج)', oldPromo?.type, newPromo?.type, userId, userName, now, fieldKey: 'promotionModel.type');
      _addIfChanged(events, 'تم تغيير الأولوية (الترويج)', oldPromo?.priority, newPromo?.priority, userId, userName, now, fieldKey: 'promotionModel.priority');
      _addIfChanged(events, 'تم تغيير الحالة (الترويج)', oldPromo?.status, newPromo?.status, userId, userName, now, fieldKey: 'promotionModel.status');
      _addIfChanged(events, 'تم تغيير الوصف (الترويج)', oldPromo?.description, newPromo?.description, userId, userName, now, fieldKey: 'promotionModel.description');
      _addIfChanged(events, 'تم تغيير المنفذ (الترويج)', oldPromo?.executorId, newPromo?.executorId, userId, userName, now, fieldKey: 'promotionModel.executorId');
      _addIfChanged(events, 'تم تغيير تاريخ البداية (الترويج)', oldPromo?.startDate, newPromo?.startDate, userId, userName, now, fieldKey: 'promotionModel.startDate');
      _addIfChanged(events, 'تم تغيير تاريخ النهاية (الترويج)', oldPromo?.endDate, newPromo?.endDate, userId, userName, now, fieldKey: 'promotionModel.endDate');
      _addIfChanged(events, 'تم تغيير المدة (الترويج)', oldPromo?.duration, newPromo?.duration, userId, userName, now, fieldKey: 'promotionModel.duration');
      _addIfChanged(events, 'تم تغيير العلامات (الترويج)', oldPromo?.tags, newPromo?.tags, userId, userName, now, fieldKey: 'promotionModel.tags');
      _addIfChanged(events, 'تم تغيير المنصات (الترويج)', oldPromo?.platforms, newPromo?.platforms, userId, userName, now, fieldKey: 'promotionModel.platforms');
      _addIfChanged(events, 'تم تغيير الاهتمامات', oldPromo?.interests, newPromo?.interests, userId, userName, now, fieldKey: 'promotionModel.interests');
      _addIfChanged(events, 'تم تغيير المدن', oldPromo?.cities, newPromo?.cities, userId, userName, now, fieldKey: 'promotionModel.cities');
      _addIfChanged(events, 'تم تغيير الدول', oldPromo?.countries, newPromo?.countries, userId, userName, now, fieldKey: 'promotionModel.countries');
      _addIfChanged(events, 'تم تغيير التخصصات', oldPromo?.specializations, newPromo?.specializations, userId, userName, now, fieldKey: 'promotionModel.specializations');
      _addIfChanged(events, 'تم تغيير الفئات العمرية', oldPromo?.ageRanges, newPromo?.ageRanges, userId, userName, now, fieldKey: 'promotionModel.ageRanges');
      _addIfChanged(events, 'تم تغيير الملاحظات (الترويج)', oldPromo?.notes, newPromo?.notes, userId, userName, now, fieldKey: 'promotionModel.notes');
      _addIfChanged(events, 'تم تغيير رابط المرفق (الترويج)', oldPromo?.attachementurl, newPromo?.attachementurl, userId, userName, now, fieldKey: 'promotionModel.attachementurl');
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
    try {
      isUploading.value = true;
      uploadProgress.value = 0.0;

      showUploadDialog(); // 👈 نعرض الدايلوج

      final bucket = supabase.storage.from('point');
      final uniqueName = "${uuid.v1()}.${getExtension(fileName ?? '')}";

      final bytes = filePathOrBytes as Uint8List;

      // 🔥 نعمل حركة progress manually أثناء الرفع
      // (Supabase مفيهوش progress حقيقي)
      Timer.periodic(Duration(milliseconds: 100), (timer) {
        if (uploadProgress.value >= 0.95) {
          timer.cancel();
        } else {
          uploadProgress.value += 0.05;
        }
      });

      await bucket.uploadBinary(uniqueName, bytes); // الرفع الحقيقي

      uploadProgress.value = 1.0; // 100%

      final url = bucket.getPublicUrl(uniqueName);

      uploadedFilesPaths.add(url);

      isUploading.value = false;
      Get.back(); // اقفل الدايلوج

      return url;
    } catch (e) {
      isUploading.value = false;
      Get.back();
      log("Error uploading file: $e");
      return null;
    }
  }

  Future<EmployeeModel?> loginClient(email, pass) async {
    isLoading.value = true;
    final result = await _service.loginemployee(email, pass);
    isLoading.value = false;
    return result;
  }

  final _clientCollection = FirebaseFirestore.instance.collection("employees");
  Rxn<EmployeeModel> currentemployee = Rxn<EmployeeModel>();

  void listenToClient(String empid) async {
    _clientCollection.doc(empid).snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        currentemployee.value = EmployeeModel.fromJson(snapshot.data()!);
        _startTotalUnreadStream(empid);
      } else {
        currentemployee.value = null;
        _stopTotalUnreadStream();
      }
    });
    fetchContents();
    // fetchnotification(currentemployee.value?.id);
  }

  var employees = <EmployeeModel>[].obs;
  var clients = <ClientModel>[].obs;
  var contents = <ContentModel>[].obs;
  var searchedcontents = <ContentModel>[].obs;
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
        .getTotalUnreadMessagesStream(userId)
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

        // 2. الحصول على التوكن (على الويب قد يفشل لغياب OAuth/Service Worker)
        final vapidKey = kIsWeb
            ? (dotenv.env['FIREBASE_WEB_VAPID_KEY']?.trim().isNotEmpty == true
                ? dotenv.env['FIREBASE_WEB_VAPID_KEY']
                : 'BHG6F1qLC4V-rB_F1gKip91B6uAdxilKNs0Fj_ZtPA9M0vB9i8VBPelvJ9eDcgNfFaQqXGQQY22TksZvkBulre8')
            : null;
        String? token = await messaging.getToken(vapidKey: vapidKey);
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
    }
  }

  void showUploadDialog() {
    Get.dialog(
      Scaffold(
        body: Center(
          child: Obx(() {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    "${(uploadProgress.value * 100).toStringAsFixed(0)} %",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text("Uploading..."),
                ],
              ),
            );
          }),
        ),
      ),
      barrierDismissible: false,
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
    fetchTasks();
    ever(tasks, (_) {
      filterTasks();
      filterTasksHistory();
    });
    super.onInit();
  }

  @override
  void onClose() {
    _stopTotalUnreadStream();
    super.onClose();
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
