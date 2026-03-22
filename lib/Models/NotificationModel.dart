import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String? id;
  final String? title;
  final String? body;
  final Map<String, dynamic>? data;
  final String? recipientId; // fcmToken بتاع المستلم
  final DateTime? createdAt;
  /// null أو true = لا يُحسب ضمن «غير مقروء» في الشارة؛ false = غير مقروء.
  final bool? isRead;

  NotificationModel({
    this.id,
    this.title,
    this.body,
    this.data,
    this.recipientId,
    this.createdAt,
    this.isRead,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? recipientId,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      recipientId: recipientId ?? this.recipientId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      data:
          json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      recipientId: json['recipientId'],
      createdAt: () {
        final v = json['createdAt'];
        if (v == null) return null;
        if (v is Timestamp) return v.toDate();
        if (v is String) return DateTime.tryParse(v);
        return DateTime.tryParse(v.toString());
      }(),
      isRead: json['isRead'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'recipientId': recipientId,
      'createdAt': createdAt?.toIso8601String(),
      if (isRead != null) 'isRead': isRead,
    };
  }
}
