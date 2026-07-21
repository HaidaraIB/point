import 'package:point/Models/EmployeeAttendanceLocation.dart';
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
  /// Branch/office geofence for attendance (employees only).
  final EmployeeAttendanceLocation? attendanceLocation;
  /// Work hours as "HH:mm" for check-in/out reminders.
  final String? workHoursFrom;
  final String? workHoursTo;
  /// When true, employee skips GPS/geofence during attendance (photo + windows only).
  final bool attendanceRemote;
  /// When true (with [attendanceRemote]), check-in/out buttons are available all day.
  final bool attendanceFlexibleHours;
  /// Admin-granted access to the Library (browse, direct upload, pick from library).
  final bool libraryAccess;

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
    this.attendanceLocation,
    this.workHoursFrom,
    this.workHoursTo,
    this.attendanceRemote = false,
    this.attendanceFlexibleHours = false,
    this.libraryAccess = false,
  });

  /// First department slug, if any (e.g. notifications / legacy single-field UX).
  String? get primaryDepartment =>
      departments.isEmpty ? null : departments.first;

  bool get isRemoteAttendance => attendanceRemote;

  bool get hasFlexibleAttendanceHours =>
      attendanceRemote && attendanceFlexibleHours;

  bool get hasAttendanceLocationConfigured =>
      attendanceLocation?.isConfigured ?? false;

  bool get hasWorkHours =>
      (workHoursFrom?.trim().isNotEmpty ?? false) &&
      (workHoursTo?.trim().isNotEmpty ?? false);

  bool hasDepartment(String semanticDepartment) => departments.any(
        (d) => StorageKeys.matchesDepartment(d, semanticDepartment),
      );

  /// Admin and supervisor are global roles (no department membership).
  bool get isManagerRole {
    final r = role.trim().toLowerCase();
    return r == 'admin' || r == 'supervisor';
  }

  /// Whether this person can appear as a task assignee for [semanticDepartment].
  /// Managers (admin/supervisor) are always assignable; staff need the department.
  bool canBeAssignedAsExecutorFor(String semanticDepartment) =>
      isManagerRole || hasDepartment(semanticDepartment);

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
    EmployeeAttendanceLocation? attendanceLocation,
    String? workHoursFrom,
    String? workHoursTo,
    bool? attendanceRemote,
    bool? attendanceFlexibleHours,
    bool? libraryAccess,
    bool clearAttendanceLocation = false,
    bool clearWorkHours = false,
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
      attendanceLocation: clearAttendanceLocation
          ? null
          : (attendanceLocation ?? this.attendanceLocation),
      workHoursFrom: clearWorkHours ? null : (workHoursFrom ?? this.workHoursFrom),
      workHoursTo: clearWorkHours ? null : (workHoursTo ?? this.workHoursTo),
      attendanceRemote: attendanceRemote ?? this.attendanceRemote,
      attendanceFlexibleHours:
          attendanceFlexibleHours ?? this.attendanceFlexibleHours,
      libraryAccess: libraryAccess ?? this.libraryAccess,
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
      parsed = StorageKeys.normalizeDepartments(
        [json['department']?.toString()],
      );
    }

    EmployeeAttendanceLocation? location;
    final rawLoc = json['attendanceLocation'];
    if (rawLoc is Map) {
      try {
        location = EmployeeAttendanceLocation.fromJson(
          Map<String, dynamic>.from(rawLoc),
        );
        if (!location.isConfigured) location = null;
      } catch (_) {
        location = null;
      }
    }

    return EmployeeModel(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? '',
      departments: parsed,
      fcmToken: json['fcmToken']?.toString(),
      onesignal: json['onesignal']?.toString(),
      hireDate: _parseDateTimeLike(json['hireDate']),
      status: json['status']?.toString() ?? '',
      createdAt: _parseDateTimeLike(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      authUid: json['authUid']?.toString(),
      authStatus: json['authStatus']?.toString(),
      image: json['image']?.toString(),
      activeChatUpdatedAt: _parseDateTimeLike(json['activeChatUpdatedAt']),
      attendanceLocation: location,
      workHoursFrom: json['workHoursFrom']?.toString(),
      workHoursTo: json['workHoursTo']?.toString(),
      attendanceRemote: json['attendanceRemote'] == true,
      attendanceFlexibleHours: json['attendanceFlexibleHours'] == true,
      libraryAccess: json['libraryAccess'] == true,
    );
  }

  /// Parse Firestore document data (handles Timestamp fields and nested maps).
  factory EmployeeModel.fromFirestoreMap(
    Object? data, {
    String? id,
  }) {
    if (data is! Map) {
      return EmployeeModel.fromJson(const {}).copyWith(id: id);
    }
    final map = Map<String, dynamic>.from(data);
    return EmployeeModel.fromJson(map).copyWith(id: id ?? map['id']?.toString());
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
      if (attendanceLocation != null && attendanceLocation!.isConfigured)
        "attendanceLocation": attendanceLocation!.toJson(),
      if (workHoursFrom != null && workHoursFrom!.trim().isNotEmpty)
        "workHoursFrom": workHoursFrom!.trim(),
      if (workHoursTo != null && workHoursTo!.trim().isNotEmpty)
        "workHoursTo": workHoursTo!.trim(),
      "attendanceRemote": attendanceRemote,
      "attendanceFlexibleHours": attendanceFlexibleHours,
      "libraryAccess": libraryAccess,
    };
  }
}
