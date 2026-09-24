import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Models/Os/OsActiveCardProviderStatus.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Utils/EdgeFunctionRateLimiter.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _functionName = 'card-payment';

class OsCardPaymentSession {
  const OsCardPaymentSession({
    required this.provider,
    required this.redirectUrl,
    required this.providerRef,
  });

  final String provider;
  final String redirectUrl;
  final String providerRef;

  factory OsCardPaymentSession.fromJson(Map<String, dynamic> json) {
    return OsCardPaymentSession(
      provider: (json['provider'] as String?)?.trim().toLowerCase() ?? '',
      redirectUrl: (json['redirectUrl'] as String?)?.trim() ?? '',
      providerRef: (json['providerRef'] as String?)?.trim() ?? '',
    );
  }
}

/// Unified card payment provider (PayTabs / Alqaseh) via Edge Function.
class OsCardPaymentService {
  OsCardPaymentService._();
  static final OsCardPaymentService instance = OsCardPaymentService._();

  OsActiveCardProviderStatus? _cachedActive;
  OsActiveCardProviderStatus? get cachedActive => _cachedActive;

  static OsActiveCardProviderStatus? parseActiveFromResponse(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) return null;
    return OsActiveCardProviderStatus.fromJson(map);
  }

  static OsCardPaymentSession? parseSessionFromResponse(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) return null;
    final session = OsCardPaymentSession.fromJson(map);
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

  Future<OsActiveCardProviderStatus?> loadActiveProvider({
    bool force = false,
  }) async {
    if (!force && _cachedActive != null) return _cachedActive;
    try {
      final data = await _invokeRaw(body: {'action': 'get-active'});
      final status = parseActiveFromResponse(data);
      if (status != null) _cachedActive = status;
      return status;
    } catch (e, st) {
      appLog('OsCardPaymentService.loadActiveProvider failed: $e\n$st');
      return _cachedActive;
    }
  }

  Future<OsActiveCardProviderStatus?> setActiveProvider({
    required String provider,
    required String defaultBankAccountId,
  }) async {
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'set-active',
          'provider': provider.trim().toLowerCase(),
          'defaultBankAccountId': defaultBankAccountId.trim(),
        },
      );
      final status = parseActiveFromResponse(data);
      if (status != null) _cachedActive = status;
      return status;
    } catch (e, st) {
      appLog('OsCardPaymentService.setActiveProvider failed: $e\n$st');
      return null;
    }
  }

  Future<OsCardPaymentSession?> createSession({
    required String invoiceId,
  }) async {
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'create-session',
          'invoiceId': invoiceId.trim(),
          'returnBaseUrl': AppConfig.resolveCardPaymentReturnBaseUrl(),
        },
      );
      return parseSessionFromResponse(data);
    } catch (e, st) {
      appLog('OsCardPaymentService.createSession failed: $e\n$st');
      return null;
    }
  }

  /// Returns a hosted payment URL for [invoice], creating a session if needed.
  Future<String?> resolveInvoicePaymentLink(OsInvoiceModel invoice) async {
    if (invoice.isPaid) return null;

    final invoiceId = invoice.id?.trim() ?? '';
    if (invoiceId.isEmpty) return null;

    final active = await loadActiveProvider();
    if (active == null || !active.isEnabled) return null;

    final cachedUrl = invoice.cardPaymentUrl?.trim().isNotEmpty == true
        ? invoice.cardPaymentUrl!.trim()
        : (invoice.paytabsRedirectUrl?.trim() ?? '');
    final cachedProvider = invoice.cardProvider?.trim().toLowerCase() ??
        (invoice.paytabsRedirectUrl?.isNotEmpty == true ? 'paytabs' : '');

    if (cachedUrl.isNotEmpty &&
        cachedProvider.isNotEmpty &&
        cachedProvider == active.provider) {
      return cachedUrl;
    }

    final session = await createSession(invoiceId: invoiceId);
    return session?.redirectUrl;
  }

  Future<dynamic> _invokeRaw({required Map<String, dynamic> body}) async {
    final firebaseIdToken =
        await FirebaseAuth.instance.currentUser?.getIdToken();
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
