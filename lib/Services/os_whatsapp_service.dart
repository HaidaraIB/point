import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Models/Os/OsWhatsappLogModel.dart';
import 'package:point/Models/Os/OsWhatsappSettingsStatus.dart';
import 'package:point/Utils/EdgeFunctionRateLimiter.dart';
import 'package:point/Utils/app_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _functionName = 'os-whatsapp';

class OsWhatsappTestResult {
  const OsWhatsappTestResult({
    required this.displayPhoneNumber,
    required this.verifiedName,
  });

  final String displayPhoneNumber;
  final String verifiedName;

  factory OsWhatsappTestResult.fromJson(Map<String, dynamic> json) {
    return OsWhatsappTestResult(
      displayPhoneNumber:
          (json['displayPhoneNumber'] as String?)?.trim() ?? '',
      verifiedName: (json['verifiedName'] as String?)?.trim() ?? '',
    );
  }
}

class OsWhatsappTestOutcome {
  const OsWhatsappTestOutcome({this.result, this.errorMessage});

  final OsWhatsappTestResult? result;
  final String? errorMessage;
}

class OsWhatsappSendResult {
  const OsWhatsappSendResult({
    required this.success,
    this.wamid,
    this.logId,
    this.errorCode,
    this.errorMessage,
  });

  final bool success;
  final String? wamid;
  final String? logId;
  final String? errorCode;
  final String? errorMessage;
}

class OsWhatsappSessionWindowStatus {
  const OsWhatsappSessionWindowStatus({
    required this.open,
    required this.tracked,
    this.expiresAt,
    this.lastInboundAt,
  });

  final bool open;
  final bool tracked;
  final DateTime? expiresAt;
  final DateTime? lastInboundAt;

  static OsWhatsappSessionWindowStatus fromJson(Map<String, dynamic> map) {
    DateTime? parse(String? raw) {
      if (raw == null || raw.trim().isEmpty) return null;
      return DateTime.tryParse(raw.trim());
    }

    return OsWhatsappSessionWindowStatus(
      open: map['open'] == true,
      tracked: map['tracked'] == true,
      expiresAt: parse(map['expiresAt'] as String?),
      lastInboundAt: parse(map['lastInboundAt'] as String?),
    );
  }
}

/// Client for Meta WhatsApp settings and template send via Edge Function.
class OsWhatsappService {
  OsWhatsappService._();
  static final OsWhatsappService instance = OsWhatsappService._();

  OsWhatsappSettingsStatus? _cachedSettings;
  OsWhatsappSettingsStatus? get cachedSettings => _cachedSettings;

  static OsWhatsappSettingsStatus? parseSettingsFromResponse(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) return null;
    return OsWhatsappSettingsStatus.fromJson(map);
  }

  static String? parseErrorCode(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final code = map['errorCode'];
    if (code is String && code.trim().isNotEmpty) return code.trim();
    return null;
  }

  Future<OsWhatsappSettingsStatus?> loadSettings({bool force = false}) async {
    if (!force && _cachedSettings != null) return _cachedSettings;
    try {
      final data = await _invokeRaw(body: {'action': 'get-settings'});
      final status = parseSettingsFromResponse(data);
      if (status != null) _cachedSettings = status;
      return status;
    } catch (e, st) {
      appLog('OsWhatsappService.loadSettings failed: $e\n$st');
      return _cachedSettings;
    }
  }

  Future<OsWhatsappSettingsStatus?> saveSettings({
    String? accessToken,
    required String phoneNumberId,
    required String businessAccountId,
    required bool isEnabled,
  }) async {
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'save-settings',
          if (accessToken != null && accessToken.trim().isNotEmpty)
            'accessToken': accessToken.trim(),
          'phoneNumberId': phoneNumberId.trim(),
          'businessAccountId': businessAccountId.trim(),
          'isEnabled': isEnabled,
        },
      );
      final status = parseSettingsFromResponse(data);
      if (status != null) _cachedSettings = status;
      return status;
    } catch (e, st) {
      appLog('OsWhatsappService.saveSettings failed: $e\n$st');
      return null;
    }
  }

  static String? parseErrorMessage(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final msg = map['errorMessage'];
    if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    return null;
  }

  static String? _errorMessageFromFunctionException(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      return parseErrorMessage(details);
    }
    return null;
  }

  Future<OsWhatsappTestOutcome> testConnection() async {
    try {
      final data = await _invokeRaw(body: {'action': 'test-connection'});
      if (data is! Map) {
        return const OsWhatsappTestOutcome(
          errorMessage: null,
        );
      }
      final map = Map<String, dynamic>.from(data);
      if (map['success'] != true) {
        return OsWhatsappTestOutcome(
          errorMessage: parseErrorMessage(map) ?? parseErrorCode(map),
        );
      }
      final result = OsWhatsappTestResult.fromJson(map);
      _cachedSettings = await loadSettings(force: true);
      return OsWhatsappTestOutcome(result: result);
    } on FunctionException catch (e) {
      appLog(
        'OsWhatsappService.testConnection FunctionException: '
        'status=${e.status} details=${e.details}',
      );
      return OsWhatsappTestOutcome(
        errorMessage:
            _errorMessageFromFunctionException(e) ?? parseErrorCode(e.details),
      );
    } catch (e, st) {
      appLog('OsWhatsappService.testConnection failed: $e\n$st');
      return const OsWhatsappTestOutcome();
    }
  }

  Future<List<OsWhatsappTemplateModel>> listTemplates() async {
    try {
      final data = await _invokeRaw(body: {'action': 'list-templates'});
      if (data is! Map) return const [];
      final map = Map<String, dynamic>.from(data);
      if (map['success'] != true) return const [];
      final raw = map['templates'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => OsWhatsappTemplateModel.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .where((t) => t.name.isNotEmpty)
          .toList(growable: false);
    } catch (e, st) {
      appLog('OsWhatsappService.listTemplates failed: $e\n$st');
      return const [];
    }
  }

  Future<OsWhatsappSessionWindowStatus?> checkSessionWindow(
    String toPhone,
  ) async {
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'check-session-window',
          'toPhone': toPhone.trim(),
        },
      );
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      if (map['success'] != true) return null;
      return OsWhatsappSessionWindowStatus.fromJson(map);
    } catch (e, st) {
      appLog('OsWhatsappService.checkSessionWindow failed: $e\n$st');
      return null;
    }
  }

  Future<OsWhatsappSendResult> sendSession({
    required String toPhone,
    String? text,
    String? referenceId,
    String? recipientName,
    String? category,
    String? preview,
    String? documentBase64,
    String? documentFilename,
  }) async {
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'send-session',
          'toPhone': toPhone.trim(),
          if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
          if (referenceId != null) 'referenceId': referenceId.trim(),
          if (recipientName != null) 'recipientName': recipientName.trim(),
          if (category != null) 'category': category.trim(),
          if (preview != null) 'preview': preview.trim(),
          if (documentBase64 != null && documentBase64.isNotEmpty)
            'documentBase64': documentBase64,
          if (documentFilename != null && documentFilename.isNotEmpty)
            'documentFilename': documentFilename.trim(),
        },
      );
      if (data is! Map) {
        return const OsWhatsappSendResult(success: false);
      }
      final map = Map<String, dynamic>.from(data);
      if (map['success'] == true) {
        return OsWhatsappSendResult(
          success: true,
          wamid: (map['wamid'] as String?)?.trim(),
          logId: (map['logId'] as String?)?.trim(),
        );
      }
      return OsWhatsappSendResult(
        success: false,
        errorCode: parseErrorCode(map),
        logId: (map['logId'] as String?)?.trim(),
        errorMessage: parseErrorMessage(map),
      );
    } on FunctionException catch (e) {
      appLog(
        'OsWhatsappService.sendSession FunctionException: '
        'status=${e.status} details=${e.details}',
      );
      if (e.details is Map) {
        final map = Map<String, dynamic>.from(e.details as Map);
        return OsWhatsappSendResult(
          success: false,
          errorCode: parseErrorCode(map),
          logId: (map['logId'] as String?)?.trim(),
          errorMessage:
              parseErrorMessage(map) ?? _errorMessageFromFunctionException(e),
        );
      }
      return OsWhatsappSendResult(
        success: false,
        errorMessage: _errorMessageFromFunctionException(e),
      );
    } catch (e, st) {
      appLog('OsWhatsappService.sendSession failed: $e\n$st');
      return const OsWhatsappSendResult(success: false);
    }
  }

  Future<OsWhatsappSendResult> sendTemplate({
    required String toPhone,
    required String templateName,
    required String languageCode,
    List<String>? bodyParameters,
    List<String>? headerParameters,
    String? referenceId,
    String? recipientName,
    String? category,
    String? preview,
    String? documentBase64,
    String? documentFilename,
    bool templateHasDocumentHeader = false,
  }) async {
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'send-template',
          'toPhone': toPhone.trim(),
          'templateName': templateName.trim(),
          'languageCode': languageCode.trim(),
          'bodyParameters': bodyParameters ?? const [],
          'headerParameters': headerParameters ?? const [],
          if (referenceId != null) 'referenceId': referenceId.trim(),
          if (recipientName != null) 'recipientName': recipientName.trim(),
          if (category != null) 'category': category.trim(),
          if (preview != null) 'preview': preview.trim(),
          if (documentBase64 != null && documentBase64.isNotEmpty)
            'documentBase64': documentBase64,
          if (documentFilename != null && documentFilename.isNotEmpty)
            'documentFilename': documentFilename.trim(),
          'templateHasDocumentHeader': templateHasDocumentHeader,
        },
      );
      if (data is! Map) {
        return const OsWhatsappSendResult(success: false);
      }
      final map = Map<String, dynamic>.from(data);
      if (map['success'] == true) {
        return OsWhatsappSendResult(
          success: true,
          wamid: (map['wamid'] as String?)?.trim(),
          logId: (map['logId'] as String?)?.trim(),
        );
      }
      return OsWhatsappSendResult(
        success: false,
        errorCode: parseErrorCode(map),
        logId: (map['logId'] as String?)?.trim(),
        errorMessage: parseErrorMessage(map),
      );
    } on FunctionException catch (e) {
      appLog(
        'OsWhatsappService.sendTemplate FunctionException: '
        'status=${e.status} details=${e.details}',
      );
      if (e.details is Map) {
        final map = Map<String, dynamic>.from(e.details as Map);
        return OsWhatsappSendResult(
          success: false,
          errorCode: parseErrorCode(map),
          logId: (map['logId'] as String?)?.trim(),
          errorMessage:
              parseErrorMessage(map) ?? _errorMessageFromFunctionException(e),
        );
      }
      return OsWhatsappSendResult(
        success: false,
        errorMessage: _errorMessageFromFunctionException(e),
      );
    } catch (e, st) {
      appLog('OsWhatsappService.sendTemplate failed: $e\n$st');
      return const OsWhatsappSendResult(success: false);
    }
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
