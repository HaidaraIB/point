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
  final String? password; // 👈 كلمة السر
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
    this.password,
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
    String? password,
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
      password: password ?? this.password,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      onesignal: onesignal ?? this.onesignal,
    );
  }

  factory ClientModel.fromJson(Map<String, dynamic> json, String docId) {
    return ClientModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      address: json['address'],
      image: json['image'],
      status: json['status'],
      description: json['description'],
      startAt:
          json['startAt'] != null
              ? (json['startAt'] as Timestamp).toDate()
              : null,
      endAt:
          json['endAt'] != null ? (json['endAt'] as Timestamp).toDate() : null,
      password: json['password'],
      fcmToken: json['fcmToken'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      onesignal: json['onesignal'],
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
      "password": password,
      "fcmToken": fcmToken,
      "createdAt": createdAt,
      'onesignal': onesignal,
    };
  }
}
