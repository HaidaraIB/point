import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:point/Models/Os/os_whatsapp_enums.dart';



class OsWhatsappLogModel {

  final String? id;

  final String type;

  final String recipientName;

  final String recipientPhone;

  final String templateName;

  final String languageCode;

  final String status;

  final String preview;

  final String? referenceId;

  final String wamid;

  final String errorMessage;

  final DateTime sentAt;

  /// PDF or other media filename when sent with the message (e.g. invoice).
  final String attachmentFilename;



  const OsWhatsappLogModel({

    this.id,

    required this.type,

    required this.recipientName,

    required this.recipientPhone,

    required this.templateName,

    required this.languageCode,

    this.status = OsWhatsappLogStatus.sent,

    required this.preview,

    this.referenceId,

    this.wamid = '',

    this.errorMessage = '',

    this.attachmentFilename = '',

    required this.sentAt,

  });



  static dynamic _readField(Object? data, String key) {
    if (data is! Map) return null;
    try {
      return data[key];
    } catch (_) {
      return null;
    }
  }

  static String _str(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  static String? _strOrNull(dynamic value) {
    if (value == null) return null;
    final s = value is String ? value : value.toString();
    return s.trim().isEmpty ? null : s;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      final ms = value >= 1000000000000 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    try {
      final dynamic toDate = (value as dynamic).toDate;
      if (toDate is Function) {
        final converted = toDate();
        if (converted is DateTime) return converted;
      }
    } catch (_) {}
    return null;
  }

  factory OsWhatsappLogModel.fromJson(Map<String, dynamic> json, String docId) {
    return OsWhatsappLogModel(
      id: _strOrNull(json['id']) ?? docId,
      type: _str(json['type'], OsWhatsappCategory.custom),
      recipientName: _str(json['recipientName']),
      recipientPhone: _str(json['recipientPhone']),
      templateName: _str(json['templateName']),
      languageCode: _str(json['languageCode']),
      status: _str(json['status'], OsWhatsappLogStatus.sent),
      preview: _str(json['preview']),
      referenceId: _strOrNull(json['referenceId']),
      wamid: _str(json['wamid']),
      errorMessage: _str(json['errorMessage']),
      attachmentFilename: _str(json['attachmentFilename']),
      sentAt: _parseDateTime(json['sentAt']) ?? DateTime.now(),
    );
  }

  /// Reads fields directly from Firestore snapshot data (web / pipelines safe).
  factory OsWhatsappLogModel.fromFirestore(Object? data, String docId) {
    return OsWhatsappLogModel(
      id: _strOrNull(_readField(data, 'id')) ?? docId,
      type: _str(_readField(data, 'type'), OsWhatsappCategory.custom),
      recipientName: _str(_readField(data, 'recipientName')),
      recipientPhone: _str(_readField(data, 'recipientPhone')),
      templateName: _str(_readField(data, 'templateName')),
      languageCode: _str(_readField(data, 'languageCode')),
      status: _str(_readField(data, 'status'), OsWhatsappLogStatus.sent),
      preview: _str(_readField(data, 'preview')),
      referenceId: _strOrNull(_readField(data, 'referenceId')),
      wamid: _str(_readField(data, 'wamid')),
      errorMessage: _str(_readField(data, 'errorMessage')),
      attachmentFilename: _str(_readField(data, 'attachmentFilename')),
      sentAt: _parseDateTime(_readField(data, 'sentAt')) ?? DateTime.now(),
    );
  }
}



class OsWhatsappTemplateModel {
  const OsWhatsappTemplateModel({
    required this.name,
    required this.status,
    required this.category,
    required this.language,
    required this.components,
  });

  final String name;
  final String status;
  final String category;
  final String language;
  final List<dynamic> components;

  factory OsWhatsappTemplateModel.fromJson(Map<String, dynamic> json) {
    final components = json['components'];
    return OsWhatsappTemplateModel(
      name: (json['name'] as String?)?.trim() ?? '',
      status: (json['status'] as String?)?.trim() ?? '',
      category: (json['category'] as String?)?.trim() ?? '',
      language: (json['language'] as String?)?.trim() ?? '',
      components: components is List ? components : const [],
    );
  }

  int get bodyPlaceholderCount => _placeholderCount('BODY');
  int get headerTextPlaceholderCount => _headerTextPlaceholderCount();
  bool get hasDocumentHeader => _headerFormat() == 'DOCUMENT';

  /// Meta call-permission buttons trigger Graph #138017 for some recipients.
  bool get hasCallPermissionRequest => _hasCallPermissionRequest();

  bool get isEligibleForInvoiceSend =>
      hasDocumentHeader && !hasCallPermissionRequest;

  bool _hasCallPermissionRequest() {
    for (final raw in components) {
      final map = _componentMap(raw);
      if (map == null) continue;
      final type = (map['type'] as String?)?.toUpperCase() ?? '';
      if (type == 'CALL_PERMISSION_REQUEST') return true;
      if (type != 'BUTTONS') continue;
      final buttons = map['buttons'];
      if (buttons is! List) continue;
      for (final btn in buttons) {
        final btnMap = _componentMap(btn);
        if (btnMap == null) continue;
        final btnType = (btnMap['type'] as String?)?.toUpperCase() ?? '';
        if (btnType == 'CALL_PERMISSION_REQUEST' ||
            btnType == 'VOICE_CALL' ||
            btnType.contains('CALL_PERMISSION')) {
          return true;
        }
      }
    }
    return false;
  }

  static Map<String, dynamic>? _componentMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String? _headerFormat() {
    for (final raw in components) {
      final map = _componentMap(raw);
      if (map == null) continue;
      final type = (map['type'] as String?)?.toUpperCase() ?? '';
      if (type != 'HEADER') continue;
      return (map['format'] as String?)?.toUpperCase() ?? 'TEXT';
    }
    return null;
  }

  int _placeholderCount(String componentType) {
    for (final raw in components) {
      if (raw is! Map) continue;
      final type = (raw['type'] as String?)?.toUpperCase() ?? '';
      if (type != componentType) continue;
      final text = raw['text'] as String? ?? '';
      return RegExp(r'\{\{\d+\}\}').allMatches(text).length;
    }
    return 0;
  }

  int _headerTextPlaceholderCount() {
    for (final raw in components) {
      if (raw is! Map) continue;
      final type = (raw['type'] as String?)?.toUpperCase() ?? '';
      if (type != 'HEADER') continue;
      final format = (raw['format'] as String?)?.toUpperCase() ?? 'TEXT';
      if (format != 'TEXT') return 0;
      final text = raw['text'] as String? ?? '';
      return RegExp(r'\{\{\d+\}\}').allMatches(text).length;
    }
    return 0;
  }

  String previewBodyText() {
    for (final raw in components) {
      if (raw is! Map) continue;
      final type = (raw['type'] as String?)?.toUpperCase() ?? '';
      if (type == 'BODY') {
        return (raw['text'] as String?)?.trim() ?? name;
      }
    }
    return name;
  }
}
