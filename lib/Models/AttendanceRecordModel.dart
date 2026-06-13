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
  final String approvalStatus;
  final String? rejectionReason;
  final String? markedBy;
  final DateTime? reviewedAt;
  final String? reviewedByEmployeeId;
  final String? reviewedByName;
  final bool locationBypassed;

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
    this.approvalStatus = statusPending,
    this.rejectionReason,
    this.markedBy,
    this.reviewedAt,
    this.reviewedByEmployeeId,
    this.reviewedByName,
    this.locationBypassed = false,
  });

  static const String actionPresent = 'present';
  static const String actionLeft = 'left';

  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusAbsent = 'absent';
  static const String statusAutoRejectedLate = 'auto_rejected_late';

  static const String reasonMissedCheckInWindow = 'missed_check_in_window';
  static const String reasonMissedCheckOutWindow = 'missed_check_out_window';
  static const String markedBySystem = 'system';

  bool get isPresent => action == actionPresent;
  bool get isLeft => action == actionLeft;
  bool get isPending => approvalStatus == statusPending;
  bool get isApproved => approvalStatus == statusApproved;
  bool get isAbsent => approvalStatus == statusAbsent;
  bool get isAutoRejectedLate => approvalStatus == statusAutoRejectedLate;
  bool get isActionFinalized =>
      isApproved || isAbsent || isAutoRejectedLate;

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
      approvalStatus: json['approvalStatus']?.toString() ?? statusPending,
      rejectionReason: json['rejectionReason']?.toString(),
      markedBy: json['markedBy']?.toString(),
      reviewedAt: _parseDateTime(json['reviewedAt']),
      reviewedByEmployeeId: json['reviewedByEmployeeId']?.toString(),
      reviewedByName: json['reviewedByName']?.toString(),
      locationBypassed: json['locationBypassed'] == true,
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
      'approvalStatus': approvalStatus,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
      if (rejectionReason != null && rejectionReason!.isNotEmpty)
        'rejectionReason': rejectionReason,
      if (markedBy != null && markedBy!.isNotEmpty) 'markedBy': markedBy,
      if (reviewedAt != null) 'reviewedAt': reviewedAt,
      if (reviewedByEmployeeId != null && reviewedByEmployeeId!.isNotEmpty)
        'reviewedByEmployeeId': reviewedByEmployeeId,
      if (reviewedByName != null && reviewedByName!.isNotEmpty)
        'reviewedByName': reviewedByName,
      if (locationBypassed) 'locationBypassed': true,
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
