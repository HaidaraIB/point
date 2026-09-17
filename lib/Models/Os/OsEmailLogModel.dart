import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/os_email_enums.dart';

class OsEmailLogModel {
  final String? id;
  final String type;
  final String recipientName;
  final String recipientEmail;
  final String subject;
  final String content;
  final String status;
  final String? referenceId;
  final String senderEmail;
  final int attachmentsCount;
  final DateTime sentAt;

  const OsEmailLogModel({
    this.id,
    required this.type,
    required this.recipientName,
    required this.recipientEmail,
    required this.subject,
    required this.content,
    this.status = OsEmailLogStatus.sent,
    this.referenceId,
    required this.senderEmail,
    this.attachmentsCount = 0,
    required this.sentAt,
  });

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory OsEmailLogModel.fromJson(Map<String, dynamic> json, String docId) {
    return OsEmailLogModel(
      id: json['id'] as String? ?? docId,
      type: json['type'] as String? ?? OsEmailCategory.custom,
      recipientName: json['recipientName'] as String? ?? '',
      recipientEmail: json['recipientEmail'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      content: json['content'] as String? ?? '',
      status: json['status'] as String? ?? OsEmailLogStatus.sent,
      referenceId: json['referenceId'] as String?,
      senderEmail: json['senderEmail'] as String? ?? '',
      attachmentsCount: (json['attachmentsCount'] as num?)?.toInt() ?? 0,
      sentAt: _parseDateTime(json['sentAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'subject': subject,
        'content': content,
        'status': status,
        if (referenceId != null) 'referenceId': referenceId,
        'senderEmail': senderEmail,
        'attachmentsCount': attachmentsCount,
        'sentAt': Timestamp.fromDate(sentAt),
      };
}
