import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsPaytabsSettingsStatus.dart';
import 'package:point/Utils/EdgeFunctionRateLimiter.dart';
import 'package:point/Utils/app_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _functionName = 'paytabs';

class OsPaytabsSession {
  const OsPaytabsSession({
    required this.redirectUrl,
    required this.tranRef,
    required this.cartId,
  });

  final String redirectUrl;
  final String tranRef;
  final String cartId;

  factory OsPaytabsSession.fromJson(Map<String, dynamic> json) {
    return OsPaytabsSession(
      redirectUrl: (json['redirectUrl'] as String?)?.trim() ?? '',
      tranRef: (json['tranRef'] as String?)?.trim() ?? '',
      cartId: (json['cartId'] as String?)?.trim() ?? '',
    );
  }
}

/// Client for PayTabs settings and hosted payment sessions via Edge Function.
class OsPaytabsService {
  OsPaytabsService._();
  static final OsPaytabsService instance = OsPaytabsService._();

  OsPaytabsSettingsStatus? _cachedSettings;
  OsPaytabsSettingsStatus? get cachedSettings => _cachedSettings;

  static OsPaytabsSettingsStatus? parseSettingsFromResponse(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) return null;
    return OsPaytabsSettingsStatus.fromJson(map);
  }

  static OsPaytabsSession? parseSessionFromResponse(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) return null;
    final session = OsPaytabsSession.fromJson(map);
    if (session.redirectUrl.isEmpty) return null;
    return session;
  }

  static String? parseErrorCode(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final code = map['errorCode'];
    if (code is String && code.trim().isNotEmpty) return code.trim();
    return null;
  }

  Future<OsPaytabsSettingsStatus?> loadSettings({bool force = false}) async {
    if (!force && _cachedSettings != null) return _cachedSettings;
    try {
      final data = await _invokeRaw(body: {'action': 'get-settings'});
      final status = parseSettingsFromResponse(data);
      if (status != null) _cachedSettings = status;
      return status;
    } catch (e, st) {
      appLog('OsPaytabsService.loadSettings failed: $e\n$st');
      return _cachedSettings;
    }
  }

  Future<OsPaytabsSettingsStatus?> saveSettings({
    required String profileId,
    String? serverKey,
    String? clientKey,
    required String region,
    required String currency,
    required bool isEnabled,
    required String defaultBankAccountId,
  }) async {
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'save-settings',
          'profileId': profileId.trim(),
          if (serverKey != null) 'serverKey': serverKey.trim(),
          if (clientKey != null) 'clientKey': clientKey.trim(),
          'region': region.trim(),
          'currency': currency.trim(),
          'isEnabled': isEnabled,
          'defaultBankAccountId': defaultBankAccountId.trim(),
        },
      );
      final status = parseSettingsFromResponse(data);
      if (status != null) _cachedSettings = status;
      return status;
    } catch (e, st) {
      appLog('OsPaytabsService.saveSettings failed: $e\n$st');
      return null;
    }
  }

  Future<OsPaytabsSession?> createSession({
    required String invoiceId,
  }) async {
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'create-session',
          'invoiceId': invoiceId.trim(),
        },
      );
      return parseSessionFromResponse(data);
    } catch (e, st) {
      appLog('OsPaytabsService.createSession failed: $e\n$st');
      return null;
    }
  }

  /// Returns a hosted PayTabs URL for [invoice], creating a session if needed.
  Future<String?> resolveInvoicePaymentLink(OsInvoiceModel invoice) async {
    final existing = invoice.paytabsRedirectUrl?.trim() ?? '';
    if (existing.isNotEmpty) return existing;

    final invoiceId = invoice.id?.trim() ?? '';
    if (invoiceId.isEmpty) return null;

    final session = await createSession(invoiceId: invoiceId);
    return session?.redirectUrl;
  }

  Future<dynamic> _invokeRaw({required Map<String, dynamic> body}) async {
    final firebaseIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw StateError('Not authenticated');
    }

    final res = await EdgeFunctionRateLimiter.instance.run(() {
      return Supabase.instance.client.functions.invoke(
        _functionName,
        headers: <String, String>{
          'x-firebase-id-token': 'Bearer $firebaseIdToken',
        },
        body: body,
      );
    });

    final data = res.data;
    if (res.status == 403 ||
        (data is Map && data['errorCode'] == 'ERR_FORBIDDEN')) {
      throw StateError('Forbidden');
    }

    return data;
  }
}
