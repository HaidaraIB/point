import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Models/Os/OsAlqasehSettingsStatus.dart';
import 'package:point/Utils/EdgeFunctionRateLimiter.dart';
import 'package:point/Utils/app_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _functionName = 'alqaseh';

/// Client for Alqaseh settings via Edge Function.
class OsAlqasehService {
  OsAlqasehService._();
  static final OsAlqasehService instance = OsAlqasehService._();

  OsAlqasehSettingsStatus? _cachedSettings;
  OsAlqasehSettingsStatus? get cachedSettings => _cachedSettings;

  static OsAlqasehSettingsStatus? parseSettingsFromResponse(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) return null;
    return OsAlqasehSettingsStatus.fromJson(map);
  }

  Future<OsAlqasehSettingsStatus?> loadSettings({
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
      appLog('OsAlqasehService.loadSettings failed: $e\n$st');
      return _cachedSettings;
    }
  }

  Future<OsAlqasehSettingsStatus?> saveSettings({
    required String environment,
    required String clientId,
    String? clientSecret,
    required String currency,
    required int tokenExpiryHours,
  }) async {
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'save-settings',
          'environment': environment.trim(),
          'clientId': clientId.trim(),
          if (clientSecret != null) 'clientSecret': clientSecret.trim(),
          'currency': currency.trim(),
          'tokenExpiryHours': tokenExpiryHours,
        },
      );
      final status = parseSettingsFromResponse(data);
      if (status != null) _cachedSettings = status;
      return status;
    } catch (e, st) {
      appLog('OsAlqasehService.saveSettings failed: $e\n$st');
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
