import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/os_payroll_enums.dart';

class OsPayrollRunModel {
  final String? id;
  /// Period as `YYYY-MM`.
  final String period;
  final String status;
  final double totalGross;
  final double totalDeductions;
  final double totalNet;
  final int employeeCount;
  final DateTime createdAt;

  const OsPayrollRunModel({
    this.id,
    required this.period,
    this.status = OsPayrollRunStatus.draft,
    this.totalGross = 0,
    this.totalDeductions = 0,
    this.totalNet = 0,
    this.employeeCount = 0,
    required this.createdAt,
  });

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  factory OsPayrollRunModel.fromJson(Map<String, dynamic> json, String docId) {
    return OsPayrollRunModel(
      id: json['id'] as String? ?? docId,
      period: json['period'] as String? ?? '',
      status: json['status'] as String? ?? OsPayrollRunStatus.draft,
      totalGross: (json['totalGross'] as num?)?.toDouble() ?? 0,
      totalDeductions: (json['totalDeductions'] as num?)?.toDouble() ?? 0,
      totalNet: (json['totalNet'] as num?)?.toDouble() ?? 0,
      employeeCount: (json['employeeCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'period': period,
        'status': status,
        'totalGross': totalGross,
        'totalDeductions': totalDeductions,
        'totalNet': totalNet,
        'employeeCount': employeeCount,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsPayrollRunModel copyWith({
    String? id,
    String? period,
    String? status,
    double? totalGross,
    double? totalDeductions,
    double? totalNet,
    int? employeeCount,
    DateTime? createdAt,
  }) {
    return OsPayrollRunModel(
      id: id ?? this.id,
      period: period ?? this.period,
      status: status ?? this.status,
      totalGross: totalGross ?? this.totalGross,
      totalDeductions: totalDeductions ?? this.totalDeductions,
      totalNet: totalNet ?? this.totalNet,
      employeeCount: employeeCount ?? this.employeeCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
