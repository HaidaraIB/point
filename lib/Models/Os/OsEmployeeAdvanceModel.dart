import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/os_payroll_enums.dart';

class OsEmployeeAdvanceModel {
  final String? id;
  final String employeeId;
  final String employeeName;
  final double totalAmount;
  final double monthlyInstallment;
  final double paidAmount;
  final double remainingAmount;
  final String status;
  final DateTime createdAt;

  const OsEmployeeAdvanceModel({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.totalAmount,
    required this.monthlyInstallment,
    this.paidAmount = 0,
    required this.remainingAmount,
    this.status = OsEmployeeAdvanceStatus.active,
    required this.createdAt,
  });

  bool get isActive => status == OsEmployeeAdvanceStatus.active;

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  factory OsEmployeeAdvanceModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    final total = (json['totalAmount'] as num?)?.toDouble() ?? 0;
    final paid = (json['paidAmount'] as num?)?.toDouble() ?? 0;
    final remaining = (json['remainingAmount'] as num?)?.toDouble() ??
        (total - paid).clamp(0, double.infinity);
    return OsEmployeeAdvanceModel(
      id: json['id'] as String? ?? docId,
      employeeId: json['employeeId'] as String? ?? '',
      employeeName: json['employeeName'] as String? ?? '',
      totalAmount: total,
      monthlyInstallment:
          (json['monthlyInstallment'] as num?)?.toDouble() ?? 0,
      paidAmount: paid,
      remainingAmount: remaining,
      status: json['status'] as String? ?? OsEmployeeAdvanceStatus.active,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'totalAmount': totalAmount,
        'monthlyInstallment': monthlyInstallment,
        'paidAmount': paidAmount,
        'remainingAmount': remainingAmount,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsEmployeeAdvanceModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    double? totalAmount,
    double? monthlyInstallment,
    double? paidAmount,
    double? remainingAmount,
    String? status,
    DateTime? createdAt,
  }) {
    return OsEmployeeAdvanceModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      totalAmount: totalAmount ?? this.totalAmount,
      monthlyInstallment: monthlyInstallment ?? this.monthlyInstallment,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
