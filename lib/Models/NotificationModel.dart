class NotificationModel {
  final String? id;
  final String? title;
  final String? body;
  final Map<String, dynamic>? data;
  final String? recipientId; // fcmToken بتاع المستلم
  final DateTime? createdAt;

  NotificationModel({
    this.id,
    this.title,
    this.body,
    this.data,
    this.recipientId,
    this.createdAt,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? recipientId,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      recipientId: recipientId ?? this.recipientId,
      createdAt: createdAt ?? this.createdAt,
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
      createdAt:
          json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'])
              : null,
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
    };
  }
}
