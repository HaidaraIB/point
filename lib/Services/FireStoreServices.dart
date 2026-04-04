import 'dart:async';
import 'package:point/Utils/app_log.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:point/config/app_config.dart';
import 'package:point/Models/ChatMetaData.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/firestore/firestore_auth_api.dart';
import 'package:point/Services/firestore/firestore_chat_api.dart';
import 'package:point/Services/firestore/firestore_diagnostics_api.dart';
import 'package:point/Services/firestore/firestore_fcm_api.dart';
import 'package:point/Services/firestore/firestore_notification_api.dart';
import 'package:point/Services/firestore/firestore_stream_utils.dart';
import 'package:point/Services/firestore/firestore_task_utils.dart'
    show taskTypeCodeForNormalizedDepartment;

export 'package:point/Services/firestore/fcm_exceptions.dart';

part 'firestore/firestore_services_instance_part.dart';

/// حقول Firestore المشتركة بين الواجهات (أساس لـ [FirestoreServicesInstanceMixin]).
class FirestoreServicesBase {
  var db = FirebaseFirestore.instance;
  final CollectionReference _employeeCollection = FirebaseFirestore.instance
      .collection('employees');
  final CollectionReference _clientCollection =
      FirebaseFirestore.instance.collection('clients');
  final CollectionReference _db =
      FirebaseFirestore.instance.collection('contents');
  final CollectionReference _dbtask =
      FirebaseFirestore.instance.collection('tasks');
}

/// واجهة Firestore الرئيسية للتطبيق؛ المنطق مُقسّم على [FirestoreFcmApi] ووحدات أخرى.
class FirestoreServices extends FirestoreServicesBase
    with FirestoreServicesInstanceMixin {
  FirestoreServices();

  static const String authRolesCollection = FirestoreAuthApi.authRolesCollection;

  static Future<void> syncAuthRoleForEmployee(EmployeeModel employee) =>
      FirestoreAuthApi.syncAuthRoleForEmployee(employee);

  static Future<void> syncAuthRoleForClient(ClientModel client) =>
      FirestoreAuthApi.syncAuthRoleForClient(client);

  static Future<void> addEmployeeFcmToken({
    required String employeeId,
    required String token,
  }) =>
      FirestoreFcmApi.addEmployeeFcmToken(employeeId: employeeId, token: token);

  static Future<void> addClientFcmToken({
    required String clientId,
    required String token,
  }) =>
      FirestoreFcmApi.addClientFcmToken(clientId: clientId, token: token);

  static Future<void> logClientDiagnosticError({
    required String source,
    required String code,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) =>
      FirestoreFcmApi.logClientDiagnosticError(
        source: source,
        code: code,
        error: error,
        stackTrace: stackTrace,
        extra: extra,
      );

  static Future<void> syncEmployeeActiveChatId(
    String employeeId,
    String? chatId,
  ) =>
      FirestoreChatApi.syncEmployeeActiveChatId(employeeId, chatId);

  static Future<void> markIncomingMessagesReadInChat(
    String chatId,
    String viewerUserId,
  ) =>
      FirestoreChatApi.markIncomingMessagesReadInChat(chatId, viewerUserId);

  static String chatListPreviewFromMessageData(Map<String, dynamic> data) =>
      FirestoreChatApi.chatListPreviewFromMessageData(data);

  static Future<String?> fetchLatestMessagePreviewForChat(
    FirebaseFirestore fs,
    String chatId,
  ) =>
      FirestoreChatApi.fetchLatestMessagePreviewForChat(fs, chatId);

  static Future<Map<String, String?>> fetchLatestMessagePreviewsForChatIds(
    FirebaseFirestore fs,
    Iterable<String> chatIds,
  ) =>
      FirestoreChatApi.fetchLatestMessagePreviewsForChatIds(fs, chatIds);

  static Future<void> patchChatLastMessageIfStale(
    FirebaseFirestore fs,
    String chatId,
    String previewFromMessages,
    String currentDocLastMessage,
  ) =>
      FirestoreChatApi.patchChatLastMessageIfStale(
        fs,
        chatId,
        previewFromMessages,
        currentDocLastMessage,
      );

  static Future<void> addNotification(NotificationModel model) =>
      FirestoreNotificationApi.addNotification(model);

  static Future<void> markInAppNotificationsAsRead(Iterable<String> docIds) =>
      FirestoreNotificationApi.markInAppNotificationsAsRead(docIds);

  static Future<void> deleteInAppNotifications(Iterable<String> docIds) =>
      FirestoreNotificationApi.deleteInAppNotifications(docIds);

  static Stream<QuerySnapshot<Map<String, dynamic>>>
      watchPushDiagnosticsByRequestId(String requestId) =>
          FirestoreDiagnosticsApi.watchPushDiagnosticsByRequestId(requestId);

  static Stream<QuerySnapshot<Map<String, dynamic>>>
      watchPushDiagnosticsByRecipient(String recipientId) =>
          FirestoreDiagnosticsApi.watchPushDiagnosticsByRecipient(recipientId);

  static Stream<QuerySnapshot<Map<String, dynamic>>>
      watchRecentIosPushFailures() =>
          FirestoreDiagnosticsApi.watchRecentIosPushFailures();

  static Future<void> sendFcm({
    required String userId,
    required String title,
    required String body,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
    Map<String, String>? fcmDataExtras,
    bool sendPush = true,
    bool? sendEmail,
    Set<String>? batchSeenTokens,
    Set<String>? batchSeenEmails,
  }) =>
      FirestoreFcmApi.sendFcm(
        userId: userId,
        title: title,
        body: body,
        notificationType: notificationType,
        actionText: actionText,
        referenceId: referenceId,
        emailDetails: emailDetails,
        fcmDataExtras: fcmDataExtras,
        sendPush: sendPush,
        sendEmail: sendEmail,
        batchSeenTokens: batchSeenTokens,
        batchSeenEmails: batchSeenEmails,
      );

  static Future<void> sendFcmForClient({
    required String userId,
    required String title,
    required String body,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
    Map<String, String>? fcmDataExtras,
    bool sendPush = true,
    bool? sendEmail,
    Set<String>? batchSeenTokens,
    Set<String>? batchSeenEmails,
  }) =>
      FirestoreFcmApi.sendFcmForClient(
        userId: userId,
        title: title,
        body: body,
        notificationType: notificationType,
        actionText: actionText,
        referenceId: referenceId,
        emailDetails: emailDetails,
        fcmDataExtras: fcmDataExtras,
        sendPush: sendPush,
        sendEmail: sendEmail,
        batchSeenTokens: batchSeenTokens,
        batchSeenEmails: batchSeenEmails,
      );

  static Future<void> sendFcmTopic({
    required String topic,
    required String title,
    required String body,
    required String scheduledAt,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
    bool sendPush = true,
    bool sendEmail = true,
  }) =>
      FirestoreFcmApi.sendFcmTopic(
        topic: topic,
        title: title,
        body: body,
        scheduledAt: scheduledAt,
        notificationType: notificationType,
        actionText: actionText,
        referenceId: referenceId,
        emailDetails: emailDetails,
        sendPush: sendPush,
        sendEmail: sendEmail,
      );

  static Future<List<String>> getEmployeeIdsByRole(List<String> roles) =>
      FirestoreFcmApi.getEmployeeIdsByRole(roles);

  static Future<List<String>> getEmployeeIdsByDepartment(String department) =>
      FirestoreFcmApi.getEmployeeIdsByDepartment(department);

  static Future<void> sendFcmToEmployees({
    required List<String> userIds,
    required String title,
    required String body,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
    Map<String, String>? fcmDataExtras,
  }) =>
      FirestoreFcmApi.sendFcmToEmployees(
        userIds: userIds,
        title: title,
        body: body,
        notificationType: notificationType,
        actionText: actionText,
        referenceId: referenceId,
        emailDetails: emailDetails,
        fcmDataExtras: fcmDataExtras,
      );
}
