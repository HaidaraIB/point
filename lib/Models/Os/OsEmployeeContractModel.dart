import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/os_payroll_enums.dart';

class OsEmployeeContractModel {
  final String? id;
  final String employeeId;
  final String employeeName;
  final String type;
  final String startDate;
  final String endDate;
  final String status;
  /// Human-readable ref like `CON-01`.
  final String? displayNumber;
  final String? notes;
  final DateTime createdAt;

  const OsEmployeeContractModel({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.status = OsEmployeeContractStatus.active,
    this.displayNumber,
    this.notes,
    required this.createdAt,
  });

  bool get isActive => status == OsEmployeeContractStatus.active;

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  factory OsEmployeeContractModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return OsEmployeeContractModel(
      id: json['id'] as String? ?? docId,
      employeeId: json['employeeId'] as String? ?? '',
      employeeName: json['employeeName'] as String? ?? '',
      type: json['type'] as String? ?? '',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      status: json['status'] as String? ?? OsEmployeeContractStatus.active,
      displayNumber: json['displayNumber'] as String?,
      notes: json['notes'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'type': type,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
        if (displayNumber != null) 'displayNumber': displayNumber,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsEmployeeContractModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? type,
    String? startDate,
    String? endDate,
    String? status,
    String? displayNumber,
    String? notes,
    DateTime? createdAt,
    bool clearNotes = false,
  }) {
    return OsEmployeeContractModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      displayNumber: displayNumber ?? this.displayNumber,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
