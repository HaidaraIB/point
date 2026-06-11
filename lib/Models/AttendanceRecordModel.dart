import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecordModel {
  final String? id;
  final String employeeId;
  final String employeeName;
  final String action;
  final DateTime? recordedAt;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final double officeLatitude;
  final double officeLongitude;
  final double officeRadiusMeters;
  final String? photoUrl;

  const AttendanceRecordModel({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.action,
    this.recordedAt,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.officeRadiusMeters,
    this.photoUrl,
  });

  static const String actionPresent = 'present';
  static const String actionLeft = 'left';

  bool get isPresent => action == actionPresent;
  bool get isLeft => action == actionLeft;

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return AttendanceRecordModel(
      id: id ?? json['id']?.toString(),
      employeeId: json['employeeId']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      recordedAt: _parseDateTime(json['recordedAt']),
      latitude: _asDouble(json['latitude']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
      distanceMeters: _asDouble(json['distanceMeters']) ?? 0,
      officeLatitude: _asDouble(json['officeLatitude']) ?? 0,
      officeLongitude: _asDouble(json['officeLongitude']) ?? 0,
      officeRadiusMeters: _asDouble(json['officeRadiusMeters']) ?? 0,
      photoUrl: json['photoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'action': action,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'officeLatitude': officeLatitude,
      'officeLongitude': officeLongitude,
      'officeRadiusMeters': officeRadiusMeters,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
    };
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return DateTime.tryParse(value.toString());
  }

  static double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}
