import 'package:point/Services/StorageKeys.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeModel {
  String? id;
  final String? name;
  final String? email;
  final String? phone;
  final String role; // (staff, supervisor, media buyer ...)
  /// Canonical department slugs (see [StorageKeys.departmentSlugs]). Empty for admin/supervisor.
  final List<String> departments;
  final String? fcmToken;
  final String? onesignal;
  final DateTime? hireDate;
  final String? status;
  final DateTime createdAt;
  final String? authUid;
  final String? authStatus; // pendingActivation, active, pendingEmailVerification
  final String? image;
  /// Presence heartbeat timestamp (used by employees table status).
  final DateTime? activeChatUpdatedAt;

  EmployeeModel({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.departments = const [],
    this.fcmToken,
    this.onesignal,
    this.hireDate,
    required this.status,
    required this.createdAt,
    this.authUid,
    this.authStatus,
    this.image,
    this.activeChatUpdatedAt,
  });

  /// First department slug, if any (e.g. notifications / legacy single-field UX).
  String? get primaryDepartment =>
      departments.isEmpty ? null : departments.first;

  bool hasDepartment(String semanticDepartment) => departments.any(
        (d) => StorageKeys.matchesDepartment(d, semanticDepartment),
      );

  EmployeeModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    List<String>? departments,
    String? fcmToken,
    String? onesignal,
    DateTime? hireDate,
    String? status,
    DateTime? createdAt,
    String? authUid,
    String? authStatus,
    String? image,
    DateTime? activeChatUpdatedAt,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      departments: departments ?? this.departments,
      fcmToken: fcmToken ?? this.fcmToken,
      onesignal: onesignal ?? this.onesignal,
      hireDate: hireDate ?? this.hireDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      authUid: authUid ?? this.authUid,
      authStatus: authStatus ?? this.authStatus,
      image: image ?? this.image,
      activeChatUpdatedAt: activeChatUpdatedAt ?? this.activeChatUpdatedAt,
    );
  }

  static DateTime? _parseDateTimeLike(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is int) {
      final ms = raw >= 1000000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (raw is String) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) return parsed;
      final asInt = int.tryParse(raw.trim());
      if (asInt != null) {
        final ms = asInt >= 1000000000000 ? asInt : asInt * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    return null;
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final rawDepts = json['departments'];
    final List<String> parsed;
    if (rawDepts is List) {
      parsed = StorageKeys.normalizeDepartments(
        rawDepts.map((e) => e?.toString()),
      );
    } else {
      // Pre-migration docs: single `department` string until backfill runs.
      parsed = StorageKeys.normalizeDepartments(
        [json['department']?.toString()],
      );
    }
    return EmployeeModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      departments: parsed,
      fcmToken: json['fcmToken'],
      onesignal: json['onesignal'],
      hireDate:
          json['hireDate'] != null ? DateTime.parse(json['hireDate']) : null,
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      authUid: json['authUid'],
      authStatus: json['authStatus'],
      image: json['image'],
      activeChatUpdatedAt: _parseDateTimeLike(json['activeChatUpdatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    final normalizedDepartments = StorageKeys.normalizeDepartments(departments);
    return {
      "id": id,
      "name": name,
      "email": email,
      "phone": phone,
      "role": role,
      "departments": normalizedDepartments,
      // Temporary compatibility for old app versions that still read/write
      // single-field department.
      "department": normalizedDepartments.isEmpty ? '' : normalizedDepartments.first,
      "fcmToken": fcmToken,
      'onesignal': onesignal,
      "hireDate": hireDate?.toIso8601String(),
      "status": status,
      "createdAt": createdAt.toIso8601String(),
      if (authUid != null) "authUid": authUid,
      if (authStatus != null) "authStatus": authStatus,
      "image": image,
      if (activeChatUpdatedAt != null)
        "activeChatUpdatedAt": activeChatUpdatedAt!.toIso8601String(),
    };
  }
}
