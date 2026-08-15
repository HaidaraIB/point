import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/ClientController.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/notification_navigation/notification_destination.dart';
import 'package:point/Utils/ContentPermissions.dart';
import 'package:point/View/Chats/ChatPage.dart';
import 'package:point/View/Chats/MChatPage.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';
import 'package:point/View/Contents/ContentDialogDetails.dart';
import 'package:point/View/Mobile/ClientContentDetails.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/open_task_details.dart';

/// Opens the screen / dialog for a parsed notification destination.
class NotificationNavigator {
  NotificationNavigator._();

  static String? _openEntityKey;
  static final FirestoreServices _firestore = FirestoreServices();

  static Future<void> open(NotificationDestination dest) async {
    final ctx = Get.context;
    if (ctx == null) return;

    final employee = _employee();
    final isClient = _isClientOnly();

    switch (dest.kind) {
      case NotificationDestinationKind.chat:
        await _openChat(ctx, dest, isClient: isClient);
        break;
      case NotificationDestinationKind.chatList:
        await _openChatList(ctx, isClient: isClient);
        break;
      case NotificationDestinationKind.task:
        await _openTask(ctx, dest, employee);
        break;
      case NotificationDestinationKind.content:
        await _openContent(ctx, dest, employee, isClient);
        break;
      case NotificationDestinationKind.publish:
        await _openPublish(ctx, dest, employee, isClient);
        break;
      case NotificationDestinationKind.attendance:
        await _openAttendance(employee, isClient);
        break;
      case NotificationDestinationKind.home:
        await _openHome(employee, isClient);
        break;
    }
  }

  static EmployeeModel? _employee() {
    if (!Get.isRegistered<HomeController>()) return null;
    return Get.find<HomeController>().currentEmployee.value;
  }

  static bool _isClientOnly() {
    final hasEmployee =
        _employee() != null && (_employee()!.id ?? '').trim().isNotEmpty;
    if (hasEmployee) return false;
    if (!Get.isRegistered<ClientController>()) return false;
    final c = Get.find<ClientController>().currentClient.value;
    return c != null && (c.id ?? '').trim().isNotEmpty;
  }

  static String _role(EmployeeModel? e) => (e?.role ?? '').trim().toLowerCase();

  static bool _isManager(EmployeeModel? e) {
    final r = _role(e);
    return r == 'admin' || r == 'supervisor';
  }

  static bool _isStaffEmployee(EmployeeModel? e) => _role(e) == 'employee';

  static String _currentPath() => Get.currentRoute.split('?').first;

  static Future<void> _goNamed(String route) async {
    final path = route.split('?').first;
    if (_currentPath() == path && !route.contains('?')) return;
    if (_currentPath() == path && route.contains('?')) {
      final currentParams = Get.parameters;
      final uri = Uri.parse(route);
      var same = true;
      uri.queryParameters.forEach((k, v) {
        if (currentParams[k] != v) same = false;
      });
      if (same) return;
    }
    Get.toNamed(route);
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  static void _snackMissing() {
    FunHelper.showSnackbar(
      AppLocaleKeys.errorTitle.tr,
      AppLocaleKeys.errorsNotificationTargetMissing.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  static void _snackUnavailable() {
    FunHelper.showSnackbar(
      AppLocaleKeys.errorTitle.tr,
      AppLocaleKeys.errorsNotificationUnavailable.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  static bool _skipIfAlreadyOpen(String key) {
    if (key.isEmpty) return false;
    if (_openEntityKey == key && (Get.isDialogOpen ?? false)) return true;
    return false;
  }

  static Future<void> _openChat(
    BuildContext context,
    NotificationDestination dest, {
    required bool isClient,
  }) async {
    final chatId = dest.chatId?.trim() ?? '';
    if (chatId.isEmpty) {
      await _openChatList(context, isClient: isClient);
      return;
    }
    if (isClient) {
      await _goNamed('/ClientHome');
      return;
    }
    if (ChatAudioFocus.shouldSuppressForegroundFcmForChat(chatId)) return;
    if (_skipIfAlreadyOpen('chat:$chatId')) return;
    _openEntityKey = 'chat:$chatId';

    if (!Get.isRegistered<HomeController>()) return;
    final hc = Get.find<HomeController>();
    final name = (dest.chatTitle ?? '').trim().isNotEmpty
        ? dest.chatTitle!.trim()
        : AppLocaleKeys.chatUnknownUser.tr;
    hc.selectedChat = <String, dynamic>{
      'id': chatId,
      'isGroup': dest.isGroup ?? false,
      'title': name,
      'displayName': name,
    };

    if (Responsive.isMobile(context)) {
      Get.to(() => ChatsListScreen(onMinimize: () {}, initialChatId: chatId));
      return;
    }
    hc.openChat(
      OpenChatModel(
        id: chatId,
        name: name,
        avatar: '',
        isGroup: dest.isGroup ?? false,
      ),
    );
  }

  static Future<void> _openChatList(
    BuildContext context, {
    required bool isClient,
  }) async {
    if (isClient) {
      await _goNamed('/ClientHome');
      return;
    }
    if (Responsive.isMobile(context)) {
      Get.to(() => ChatsListScreen(onMinimize: () {}));
      return;
    }
    if (Get.isDialogOpen ?? false) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Material(
          color: chatShellBackground(ctx),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.7,
            height: MediaQuery.of(ctx).size.height * 0.9,
            child: ChatScreen(
              isFloatingPopUp: true,
              onMinimize: () => Get.back(),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openTask(
    BuildContext context,
    NotificationDestination dest,
    EmployeeModel? employee,
  ) async {
    if (_isClientOnly()) {
      await _goNamed('/ClientHome');
      return;
    }
    final type = dest.taskType?.trim() ?? '';
    if (_isStaffEmployee(employee)) {
      await _goNamed('/employeeDashboard');
    } else {
      await _goNamed(_tasksRoute(type));
    }

    final id = dest.taskId?.trim() ?? '';
    if (id.isEmpty) return;
    if (_skipIfAlreadyOpen('task:$id')) return;

    final task = await _resolveTask(id);
    if (task == null) {
      _snackMissing();
      return;
    }
    final ctx = Get.context ?? context;
    _openEntityKey = 'task:$id';
    openTaskDetails(ctx, task);
  }

  static String _tasksRoute(String taskType) {
    final idx = int.tryParse(taskType) ?? 0;
    final slugs = StorageKeys.departmentSlugs;
    final i = idx < 0 || idx >= slugs.length ? 0 : idx;
    return '/tasks?department=${slugs[i]}&id=$i';
  }

  static Future<TaskModel?> _resolveTask(String id) async {
    if (Get.isRegistered<HomeController>()) {
      final cached = Get.find<HomeController>().tasks.firstWhereOrNull(
        (t) => (t.id ?? '') == id,
      );
      if (cached != null) return cached;
    }
    return _firestore.getTaskById(id);
  }

  static Future<ContentModel?> _resolveContent(String id) async {
    if (Get.isRegistered<HomeController>()) {
      final cached = Get.find<HomeController>().contents.firstWhereOrNull(
        (c) => (c.id ?? '') == id,
      );
      if (cached != null) return cached;
    }
    if (Get.isRegistered<ClientController>()) {
      final cached = Get.find<ClientController>().contents.firstWhereOrNull(
        (c) => (c.id ?? '') == id,
      );
      if (cached != null) return cached;
    }
    return _firestore.getContentById(id);
  }

  static Future<void> _openContent(
    BuildContext context,
    NotificationDestination dest,
    EmployeeModel? employee,
    bool isClient,
  ) async {
    if (isClient) {
      await _goNamed('/ClientHome');
      final id = dest.contentId?.trim() ?? '';
      if (id.isEmpty) return;
      final content = await _resolveContent(id);
      if (content == null) {
        _snackMissing();
        return;
      }
      Get.to(() => Clientcontentdetails(model: content));
      return;
    }

    await _goNamed(_contentListRoute(employee));
    final id = dest.contentId?.trim() ?? '';
    if (id.isEmpty) return;
    if (_skipIfAlreadyOpen('content:$id')) return;
    final content = await _resolveContent(id);
    if (content == null) {
      _snackMissing();
      return;
    }
    final ctx = Get.context ?? context;
    _openEntityKey = 'content:$id';
    showContentDialogDetails(ctx, task: content);
  }

  static String _contentListRoute(EmployeeModel? employee) {
    if (_isStaffEmployee(employee)) return '/employeeContent';
    return '/content';
  }

  static Future<void> _openPublish(
    BuildContext context,
    NotificationDestination dest,
    EmployeeModel? employee,
    bool isClient,
  ) async {
    if (isClient) {
      await _openContent(context, dest, employee, true);
      return;
    }
    if (ContentPermissions.canAccessPublishSection(employee)) {
      await _goNamed('/publish');
      final id = dest.contentId?.trim() ?? '';
      if (id.isEmpty) return;
      if (_skipIfAlreadyOpen('content:$id')) return;
      final content = await _resolveContent(id);
      if (content == null) {
        _snackMissing();
        return;
      }
      final ctx = Get.context ?? context;
      _openEntityKey = 'content:$id';
      showContentDialogDetails(ctx, task: content);
      return;
    }
    if (_isStaffEmployee(employee) &&
        ContentPermissions.isPublishingEmployee(employee)) {
      await _openContent(context, dest, employee, false);
      return;
    }
    await _goNamed('/employeeDashboard');
    if ((dest.contentId ?? '').trim().isNotEmpty) {
      _snackUnavailable();
    }
  }

  static Future<void> _openAttendance(
    EmployeeModel? employee,
    bool isClient,
  ) async {
    if (isClient) {
      await _goNamed('/ClientHome');
      return;
    }
    if (_isManager(employee)) {
      await _goNamed('/attendance');
      return;
    }
    await _goNamed('/employeeDashboard');
  }

  static Future<void> _openHome(EmployeeModel? employee, bool isClient) async {
    if (isClient) {
      await _goNamed('/ClientHome');
      return;
    }
    if (_isStaffEmployee(employee)) {
      await _goNamed('/employeeDashboard');
      return;
    }
    await _goNamed('/');
  }
}
