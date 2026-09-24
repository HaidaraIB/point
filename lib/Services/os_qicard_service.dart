import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Models/Os/OsQicardSettingsStatus.dart';
import 'package:point/Utils/EdgeFunctionRateLimiter.dart';
import 'package:point/Utils/app_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _functionName = 'qicard';

/// Client for Qi Card settings via Edge Function.
class OsQicardService {
  OsQicardService._();
  static final OsQicardService instance = OsQicardService._();

  OsQicardSettingsStatus? _cachedSettings;
  OsQicardSettingsStatus? get cachedSettings => _cachedSettings;

  static OsQicardSettingsStatus? parseSettingsFromResponse(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) return null;
    return OsQicardSettingsStatus.fromJson(map);
  }

  Future<OsQicardSettingsStatus?> loadSettings({
    bool force = false,
    String? environment,
  }) async {
    if (!force && environment == null && _cachedSettings != null) {
      return _cachedSettings;
    }
    try {
      final data = await _invokeRaw(body: {
        'action': 'get-settings',
        if (environment != null) 'environment': environment.trim(),
      });
      final status = parseSettingsFromResponse(data);
      if (status != null) _cachedSettings = status;
      return status;
    } catch (e, st) {
      appLog('OsQicardService.loadSettings failed: $e\n$st');
      return _cachedSettings;
    }
  }

  Future<OsQicardSettingsStatus?> saveSettings({
    required String environment,
    required String username,
    String? password,
    required String terminalId,
    required String currency,
    String? liveApiBase,
    String? webhookPublicKey,
  }) async {
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'save-settings',
          'environment': environment.trim(),
          'username': username.trim(),
          if (password != null) 'password': password.trim(),
          'terminalId': terminalId.trim(),
          'currency': currency.trim(),
          if (liveApiBase != null) 'liveApiBase': liveApiBase.trim(),
          if (webhookPublicKey != null)
            'webhookPublicKey': webhookPublicKey.trim(),
        },
      );
      final status = parseSettingsFromResponse(data);
      if (status != null) _cachedSettings = status;
      return status;
    } catch (e, st) {
      appLog('OsQicardService.saveSettings failed: $e\n$st');
      return null;
    }
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
