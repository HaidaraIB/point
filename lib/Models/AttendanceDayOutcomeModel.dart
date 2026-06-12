import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceDayOutcomeModel {
  const AttendanceDayOutcomeModel({
    this.id,
    required this.employeeId,
    required this.dateKey,
    required this.outcome,
    required this.reason,
    required this.markedBy,
    this.autoMarkedAt,
  });

  final String? id;
  final String employeeId;
  final String dateKey;
  final String outcome;
  final String reason;
  final String markedBy;
  final DateTime? autoMarkedAt;

  static const String outcomeAbsent = 'absent';
  static const String reasonNoCheckIn = 'no_check_in';
  static const String reasonNoCheckout = 'no_checkout';
  static const String markedBySystem = 'system';

  bool get isAbsent => outcome == outcomeAbsent;
  bool get isNoCheckIn => reason == reasonNoCheckIn;
  bool get isNoCheckout => reason == reasonNoCheckout;

  factory AttendanceDayOutcomeModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    return AttendanceDayOutcomeModel(
      id: id ?? json['id']?.toString(),
      employeeId: json['employeeId']?.toString() ?? '',
      dateKey: json['dateKey']?.toString() ?? '',
      outcome: json['outcome']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      markedBy: json['markedBy']?.toString() ?? '',
      autoMarkedAt: _parseDateTime(json['autoMarkedAt']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return DateTime.tryParse(value.toString());
  }
}
