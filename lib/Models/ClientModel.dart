import 'package:cloud_firestore/cloud_firestore.dart';

class ClientModel {
  final String? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? address;
  final String? image;
  final String? status; // active, inactive, blocked ...
  final String? description; // 👈 الوصف
  final DateTime? startAt; // 👈 بداية
  final DateTime? endAt; // 👈 نهاية
  final String? authUid;
  final String? authStatus; // pendingActivation, active, pendingEmailVerification
  final String? fcmToken; // 👈 توكن الإشعارات
  final String? onesignal; // 👈 توكن الإشعارات
  final DateTime createdAt;

  ClientModel({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.address,
    this.image,
    this.status,
    this.description,
    this.startAt,
    this.endAt,
    this.authUid,
    this.authStatus,
    this.fcmToken,
    this.onesignal,
    required this.createdAt,
  });

  ClientModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? image,
    String? status,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    String? authUid,
    String? authStatus,
    String? fcmToken,
    String? onesignal,
    DateTime? createdAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      image: image ?? this.image,
      status: status ?? this.status,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      authUid: authUid ?? this.authUid,
      authStatus: authStatus ?? this.authStatus,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      onesignal: onesignal ?? this.onesignal,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  factory ClientModel.fromJson(Map<String, dynamic> json, String docId) {
    return ClientModel(
      id: json['id'] as String? ?? docId,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      image: json['image'] as String?,
      status: json['status'] as String?,
      description: json['description'] as String?,
      startAt: _parseDateTime(json['startAt']),
      endAt: _parseDateTime(json['endAt']),
      authUid: json['authUid'] as String?,
      authStatus: json['authStatus'] as String?,
      fcmToken: json['fcmToken'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      onesignal: json['onesignal'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      "name": name,
      "email": email,
      "phone": phone,
      "address": address,
      "image": image,
      "status": status,
      "description": description,
      "startAt": startAt,
      "endAt": endAt,
      if (authUid != null) "authUid": authUid,
      if (authStatus != null) "authStatus": authStatus,
      "fcmToken": fcmToken,
      "createdAt": createdAt,
      'onesignal': onesignal,
    };
  }
}
