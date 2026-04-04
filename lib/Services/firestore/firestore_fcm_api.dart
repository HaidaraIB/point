import 'dart:async';
import 'dart:developer';
import 'dart:math' show Random;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Services/EmailNotificationService.dart';
import 'package:point/Services/firestore/fcm_exceptions.dart';
import 'package:point/Services/firestore/firestore_notification_api.dart';
import 'package:point/Services/notification_email_policy.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إرسال FCM والتوكنات وتشخيصات الدفع.
class FirestoreFcmApi {
  FirestoreFcmApi._();

  static final Random _random = Random();


  static String _newPushRequestId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(1 << 20).toRadixString(16);
    return 'push_$ms$rand';
  }

  static String _maskFcmToken(String t) {
    if (t.length <= 12) return '***';
    return '${t.substring(0, 6)}...${t.substring(t.length - 4)}';
  }

  static Future<void> _logPushDiagnostic({
    required String requestId,
    required String stage,
    required String status,
    required String targetType,
    String? recipientId,
    String? recipientType,
    String? tokenMasked,
    String? topic,
    String? title,
    int? bodyLen,
    String? notificationType,
    int? fcmHttpStatus,
    String? fcmErrorCode,
    String? fcmErrorStatus,
    String? fcmErrorMessage,
    Object? details,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('push_diagnostics').add({
        'createdAt': FieldValue.serverTimestamp(),
        'requestId': requestId,
        'stage': stage,
        'status': status,
        'targetType': targetType,
        'senderUid': currentUser?.uid,
        'recipientId': recipientId,
        'recipientType': recipientType,
        'tokenMasked': tokenMasked,
        'topic': topic,
        'title': title,
        'bodyLen': bodyLen ?? 0,
        'notificationType': notificationType,
        'fcmHttpStatus': fcmHttpStatus,
        'fcmErrorCode': fcmErrorCode,
        'fcmErrorStatus': fcmErrorStatus,
        'fcmErrorMessage': fcmErrorMessage,
        if (details != null) 'details': details.toString(),
        'source': 'flutter_app',
      });
    } catch (_) {
      // Keep diagnostics non-blocking.
    }
  }
  static List<String> _extractFcmTokens(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final tokens = <String>{};
    final rawList = data['fcmTokens'];
    if (rawList is List) {
      for (final raw in rawList) {
        final token = raw?.toString().trim() ?? '';
        if (token.isNotEmpty) tokens.add(token);
      }
    }
    final singleToken = data['fcmToken']?.toString().trim() ?? '';
    if (singleToken.isNotEmpty) tokens.add(singleToken);
    return tokens.toList();
  }

  static String _emailDedupeKey(String email) => email.trim().toLowerCase();

  static bool _isInvalidOrExpiredTokenError(Object error) {
    if (error is FcmSendException) {
      final details = (error.details?.toString() ?? '').toLowerCase();
      final fcmStatus = (error.fcmErrorStatus ?? '').toLowerCase();
      final fcmMessage = (error.fcmErrorMessage ?? '').toLowerCase();
      final combined = '$details $fcmStatus $fcmMessage';
      return combined.contains('registration-token-not-registered') ||
          combined.contains('invalid-registration-token') ||
          combined.contains('invalid_argument') ||
          combined.contains('unregistered') ||
          combined.contains('not registered') ||
          combined.contains('token-not-registered');
    }
    if (error is FunctionException) {
      return _fcmPayloadImpliesInvalidToken(error.details);
    }
    return false;
  }

  static bool _fcmPayloadImpliesInvalidToken(Object? details) {
    final s = details?.toString().toLowerCase() ?? '';
    return s.contains('unregistered') ||
        s.contains('registration-token-not-registered') ||
        s.contains('invalid-registration-token') ||
        s.contains('invalid_argument') ||
        s.contains('not registered') ||
        s.contains('token-not-registered');
  }

  /// When Supabase `functions.invoke` gets a non-2xx response it throws
  /// [FunctionException] instead of returning [FunctionResponse], so FCM errors
  /// must be normalized to [FcmSendException] for callers and token cleanup.
  static FcmSendException _fcmSendExceptionFromFunctionException(
    FunctionException e,
  ) {
    final responseData = _normalizeDetailsMap(e.details);
    final code = responseData?['errorCode']?.toString();
    final nestedDetails = responseData?['details'];
    Map<String, dynamic>? fcmError;
    final nestedMap = _normalizeDetailsMap(nestedDetails);
    if (nestedMap != null) {
      fcmError = _normalizeDetailsMap(nestedMap['error']);
    }
    return FcmSendException(
      status: e.status,
      errorCode: code,
      details: nestedDetails ?? responseData,
      fcmErrorStatus: fcmError?['status']?.toString(),
      fcmErrorMessage: fcmError?['message']?.toString(),
    );
  }

  static Map<String, dynamic>? _normalizeDetailsMap(Object? value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, dynamic v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  /// يحاول ربط توكن FCM عبر Edge Function claim-fcm-token؛ عند النجاح يُزال
  /// التوكن من أي موظف/عميل آخر ثم يُسجَّل للمستهدف. عند الفشل يُرجع false
  /// ليستمر المتصل بالتحديث المباشر (مثلاً قبل نشر الدالة أو بدون جلسة Firebase).
  static Future<bool> _tryClaimFcmTokenViaSupabase({
    required String fcmToken,
    String? employeeId,
    String? clientId,
  }) async {
    final eid = employeeId?.trim() ?? '';
    final cid = clientId?.trim() ?? '';
    if ((eid.isNotEmpty && cid.isNotEmpty) || (eid.isEmpty && cid.isEmpty)) {
      return false;
    }
    try {
      final firebaseIdToken =
          await FirebaseAuth.instance.currentUser?.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) return false;

      final res = await Supabase.instance.client.functions.invoke(
        'claim-fcm-token',
        headers: <String, String>{
          'x-firebase-id-token': 'Bearer $firebaseIdToken',
        },
        body: <String, dynamic>{
          'fcmToken': fcmToken,
          if (eid.isNotEmpty) 'employeeId': eid,
          if (cid.isNotEmpty) 'clientId': cid,
        },
      );

      final data = res.data;
      if (res.status == 200 && data is Map && data['ok'] == true) {
        return true;
      }
      log('claim-fcm-token non-ok: status=${res.status} data=$data');
      return false;
    } on FunctionException catch (e) {
      log(
        'claim-fcm-token FunctionException: status=${e.status} details=${e.details}',
      );
      return false;
    } catch (e, st) {
      log('claim-fcm-token error: $e');
      log('$st');
      return false;
    }
  }

  static Future<void> addEmployeeFcmToken({
    required String employeeId,
    required String token,
  }) async {
    final cleanedId = employeeId.trim();
    final cleanedToken = token.trim();
    if (cleanedId.isEmpty || cleanedToken.isEmpty) return;

    final claimed = await _tryClaimFcmTokenViaSupabase(
      fcmToken: cleanedToken,
      employeeId: cleanedId,
    );
    if (claimed) return;

    await FirebaseFirestore.instance
        .collection('employees')
        .doc(cleanedId)
        .update({
          'fcmToken': cleanedToken,
          'fcmTokens': FieldValue.arrayUnion([cleanedToken]),
        });
  }

  static Future<void> addClientFcmToken({
    required String clientId,
    required String token,
  }) async {
    final cleanedId = clientId.trim();
    final cleanedToken = token.trim();
    if (cleanedId.isEmpty || cleanedToken.isEmpty) return;

    final claimed = await _tryClaimFcmTokenViaSupabase(
      fcmToken: cleanedToken,
      clientId: cleanedId,
    );
    if (claimed) return;

    await FirebaseFirestore.instance
        .collection('clients')
        .doc(cleanedId)
        .update({
          'fcmToken': cleanedToken,
          'fcmTokens': FieldValue.arrayUnion([cleanedToken]),
        });
  }

  static Future<void> _removeEmployeeFcmToken({
    required String employeeId,
    required String token,
  }) async {
    final cleanedId = employeeId.trim();
    final cleanedToken = token.trim();
    if (cleanedId.isEmpty || cleanedToken.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection('employees')
        .doc(cleanedId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data();
    final currentSingle = data?['fcmToken']?.toString().trim() ?? '';
    await ref.update({
      'fcmTokens': FieldValue.arrayRemove([cleanedToken]),
      if (currentSingle == cleanedToken) 'fcmToken': null,
    });
  }

  static Future<void> _removeClientFcmToken({
    required String clientId,
    required String token,
  }) async {
    final cleanedId = clientId.trim();
    final cleanedToken = token.trim();
    if (cleanedId.isEmpty || cleanedToken.isEmpty) return;
    final ref = FirebaseFirestore.instance.collection('clients').doc(cleanedId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data();
    final currentSingle = data?['fcmToken']?.toString().trim() ?? '';
    await ref.update({
      'fcmTokens': FieldValue.arrayRemove([cleanedToken]),
      if (currentSingle == cleanedToken) 'fcmToken': null,
    });
  }

  static Future<void> logClientDiagnosticError({
    required String source,
    required String code,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('app_error_logs').add({
        'source': source,
        'code': code,
        'message': error.toString(),
        'errorType': error.runtimeType.toString(),
        'stackTrace': stackTrace?.toString(),
        'uid': currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        if (extra != null) 'extra': extra,
      });
    } catch (e, s) {
      log('⚠️ logClientDiagnosticError failed: $e');
      log('StackTrace: $s');
    }
  }

  static Future<void> _sendFcmViaFunction({
    String? token,
    String? topic,
    required String title,
    required String body,
    Map<String, String>? data,
    required String requestId,
    String? recipientId,
    String? recipientType,
    String? notificationType,
  }) async {
    final targetLabel =
        token != null
            ? 'token=${_maskFcmToken(token)}'
            : 'topic=${topic ?? "(null)"}';

    final firebaseIdToken =
        await FirebaseAuth.instance.currentUser?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw StateError('FirebaseAuth session required to send FCM.');
    }

    log(
      '➡️ FCM invoke start. target=$targetLabel title="$title" bodyLen=${body.length}',
    );

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'send-fcm',
        // IMPORTANT: keep `authorization` for Supabase; pass Firebase token via a
        // dedicated header so the Edge Function can verify it.
        headers: <String, String>{
          'x-firebase-id-token': 'Bearer $firebaseIdToken',
        },
        body: <String, dynamic>{
          if (token != null) 'token': token,
          if (topic != null) 'topic': topic,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
          'requestId': requestId,
          if (recipientId != null) 'recipientId': recipientId,
          if (recipientType != null) 'recipientType': recipientType,
          if (notificationType != null) 'notificationType': notificationType,
        },
      );

      log(
        '✅ FCM invoke success. target=$targetLabel status=${res.status} data=${res.data}',
      );
    } on FunctionException catch (e) {
      final ex = _fcmSendExceptionFromFunctionException(e);
      log(
        '❌ FCM invoke failed. target=$targetLabel status=${ex.status} errorCode=${ex.errorCode} details=${ex.details}',
      );
      throw ex;
    }
  }

  static bool _shouldPersistFcmToNotificationInbox(String? notificationType) {
    return notificationType?.trim() != 'chat_message';
  }

  static Future<void> sendFcm({
    required String userId,
    required String title,
    required String body,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
    /// يُدمج في حمولة `data` لـ FCM (مثل `chatId` لإشعارات الدردشة).
    Map<String, String>? fcmDataExtras,
    bool sendPush = true,
    /// إن وُجد يُستخدم كما هو؛ وإلا تُطبَّق [NotificationEmailPolicy] حسب [notificationType].
    bool? sendEmail,
    Set<String>? batchSeenTokens,
    /// يمنع إرسال أكثر من بريد لنفس العنوان ضمن دفعة واحدة (مثل [sendFcmToEmployees]).
    Set<String>? batchSeenEmails,
  }) async {
    try {
      final effectiveSendEmail =
          sendEmail ?? NotificationEmailPolicy.shouldSendEmail(notificationType);

      // 1. هات بيانات المستخدم من Firestore
      final doc =
          await FirebaseFirestore.instance
              .collection("employees")
              .doc(userId.trim())
              .get();

      if (!doc.exists) {
        log("⚠️ Employee not found: $userId");
        return;
      }

      final data = doc.data();
      final email = data?['email']?.toString().trim();
      final tokens = _extractFcmTokens(data);
      final rawRecipientName = data?['name']?.toString().trim();
      final recipientRole = data?['role'];
      final recipientName =
          (rawRecipientName != null && rawRecipientName.isNotEmpty)
              ? rawRecipientName
              : 'الموظف';

      final trimmedUserId = userId.trim();
      if (_shouldPersistFcmToNotificationInbox(notificationType)) {
        await FirestoreNotificationApi.addNotification(
          NotificationModel(
            title: title,
            body: body,
            recipientId: trimmedUserId,
            createdAt: DateTime.now(),
            isRead: false,
          ),
        );
      }

      // إرسال بريد (اختياري حسب اختيار القناة)
      var sendThisEmail =
          effectiveSendEmail && email != null && email.isNotEmpty;
      if (sendThisEmail && batchSeenEmails != null) {
        final key = _emailDedupeKey(email);
        if (!batchSeenEmails.add(key)) {
          sendThisEmail = false;
          log(
            "↩️ Duplicate batch email skipped ($recipientName · $trimmedUserId)",
          );
        }
      }
      if (sendThisEmail) {
        // إرسال إيميل حتى عند غياب FCM (من لم يثبت التطبيق أو عطّل الإشعارات يظل يحصل على الإيميل)
        final details = <String, String>{
          'المستلم': recipientName,
          'معرف المستلم': trimmedUserId,
          if (emailDetails != null) ...emailDetails,
        };
        unawaited(
          EmailNotificationService.sendDetailedNotification(
            toEmail: email!,
            title: title,
            body: body,
            recipientLabel: recipientName,
            notificationType: notificationType ?? 'إشعار موظف',
            actionText: actionText,
            referenceId: referenceId ?? trimmedUserId,
            details: details,
          ),
        );
      } else if (effectiveSendEmail &&
          (email == null || email.isEmpty)) {
        log(
          "⚠️ Email missing for $recipientRole $recipientName — skipping email notification",
        );
      }

      // إذا المستخدم لا يريد Push، ننهي بدون فحص token أو إرسال push.
      if (!sendPush) return;

      if (tokens.isEmpty) {
        log("⚠️ fcmToken missing for $recipientRole $recipientName — push not sent");
        return;
      }

      for (final token in tokens) {
        final cleanedToken = token.trim();
        if (cleanedToken.isEmpty) continue;
        if (batchSeenTokens != null && !batchSeenTokens.add(cleanedToken)) {
          log(
            "↩️ Duplicate batch token skipped for $recipientRole $recipientName (${_maskFcmToken(cleanedToken)})",
          );
          continue;
        }
        final requestId = _newPushRequestId();
        try {
          await _sendFcmViaFunction(
            token: cleanedToken,
            title: title,
            body: body,
            data: <String, String>{
              'type': 'internal',
              'id': trimmedUserId,
              'url': 'https://example.com',
              if (notificationType != null &&
                  notificationType.trim().isNotEmpty)
                'notificationType': notificationType.trim(),
              if (fcmDataExtras != null) ...fcmDataExtras,
            },
            requestId: requestId,
            recipientId: trimmedUserId,
            recipientType: 'employee',
            notificationType: notificationType,
          );
        } catch (e) {
          if (e is FcmSendException) {
            await _logPushDiagnostic(
              requestId: requestId,
              stage: 'app_result',
              status: 'error',
              targetType: 'token',
              recipientId: trimmedUserId,
              recipientType: 'employee',
              tokenMasked: _maskFcmToken(cleanedToken),
              title: title,
              bodyLen: body.length,
              notificationType: notificationType,
              fcmHttpStatus: e.status,
              fcmErrorCode: e.errorCode,
              fcmErrorStatus: e.fcmErrorStatus,
              fcmErrorMessage: e.fcmErrorMessage,
              details: e.details,
            );
          }
          if (_isInvalidOrExpiredTokenError(e)) {
            await _removeEmployeeFcmToken(
              employeeId: trimmedUserId,
              token: cleanedToken,
            );
            log("🧹 Removed invalid employee token for $recipientName");
            continue;
          }
          rethrow;
        }
      }
      log("✅ FCM Response: $recipientName");
    } on FcmSendException catch (e) {
      switch (e.errorCode) {
        case 'ERR_METHOD_NOT_ALLOWED':
          log("❌ FCM Error: ${AppLocaleKeys.errorsMethodNotAllowed}");
          break;
        case 'ERR_UNAUTHORIZED':
          log("❌ FCM Error: ${AppLocaleKeys.errorsUnauthorized}");
          break;
        case 'ERR_FORBIDDEN':
          log("❌ FCM Error: ${AppLocaleKeys.errorsForbidden}");
          break;
        case 'ERR_MISSING_TOKEN':
          log("❌ FCM Error: ${AppLocaleKeys.errorsMissingToken}");
          break;
        case 'ERR_INVALID_DATA':
          log("❌ FCM Error: ${AppLocaleKeys.errorsInvalidData}");
          break;
        default:
          log("❌ FCM Error: ${AppLocaleKeys.errorsServer} | $e");
      }
    } catch (e) {
      log("❌ FCM Error: $e");
    }
  }

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
    /// إن وُجد يُستخدم كما هو؛ وإلا تُطبَّق [NotificationEmailPolicy] حسب [notificationType].
    bool? sendEmail,
    Set<String>? batchSeenTokens,
    Set<String>? batchSeenEmails,
  }) async {
    try {
      final effectiveSendEmail =
          sendEmail ?? NotificationEmailPolicy.shouldSendEmail(notificationType);

      // 1. هات بيانات المستخدم من Firestore
      final doc =
          await FirebaseFirestore.instance
              .collection("clients")
              .doc(userId)
              .get();

      if (!doc.exists) {
        log("⚠️ Client not found: $userId");
        return;
      }

      final data = doc.data();
      final email = data?['email']?.toString().trim();
      final tokens = _extractFcmTokens(data);
      final rawRecipientName = data?['name']?.toString().trim();
      final recipientName =
          (rawRecipientName != null && rawRecipientName.isNotEmpty)
              ? rawRecipientName
              : 'العميل';

      final trimmedUserId = userId.trim();
      if (_shouldPersistFcmToNotificationInbox(notificationType)) {
        await FirestoreNotificationApi.addNotification(
          NotificationModel(
            title: title,
            body: body,
            recipientId: trimmedUserId,
            createdAt: DateTime.now(),
            isRead: false,
          ),
        );
      }

      var sendThisClientEmail =
          effectiveSendEmail && email != null && email.isNotEmpty;
      if (sendThisClientEmail && batchSeenEmails != null) {
        final key = _emailDedupeKey(email);
        if (!batchSeenEmails.add(key)) {
          sendThisClientEmail = false;
          log(
            "↩️ Duplicate batch email skipped (client $recipientName · $trimmedUserId)",
          );
        }
      }
      if (sendThisClientEmail) {
        final details = <String, String>{
          'المستلم': recipientName,
          'معرف المستلم': trimmedUserId,
          if (emailDetails != null) ...emailDetails,
        };
        unawaited(
          EmailNotificationService.sendDetailedNotification(
            toEmail: email!,
            title: title,
            body: body,
            recipientLabel: recipientName,
            notificationType: notificationType ?? 'إشعار عميل',
            actionText: actionText,
            referenceId: referenceId ?? trimmedUserId,
            details: details,
          ),
        );
      } else if (effectiveSendEmail &&
          (email == null || email.isEmpty)) {
        log(
          "⚠️ Email missing for client $recipientName — skipping email notification",
        );
      }

      if (!sendPush) return;

      if (tokens.isEmpty) {
        log("⚠️ fcmToken missing for client $recipientName — push not sent");
        return;
      }

      for (final token in tokens) {
        final cleanedToken = token.trim();
        if (cleanedToken.isEmpty) continue;
        if (batchSeenTokens != null && !batchSeenTokens.add(cleanedToken)) {
          log(
            "↩️ Duplicate batch token skipped for client $recipientName (${_maskFcmToken(cleanedToken)})",
          );
          continue;
        }
        final requestId = _newPushRequestId();
        try {
          await _sendFcmViaFunction(
            token: cleanedToken,
            title: title,
            body: body,
            data: <String, String>{
              'type': 'internal',
              'id': trimmedUserId,
              'url': 'https://example.com',
              if (notificationType != null &&
                  notificationType.trim().isNotEmpty)
                'notificationType': notificationType.trim(),
              if (fcmDataExtras != null) ...fcmDataExtras,
            },
            requestId: requestId,
            recipientId: trimmedUserId,
            recipientType: 'client',
            notificationType: notificationType,
          );
        } catch (e) {
          if (e is FcmSendException) {
            await _logPushDiagnostic(
              requestId: requestId,
              stage: 'app_result',
              status: 'error',
              targetType: 'token',
              recipientId: trimmedUserId,
              recipientType: 'client',
              tokenMasked: _maskFcmToken(cleanedToken),
              title: title,
              bodyLen: body.length,
              notificationType: notificationType,
              fcmHttpStatus: e.status,
              fcmErrorCode: e.errorCode,
              fcmErrorStatus: e.fcmErrorStatus,
              fcmErrorMessage: e.fcmErrorMessage,
              details: e.details,
            );
          }
          if (_isInvalidOrExpiredTokenError(e)) {
            await _removeClientFcmToken(
              clientId: trimmedUserId,
              token: cleanedToken,
            );
            log("🧹 Removed invalid client token for $recipientName");
            continue;
          }
          rethrow;
        }
      }
      log("✅ FCM sent to client: $recipientName");
    } on FcmSendException catch (e) {
      switch (e.errorCode) {
        case 'ERR_METHOD_NOT_ALLOWED':
          log("❌ FCM Error: ${AppLocaleKeys.errorsMethodNotAllowed}");
          break;
        case 'ERR_UNAUTHORIZED':
          log("❌ FCM Error: ${AppLocaleKeys.errorsUnauthorized}");
          break;
        case 'ERR_FORBIDDEN':
          log("❌ FCM Error: ${AppLocaleKeys.errorsForbidden}");
          break;
        case 'ERR_MISSING_TOKEN':
          log("❌ FCM Error: ${AppLocaleKeys.errorsMissingToken}");
          break;
        case 'ERR_INVALID_DATA':
          log("❌ FCM Error: ${AppLocaleKeys.errorsInvalidData}");
          break;
        default:
          log("❌ FCM Error: ${AppLocaleKeys.errorsServer} | $e");
      }
    } catch (e) {
      log("❌ FCM Error: $e");
    }
  }

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
  }) async {
    final requestId = _newPushRequestId();
    try {
      if (sendPush) {
        await _sendFcmViaFunction(
          topic: topic,
          title: title,
          body: body,
          data:
              notificationType != null && notificationType.trim().isNotEmpty
                  ? <String, String>{
                    'notificationType': notificationType.trim(),
                  }
                  : null,
          requestId: requestId,
          recipientType: 'topic',
          notificationType: notificationType,
        );
        log("✅ FCM topic sent: $topic");
      }

      if (sendEmail) {
        // إرسال إيميل إشعار لجميع المستلمين في الـ topic (بدون انتظار)
        unawaited(
          _sendEmailForTopic(
            topic,
            title,
            body,
            notificationType: notificationType,
            actionText: actionText,
            referenceId: referenceId,
            emailDetails: <String, String>{
              'الموضوع': topic,
              'موعد الإرسال المجدول': scheduledAt,
              if (emailDetails != null) ...emailDetails,
            },
          ),
        );
      }
    } on FcmSendException catch (e) {
      await _logPushDiagnostic(
        requestId: requestId,
        stage: 'app_result',
        status: 'error',
        targetType: 'topic',
        topic: topic,
        title: title,
        bodyLen: body.length,
        notificationType: notificationType,
        fcmHttpStatus: e.status,
        fcmErrorCode: e.errorCode,
        fcmErrorStatus: e.fcmErrorStatus,
        fcmErrorMessage: e.fcmErrorMessage,
        details: e.details,
      );
      log("❌ FCM Error: $e");
    } catch (e) {
      log("❌ FCM Error: $e");
    }
  }

  /// يجلب عناوين البريد حسب الـ topic ويرسل إشعاراً لكل واحد.
  static Future<void> _sendEmailForTopic(
    String topic,
    String title,
    String body, {
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
  }) async {
    try {
      final emails = <String>[];
      int skippedEmployees = 0;
      int skippedClients = 0;

      if (topic == 'employees' || topic == 'all') {
        final snap =
            await FirebaseFirestore.instance.collection('employees').get();
        for (final doc in snap.docs) {
          final email = doc.data()['email']?.toString().trim();
          if (email != null && email.isNotEmpty) {
            emails.add(email);
          } else {
            skippedEmployees++;
          }
        }
      }
      if (topic == 'clients' || topic == 'all') {
        final snap =
            await FirebaseFirestore.instance.collection('clients').get();
        for (final doc in snap.docs) {
          final email = doc.data()['email']?.toString().trim();
          if (email != null && email.isNotEmpty) {
            emails.add(email);
          } else {
            skippedClients++;
          }
        }
      }

      if (skippedEmployees > 0 || skippedClients > 0) {
        log(
          "⚠️ Topic $topic: skipped email for $skippedEmployees employee(s), $skippedClients client(s) with no email",
        );
      }

      final seenEmailKeys = <String>{};
      for (final email in emails) {
        final key = _emailDedupeKey(email);
        if (!seenEmailKeys.add(key)) {
          log("↩️ Duplicate topic email skipped (same address listed twice)");
          continue;
        }
        final details = <String, String>{
          'الوجهة': 'إشعار جماعي',
          'الموضوع': topic,
          if (emailDetails != null) ...emailDetails,
        };
        unawaited(
          EmailNotificationService.sendDetailedNotification(
            toEmail: email,
            title: title,
            body: body,
            notificationType: notificationType ?? 'إشعار جماعي',
            actionText: actionText,
            referenceId: referenceId,
            details: details,
          ),
        );
      }
    } catch (e) {
      log("❌ Email for topic error: $e");
    }
  }

  /// جلب معرفات الموظفين حسب الأدوار (مثل admin, supervisor).
  /// يستخدم whereIn (حد أقصى 10 قيم في الاستعلام).
  static Future<List<String>> getEmployeeIdsByRole(List<String> roles) async {
    if (roles.isEmpty) return [];
    try {
      final list = roles.take(10).toList();
      final snap =
          await FirebaseFirestore.instance
              .collection('employees')
              .where('role', whereIn: list)
              .get();
      return snap.docs.map((d) => d.id).where((id) => id.isNotEmpty).toList();
    } catch (e) {
      log("❌ getEmployeeIdsByRole: $e");
      return [];
    }
  }

  /// جلب معرفات الموظفين حسب القسم الدلالي (مثل publishing, promotion).
  static Future<List<String>> getEmployeeIdsByDepartment(
    String department,
  ) async {
    if (department.isEmpty) return [];
    try {
      final normalized = StorageKeys.normalizeDepartment(department);
      if (normalized.isEmpty) return [];
      final snap =
          await FirebaseFirestore.instance
              .collection('employees')
              .where('department', isEqualTo: normalized)
              .get();
      return snap.docs.map((d) => d.id).where((id) => id.isNotEmpty).toList();
    } catch (e) {
      log("❌ getEmployeeIdsByDepartment: $e");
      return [];
    }
  }

  /// إرسال إشعار FCM (وإيميل + حفظ في notifications) لعدة موظفين بدون تكرار.
  static Future<void> sendFcmToEmployees({
    required List<String> userIds,
    required String title,
    required String body,
    String? notificationType,
    String? actionText,
    String? referenceId,
    Map<String, String>? emailDetails,
    Map<String, String>? fcmDataExtras,
  }) async {
    final seen = <String>{};
    final batchSeenTokens = <String>{};
    final batchSeenEmails = <String>{};
    for (final id in userIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      unawaited(
        sendFcm(
          userId: trimmed,
          title: title,
          body: body,
          notificationType: notificationType,
          actionText: actionText,
          referenceId: referenceId,
          emailDetails: emailDetails,
          fcmDataExtras: fcmDataExtras,
          batchSeenTokens: batchSeenTokens,
          batchSeenEmails: batchSeenEmails,
        ),
      );
    }
  }
}
