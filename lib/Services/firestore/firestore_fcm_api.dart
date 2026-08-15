import 'dart:async';
import 'package:point/Utils/app_log.dart';
import 'dart:math' show Random, min;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/NotificationModel.dart';
import 'package:point/Services/EmailNotificationService.dart';
import 'package:point/Services/firestore/fcm_exceptions.dart';
import 'package:point/Services/firestore/firestore_notification_api.dart';
import 'package:point/Services/notification_email_policy.dart';
import 'package:point/Services/push_diagnostics.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إرسال FCM والتوكنات وتشخيصات الدفع.
class FirestoreFcmApi {
  FirestoreFcmApi._();

  static final Random _random = Random();

  /// Matches [supabase/functions/send-fcm/index.ts] `MAX_FCM_BATCH_RECIPIENTS`.
  static const int _maxFcmRecipientsPerRequest = 100;

  static String _newPushRequestId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(1 << 20).toRadixString(16);
    return 'push_$ms$rand';
  }

  static String _maskFcmToken(String t) {
    if (t.length <= 12) return '***';
    return '${t.substring(0, 6)}...${t.substring(t.length - 4)}';
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

  static String? _normalizePreferredLanguageCode(Object? raw) {
    final v = raw?.toString().trim().toLowerCase() ?? '';
    if (v.isEmpty) return null;
    if (v == 'ar' || v.startsWith('ar-')) return 'ar';
    if (v == 'en' || v.startsWith('en-')) return 'en';
    return null;
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
      final firebaseIdToken = await FirebaseAuth.instance.currentUser
          ?.getIdToken();
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
      appLog('claim-fcm-token non-ok: status=${res.status} data=$data');
      return false;
    } on FunctionException catch (e) {
      appLog(
        'claim-fcm-token FunctionException: status=${e.status} details=${e.details}',
      );
      return false;
    } catch (e, st) {
      appLog('claim-fcm-token error: $e');
      appLog('$st');
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

  /// Persists UI locale (`ar`|`en`) for scheduled digest push/email localization.
  static Future<void> setEmployeeLanguage({
    required String employeeId,
    required String code,
  }) async {
    final cleanedId = employeeId.trim();
    if (cleanedId.isEmpty) return;
    if (code != 'ar' && code != 'en') return;
    try {
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(cleanedId)
          .update({'language': code});
    } catch (e, st) {
      appLog('setEmployeeLanguage failed: $e');
      appLog('$st');
    }
  }

  static Future<void> setClientLanguage({
    required String clientId,
    required String code,
  }) async {
    final cleanedId = clientId.trim();
    if (cleanedId.isEmpty) return;
    if (code != 'ar' && code != 'en') return;
    try {
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(cleanedId)
          .update({'language': code});
    } catch (e, st) {
      appLog('setClientLanguage failed: $e');
      appLog('$st');
    }
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
      appLog('⚠️ logClientDiagnosticError failed: $e');
      appLog('StackTrace: $s');
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
    final targetLabel = token != null
        ? 'token=${_maskFcmToken(token)}'
        : 'topic=${topic ?? "(null)"}';

    final firebaseIdToken = await FirebaseAuth.instance.currentUser
        ?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw StateError('FirebaseAuth session required to send FCM.');
    }

    appLog(
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

      appLog(
        '✅ FCM invoke success. target=$targetLabel status=${res.status} data=${res.data}',
      );
    } on FunctionException catch (e) {
      final ex = _fcmSendExceptionFromFunctionException(e);
      appLog(
        '❌ FCM invoke failed. target=$targetLabel status=${ex.status} errorCode=${ex.errorCode} details=${ex.details}',
      );
      throw ex;
    }
  }

  static Future<void> _sendFcmBatchesAndApplyResults({
    required List<Map<String, dynamic>> recipients,
    required List<({String token, String userId, bool isClient})> metaAligned,
    required String title,
    required String body,
    Map<String, String>? data,
    required String parentRequestId,
    String? notificationType,
  }) async {
    if (recipients.isEmpty) return;
    assert(recipients.length == metaAligned.length);
    var offset = 0;
    while (offset < recipients.length) {
      final end = min(offset + _maxFcmRecipientsPerRequest, recipients.length);
      final chunk = recipients.sublist(offset, end);
      final chunkMeta = metaAligned.sublist(offset, end);
      offset = end;
      try {
        final out = await _sendFcmBatchViaFunction(
          recipients: chunk,
          title: title,
          body: body,
          data: data,
          requestId: parentRequestId,
          notificationType: notificationType,
        );
        await _applyFcmBatchResults(
          batchResponse: out,
          meta: chunkMeta,
          title: title,
          bodyLen: body.length,
          notificationType: notificationType,
        );
      } on FunctionException catch (e) {
        final ex = _fcmSendExceptionFromFunctionException(e);
        appLog(
          '❌ FCM batch invoke failed status=${ex.status} errorCode=${ex.errorCode}',
        );
        rethrow;
      }
    }
  }

  static Future<Map<String, dynamic>> _sendFcmBatchViaFunction({
    required List<Map<String, dynamic>> recipients,
    required String title,
    required String body,
    Map<String, String>? data,
    required String requestId,
    String? notificationType,
  }) async {
    final firebaseIdToken = await FirebaseAuth.instance.currentUser
        ?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw StateError('FirebaseAuth session required to send FCM.');
    }

    appLog(
      '➡️ FCM batch invoke start. count=${recipients.length} title="$title" bodyLen=${body.length}',
    );

    final res = await Supabase.instance.client.functions.invoke(
      'send-fcm',
      headers: <String, String>{
        'x-firebase-id-token': 'Bearer $firebaseIdToken',
      },
      body: <String, dynamic>{
        'recipients': recipients,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
        'requestId': requestId,
        if (notificationType != null) 'notificationType': notificationType,
      },
    );

    appLog('✅ FCM batch invoke done. status=${res.status} data=${res.data}');

    if (res.data is! Map) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(res.data! as Map);
  }

  static Future<void> _applyFcmBatchResults({
    required Map<String, dynamic> batchResponse,
    required List<({String token, String userId, bool isClient})> meta,
    required String title,
    required int bodyLen,
    String? notificationType,
  }) async {
    final results = batchResponse['results'];
    if (results is! List) return;
    for (var i = 0; i < results.length; i++) {
      final row = results[i];
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final ok = map['ok'] == true;
      final skipped = map['skipped'] == true;
      if (skipped) continue;
      if (ok) continue;

      final requestId = map['requestId']?.toString() ?? '';
      final recipientId = map['recipientId']?.toString();
      final recipientType = map['recipientType']?.toString();
      final tokenMasked = map['tokenMasked']?.toString();

      await PushDiagnostics.logFailure(
        requestId: requestId.isNotEmpty ? requestId : _newPushRequestId(),
        stage: 'app_result',
        targetType: 'token',
        recipientId: recipientId,
        recipientType: recipientType,
        tokenMasked: tokenMasked,
        title: title,
        bodyLen: bodyLen,
        notificationType: notificationType,
        fcmHttpStatus: _asInt(map['fcmHttpStatus']),
        fcmErrorCode: map['fcmErrorCode']?.toString(),
        fcmErrorStatus: map['fcmErrorStatus']?.toString(),
        fcmErrorMessage: map['fcmErrorMessage']?.toString(),
        details: map['details'],
      );

      if (!_fcmPayloadImpliesInvalidToken(map['details'])) continue;
      if (i >= meta.length) continue;
      final m = meta[i];
      if (m.isClient) {
        await _removeClientFcmToken(clientId: m.userId, token: m.token);
      } else {
        await _removeEmployeeFcmToken(employeeId: m.userId, token: m.token);
      }
      appLog('🧹 Removed invalid token (batch) uid=${m.userId}');
    }
  }

  static int? _asInt(Object? o) {
    if (o is int) return o;
    if (o is num) return o.toInt();
    return int.tryParse(o?.toString() ?? '');
  }

  static bool _shouldPersistFcmToNotificationInbox(String? notificationType) {
    final t = notificationType?.trim() ?? '';
    return t != 'chat_message' && t != 'chat_unread_digest';
  }

  static Map<String, dynamic>? _navigationInboxData({
    String? notificationType,
    Map<String, String>? fcmDataExtras,
  }) {
    final m = <String, dynamic>{};
    final t = notificationType?.trim() ?? '';
    if (t.isNotEmpty) m['notificationType'] = t;
    if (fcmDataExtras != null) {
      for (final e in fcmDataExtras.entries) {
        final k = e.key.trim();
        final v = e.value.trim();
        if (k.isEmpty || v.isEmpty) continue;
        m[k] = v;
      }
    }
    return m.isEmpty ? null : m;
  }

  static String? _signedInAuthUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    return uid.isEmpty ? null : uid;
  }

  /// Signed-in employee document id (maintained by [HomeController]).
  /// Used as a fallback when recipient `authUid` is missing.
  static String? sessionEmployeeId;

  /// Skips notifying the signed-in employee about their own action.
  /// Prefer [excludeUserIds]; also matches session id / recipient `authUid`.
  static bool _shouldExcludeEmployeeRecipient({
    required String recipientId,
    required Map<String, dynamic>? data,
    required bool excludeCurrentActor,
    Set<String>? excludeUserIds,
  }) {
    final trimmed = recipientId.trim();
    if (trimmed.isEmpty) return true;
    final excluded = _normalizedExcludeUserIds(excludeUserIds);
    if (excluded.contains(trimmed)) return true;
    if (!excludeCurrentActor) return false;
    final sessionId = sessionEmployeeId?.trim() ?? '';
    if (sessionId.isNotEmpty && sessionId == trimmed) return true;
    final authUid = _signedInAuthUid();
    if (authUid == null) return false;
    final recipientAuth = data?['authUid']?.toString().trim() ?? '';
    return recipientAuth.isNotEmpty && recipientAuth == authUid;
  }

  static Set<String> _normalizedExcludeUserIds(Set<String>? excludeUserIds) {
    if (excludeUserIds == null || excludeUserIds.isEmpty) {
      return const <String>{};
    }
    return {
      for (final id in excludeUserIds)
        if (id.trim().isNotEmpty) id.trim(),
    };
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
    bool useSupabaseTemplateWrapper = false,

    /// إن وُجد يُستخدم كما هو؛ وإلا تُطبَّق [NotificationEmailPolicy] حسب [notificationType].
    bool? sendEmail,
    Set<String>? batchSeenTokens,

    /// يمنع إرسال أكثر من بريد لنفس العنوان ضمن دفعة واحدة (مثل [sendFcmToEmployees]).
    Set<String>? batchSeenEmails,

    /// When true (default), do not notify the signed-in employee about their own action.
    bool excludeCurrentActor = true,
    Set<String>? excludeUserIds,
  }) async {
    try {
      final effectiveSendEmail =
          sendEmail ??
          NotificationEmailPolicy.shouldSendEmail(notificationType);

      // 1. هات بيانات المستخدم من Firestore
      final trimmedUserId = userId.trim();
      final doc = await FirebaseFirestore.instance
          .collection("employees")
          .doc(trimmedUserId)
          .get();

      if (!doc.exists) {
        appLog("⚠️ Employee not found: $userId");
        return;
      }

      final data = doc.data();
      if (_shouldExcludeEmployeeRecipient(
        recipientId: trimmedUserId,
        data: data,
        excludeCurrentActor: excludeCurrentActor,
        excludeUserIds: excludeUserIds,
      )) {
        appLog(
          '↩️ Skipping self-notification for employee $trimmedUserId '
          '(type=${notificationType ?? "null"})',
        );
        return;
      }

      final email = data?['email']?.toString().trim();
      final tokens = _extractFcmTokens(data);
      final rawRecipientName = data?['name']?.toString().trim();
      final preferredLanguageCode = _normalizePreferredLanguageCode(
        data?['language'],
      );
      final recipientRole = data?['role'];
      final recipientName =
          (rawRecipientName != null && rawRecipientName.isNotEmpty)
          ? rawRecipientName
          : 'الموظف';

      if (_shouldPersistFcmToNotificationInbox(notificationType)) {
        await FirestoreNotificationApi.addNotification(
          NotificationModel(
            title: title,
            body: body,
            recipientId: trimmedUserId,
            createdAt: DateTime.now(),
            isRead: false,
            data: _navigationInboxData(
              notificationType: notificationType,
              fcmDataExtras: fcmDataExtras,
            ),
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
          appLog(
            "↩️ Duplicate batch email skipped ($recipientName · $trimmedUserId)",
          );
        }
      }
      if (sendThisEmail) {
        // إرسال إيميل حتى عند غياب FCM (من لم يثبت التطبيق أو عطّل الإشعارات يظل يحصل على الإيميل)
        final details = <String, String>{
          if (emailDetails != null) ...emailDetails,
        };
        unawaited(
          EmailNotificationService.sendDetailedNotification(
            toEmail: email!,
            title: title,
            body: body,
            useSupabaseTemplateWrapper: useSupabaseTemplateWrapper,
            recipientLabel: recipientName,
            actionText: actionText,
            details: details,
            languageCode: preferredLanguageCode,
          ),
        );
      } else if (effectiveSendEmail && (email == null || email.isEmpty)) {
        appLog(
          "⚠️ Email missing for $recipientRole $recipientName — skipping email notification",
        );
      }

      // إذا المستخدم لا يريد Push، ننهي بدون فحص token أو إرسال push.
      if (!sendPush) return;

      if (tokens.isEmpty) {
        appLog(
          "⚠️ fcmToken missing for $recipientRole $recipientName — push not sent",
        );
        return;
      }

      final parentRequestId = _newPushRequestId();
      final recipients = <Map<String, dynamic>>[];
      final meta = <({String token, String userId, bool isClient})>[];
      final baseData = <String, String>{
        'type': 'internal',
        'id': trimmedUserId,
        'url': 'https://example.com',
        if (notificationType != null && notificationType.trim().isNotEmpty)
          'notificationType': notificationType.trim(),
        if (fcmDataExtras != null) ...fcmDataExtras,
      };

      for (final token in tokens) {
        final cleanedToken = token.trim();
        if (cleanedToken.isEmpty) continue;
        if (batchSeenTokens != null && !batchSeenTokens.add(cleanedToken)) {
          appLog(
            "↩️ Duplicate batch token skipped for $recipientRole $recipientName (${_maskFcmToken(cleanedToken)})",
          );
          continue;
        }
        recipients.add(<String, dynamic>{
          'token': cleanedToken,
          'recipientId': trimmedUserId,
          'recipientType': 'employee',
          'requestId': _newPushRequestId(),
        });
        meta.add((token: cleanedToken, userId: trimmedUserId, isClient: false));
      }

      if (recipients.isEmpty) return;

      try {
        await _sendFcmBatchesAndApplyResults(
          recipients: recipients,
          metaAligned: meta,
          title: title,
          body: body,
          data: baseData,
          parentRequestId: parentRequestId,
          notificationType: notificationType,
        );
      } on FunctionException catch (e) {
        throw _fcmSendExceptionFromFunctionException(e);
      }
      appLog("✅ FCM Response: $recipientName");
    } on FcmSendException catch (e) {
      switch (e.errorCode) {
        case 'ERR_METHOD_NOT_ALLOWED':
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsMethodNotAllowed}");
          break;
        case 'ERR_UNAUTHORIZED':
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsUnauthorized}");
          break;
        case 'ERR_FORBIDDEN':
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsForbidden}");
          break;
        case 'ERR_MISSING_TOKEN':
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsMissingToken}");
          break;
        case 'ERR_INVALID_DATA':
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsInvalidData}");
          break;
        default:
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsServer} | $e");
      }
    } catch (e) {
      appLog("❌ FCM Error: $e");
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
    bool useSupabaseTemplateWrapper = false,

    /// إن وُجد يُستخدم كما هو؛ وإلا تُطبَّق [NotificationEmailPolicy] حسب [notificationType].
    bool? sendEmail,
    Set<String>? batchSeenTokens,
    Set<String>? batchSeenEmails,
  }) async {
    try {
      final effectiveSendEmail =
          sendEmail ??
          NotificationEmailPolicy.shouldSendEmail(notificationType);

      // 1. هات بيانات المستخدم من Firestore
      final doc = await FirebaseFirestore.instance
          .collection("clients")
          .doc(userId)
          .get();

      if (!doc.exists) {
        appLog("⚠️ Client not found: $userId");
        return;
      }

      final data = doc.data();
      final email = data?['email']?.toString().trim();
      final tokens = _extractFcmTokens(data);
      final rawRecipientName = data?['name']?.toString().trim();
      final preferredLanguageCode = _normalizePreferredLanguageCode(
        data?['language'],
      );
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
            data: _navigationInboxData(
              notificationType: notificationType,
              fcmDataExtras: fcmDataExtras,
            ),
          ),
        );
      }

      var sendThisClientEmail =
          effectiveSendEmail && email != null && email.isNotEmpty;
      if (sendThisClientEmail && batchSeenEmails != null) {
        final key = _emailDedupeKey(email);
        if (!batchSeenEmails.add(key)) {
          sendThisClientEmail = false;
          appLog(
            "↩️ Duplicate batch email skipped (client $recipientName · $trimmedUserId)",
          );
        }
      }
      if (sendThisClientEmail) {
        final details = <String, String>{
          if (emailDetails != null) ...emailDetails,
        };
        unawaited(
          EmailNotificationService.sendDetailedNotification(
            toEmail: email!,
            title: title,
            body: body,
            useSupabaseTemplateWrapper: useSupabaseTemplateWrapper,
            recipientLabel: recipientName,
            actionText: actionText,
            details: details,
            languageCode: preferredLanguageCode,
          ),
        );
      } else if (effectiveSendEmail && (email == null || email.isEmpty)) {
        appLog(
          "⚠️ Email missing for client $recipientName — skipping email notification",
        );
      }

      if (!sendPush) return;

      if (tokens.isEmpty) {
        appLog("⚠️ fcmToken missing for client $recipientName — push not sent");
        return;
      }

      final parentRequestIdClient = _newPushRequestId();
      final recipientsClient = <Map<String, dynamic>>[];
      final metaClient = <({String token, String userId, bool isClient})>[];
      final baseDataClient = <String, String>{
        'type': 'internal',
        'id': trimmedUserId,
        'url': 'https://example.com',
        if (notificationType != null && notificationType.trim().isNotEmpty)
          'notificationType': notificationType.trim(),
        if (fcmDataExtras != null) ...fcmDataExtras,
      };

      for (final token in tokens) {
        final cleanedToken = token.trim();
        if (cleanedToken.isEmpty) continue;
        if (batchSeenTokens != null && !batchSeenTokens.add(cleanedToken)) {
          appLog(
            "↩️ Duplicate batch token skipped for client $recipientName (${_maskFcmToken(cleanedToken)})",
          );
          continue;
        }
        recipientsClient.add(<String, dynamic>{
          'token': cleanedToken,
          'recipientId': trimmedUserId,
          'recipientType': 'client',
          'requestId': _newPushRequestId(),
        });
        metaClient.add((
          token: cleanedToken,
          userId: trimmedUserId,
          isClient: true,
        ));
      }

      if (recipientsClient.isEmpty) return;

      try {
        await _sendFcmBatchesAndApplyResults(
          recipients: recipientsClient,
          metaAligned: metaClient,
          title: title,
          body: body,
          data: baseDataClient,
          parentRequestId: parentRequestIdClient,
          notificationType: notificationType,
        );
      } on FunctionException catch (e) {
        throw _fcmSendExceptionFromFunctionException(e);
      }
      appLog("✅ FCM sent to client: $recipientName");
    } on FcmSendException catch (e) {
      switch (e.errorCode) {
        case 'ERR_METHOD_NOT_ALLOWED':
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsMethodNotAllowed}");
          break;
        case 'ERR_UNAUTHORIZED':
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsUnauthorized}");
          break;
        case 'ERR_FORBIDDEN':
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsForbidden}");
          break;
        case 'ERR_MISSING_TOKEN':
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsMissingToken}");
          break;
        case 'ERR_INVALID_DATA':
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsInvalidData}");
          break;
        default:
          appLog("❌ FCM Error: ${AppLocaleKeys.errorsServer} | $e");
      }
    } catch (e) {
      appLog("❌ FCM Error: $e");
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
          data: notificationType != null && notificationType.trim().isNotEmpty
              ? <String, String>{'notificationType': notificationType.trim()}
              : null,
          requestId: requestId,
          recipientType: 'topic',
          notificationType: notificationType,
        );
        appLog("✅ FCM topic sent: $topic");
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
      await PushDiagnostics.logFailure(
        requestId: requestId,
        stage: 'app_result',
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
      appLog("❌ FCM Error: $e");
    } catch (e) {
      appLog("❌ FCM Error: $e");
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
        final snap = await FirebaseFirestore.instance
            .collection('employees')
            .get();
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
        final snap = await FirebaseFirestore.instance
            .collection('clients')
            .get();
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
        appLog(
          "⚠️ Topic $topic: skipped email for $skippedEmployees employee(s), $skippedClients client(s) with no email",
        );
      }

      final seenEmailKeys = <String>{};
      final dedupedEmails = <String>[];
      for (final email in emails) {
        final key = _emailDedupeKey(email);
        if (!seenEmailKeys.add(key)) {
          appLog(
            "↩️ Duplicate topic email skipped (same address listed twice)",
          );
          continue;
        }
        dedupedEmails.add(email);
      }

      if (dedupedEmails.isEmpty) return;

      final details = <String, String>{
        'الوجهة': 'إشعار جماعي',
        'الموضوع': topic,
        if (emailDetails != null) ...emailDetails,
      };
      final plainLines = <String>[
        body.trim(),
        '',
        for (final e in details.entries)
          if (e.key.trim().isNotEmpty && e.value.trim().isNotEmpty)
            '${e.key.trim()}: ${e.value.trim()}',
      ];
      final wrapperBody = plainLines.join('\n').trim();
      unawaited(
        EmailNotificationService.sendPlainNotificationBatch(
          toEmails: dedupedEmails,
          subject: title,
          body: wrapperBody,
        ),
      );
    } catch (e) {
      appLog("❌ Email for topic error: $e");
    }
  }

  /// جلب معرفات الموظفين حسب الأدوار (مثل admin, supervisor).
  /// يستخدم whereIn (حد أقصى 10 قيم في الاستعلام).
  static Future<List<String>> getEmployeeIdsByRole(List<String> roles) async {
    if (roles.isEmpty) return [];
    try {
      final list = roles.take(10).toList();
      final snap = await FirebaseFirestore.instance
          .collection('employees')
          .where('role', whereIn: list)
          .get();
      return snap.docs.map((d) => d.id).where((id) => id.isNotEmpty).toList();
    } catch (e) {
      appLog("❌ getEmployeeIdsByRole: $e");
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
      final snap = await FirebaseFirestore.instance
          .collection('employees')
          .where('departments', arrayContains: normalized)
          .get();
      return snap.docs.map((d) => d.id).where((id) => id.isNotEmpty).toList();
    } catch (e) {
      appLog("❌ getEmployeeIdsByDepartment: $e");
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

    /// When true (default), do not notify the signed-in employee about their own action.
    bool excludeCurrentActor = true,
    Set<String>? excludeUserIds,
  }) async {
    try {
      final excludedIds = _normalizedExcludeUserIds(excludeUserIds);
      final seen = <String>{};
      final orderedIds = <String>[];
      for (final id in userIds) {
        final trimmed = id.trim();
        if (trimmed.isEmpty || seen.contains(trimmed)) continue;
        if (excludedIds.contains(trimmed)) continue;
        seen.add(trimmed);
        orderedIds.add(trimmed);
      }
      if (orderedIds.isEmpty) return;

      final snapshots = await Future.wait(
        orderedIds.map(
          (id) =>
              FirebaseFirestore.instance.collection('employees').doc(id).get(),
        ),
      );

      final batchSeenTokens = <String>{};
      final batchSeenEmails = <String>{};
      final emailItems = <DetailedEmailBatchItem>[];
      final fcmRecipients = <Map<String, dynamic>>[];
      final fcmMeta = <({String token, String userId, bool isClient})>[];

      final effectiveSendEmail = NotificationEmailPolicy.shouldSendEmail(
        notificationType,
      );

      for (var i = 0; i < snapshots.length; i++) {
        final doc = snapshots[i];
        final trimmedUserId = orderedIds[i];
        if (!doc.exists) {
          appLog('⚠️ Employee not found: $trimmedUserId');
          continue;
        }

        final data = doc.data();
        if (_shouldExcludeEmployeeRecipient(
          recipientId: trimmedUserId,
          data: data,
          excludeCurrentActor: excludeCurrentActor,
          excludeUserIds: null, // already filtered above
        )) {
          appLog(
            '↩️ Skipping self-notification for employee $trimmedUserId '
            '(type=${notificationType ?? "null"})',
          );
          continue;
        }

        final email = data?['email']?.toString().trim();
        final tokens = _extractFcmTokens(data);
        final rawRecipientName = data?['name']?.toString().trim();
        final preferredLanguageCode = _normalizePreferredLanguageCode(
          data?['language'],
        );
        final recipientRole = data?['role'];
        final recipientName =
            (rawRecipientName != null && rawRecipientName.isNotEmpty)
            ? rawRecipientName
            : 'الموظف';

        if (_shouldPersistFcmToNotificationInbox(notificationType)) {
          await FirestoreNotificationApi.addNotification(
            NotificationModel(
              title: title,
              body: body,
              recipientId: trimmedUserId,
              createdAt: DateTime.now(),
              isRead: false,
              data: _navigationInboxData(
                notificationType: notificationType,
                fcmDataExtras: fcmDataExtras,
              ),
            ),
          );
        }

        var sendThisEmail =
            effectiveSendEmail && email != null && email.isNotEmpty;
        if (sendThisEmail) {
          final key = _emailDedupeKey(email);
          if (!batchSeenEmails.add(key)) {
            sendThisEmail = false;
            appLog(
              '↩️ Duplicate batch email skipped ($recipientName · $trimmedUserId)',
            );
          }
        }
        if (sendThisEmail) {
          final details = <String, String>{
            if (emailDetails != null) ...emailDetails,
          };
          emailItems.add(
            DetailedEmailBatchItem(
              toEmail: email!,
              title: title,
              body: body,
              recipientLabel: recipientName,
              actionText: actionText,
              details: details,
              languageCode: preferredLanguageCode,
            ),
          );
        } else if (effectiveSendEmail && (email == null || email.isEmpty)) {
          appLog(
            '⚠️ Email missing for $recipientRole $recipientName — skipping email notification',
          );
        }

        for (final token in tokens) {
          final cleanedToken = token.trim();
          if (cleanedToken.isEmpty) continue;
          if (!batchSeenTokens.add(cleanedToken)) {
            appLog(
              '↩️ Duplicate batch token skipped for $recipientName (${_maskFcmToken(cleanedToken)})',
            );
            continue;
          }
          fcmRecipients.add(<String, dynamic>{
            'token': cleanedToken,
            'recipientId': trimmedUserId,
            'recipientType': 'employee',
            'requestId': _newPushRequestId(),
            'data': <String, String>{
              'type': 'internal',
              'id': trimmedUserId,
              'url': 'https://example.com',
              if (notificationType != null &&
                  notificationType.trim().isNotEmpty)
                'notificationType': notificationType.trim(),
              if (fcmDataExtras != null) ...fcmDataExtras,
            },
          });
          fcmMeta.add((
            token: cleanedToken,
            userId: trimmedUserId,
            isClient: false,
          ));
        }
      }

      if (emailItems.isNotEmpty) {
        unawaited(
          EmailNotificationService.sendDetailedNotificationBatch(
            emailItems,
            useSupabaseTemplateWrapper: false,
          ),
        );
      }

      if (fcmRecipients.isEmpty) return;

      final parentRequestId = _newPushRequestId();
      await _sendFcmBatchesAndApplyResults(
        recipients: fcmRecipients,
        metaAligned: fcmMeta,
        title: title,
        body: body,
        data: null,
        parentRequestId: parentRequestId,
        notificationType: notificationType,
      );
    } on FunctionException catch (e) {
      final ex = _fcmSendExceptionFromFunctionException(e);
      switch (ex.errorCode) {
        case 'ERR_METHOD_NOT_ALLOWED':
          appLog('❌ FCM Error: ${AppLocaleKeys.errorsMethodNotAllowed}');
          break;
        case 'ERR_UNAUTHORIZED':
          appLog('❌ FCM Error: ${AppLocaleKeys.errorsUnauthorized}');
          break;
        case 'ERR_FORBIDDEN':
          appLog('❌ FCM Error: ${AppLocaleKeys.errorsForbidden}');
          break;
        case 'ERR_MISSING_TOKEN':
          appLog('❌ FCM Error: ${AppLocaleKeys.errorsMissingToken}');
          break;
        case 'ERR_INVALID_DATA':
          appLog('❌ FCM Error: ${AppLocaleKeys.errorsInvalidData}');
          break;
        default:
          appLog('❌ FCM Error: ${AppLocaleKeys.errorsServer} | $ex');
      }
    } catch (e) {
      appLog('❌ FCM Error: $e');
    }
  }
}
