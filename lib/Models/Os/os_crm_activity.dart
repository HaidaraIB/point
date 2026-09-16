import 'package:cloud_firestore/cloud_firestore.dart';

/// CRM activity log entry stored on [ClientModel.crmActivities].
class OsCrmActivity {
  const OsCrmActivity({
    required this.type,
    required this.content,
    required this.at,
    this.performedBy,
  });

  final String type;
  final String content;
  final DateTime at;
  final String? performedBy;

  factory OsCrmActivity.fromJson(Map<String, dynamic> json) {
    return OsCrmActivity(
      type: json['type'] as String? ?? OsCrmActivityType.note,
      content: json['content'] as String? ?? '',
      at: _parseAt(json['at']) ?? DateTime.now(),
      performedBy: json['performedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'content': content,
        'at': at,
        if (performedBy != null && performedBy!.trim().isNotEmpty)
          'performedBy': performedBy,
      };

  static DateTime? _parseAt(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class OsCrmActivityType {
  OsCrmActivityType._();

  static const note = 'NOTE';
  static const stageChange = 'STAGE_CHANGE';
  static const call = 'CALL';
  static const whatsapp = 'WHATSAPP';
  static const email = 'EMAIL';
}
