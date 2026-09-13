import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/os_payroll_enums.dart';

class OsPayslipModel {
  final String? id;
  final String? runId;
  /// Period as `YYYY-MM`.
  final String period;
  final String employeeId;
  final String employeeName;
  final String? jobTitle;
  final String? branchId;
  final DateTime? hireDate;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final double socialSecurity;
  final double advanceDeduction;
  final double netPay;
  final String status;
  /// Human-readable ref like `SLIP-2026-09-01`.
  final String? displayNumber;
  final String? expenseId;
  final String? voucherId;
  /// Advance repaid when this slip was disbursed (for reverse on delete).
  final String? advanceId;
  final DateTime? paidAt;
  final DateTime createdAt;

  const OsPayslipModel({
    this.id,
    this.runId,
    required this.period,
    required this.employeeId,
    required this.employeeName,
    this.jobTitle,
    this.branchId,
    this.hireDate,
    required this.basicSalary,
    this.allowances = 0,
    this.deductions = 0,
    this.socialSecurity = 0,
    this.advanceDeduction = 0,
    required this.netPay,
    this.status = OsPayslipStatus.pending,
    this.displayNumber,
    this.expenseId,
    this.voucherId,
    this.advanceId,
    this.paidAt,
    required this.createdAt,
  });

  bool get isPaid => status == OsPayslipStatus.paid;

  double get totalEarnings => basicSalary + allowances;
  double get totalDeductions =>
      deductions + socialSecurity + advanceDeduction;

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory OsPayslipModel.fromJson(Map<String, dynamic> json, String docId) {
    return OsPayslipModel(
      id: json['id'] as String? ?? docId,
      runId: json['runId'] as String?,
      period: json['period'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      employeeName: json['employeeName'] as String? ?? '',
      jobTitle: json['jobTitle'] as String?,
      branchId: json['branchId'] as String?,
      hireDate: _parseDateTime(json['hireDate']),
      basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0,
      socialSecurity: (json['socialSecurity'] as num?)?.toDouble() ?? 0,
      advanceDeduction: (json['advanceDeduction'] as num?)?.toDouble() ?? 0,
      netPay: (json['netPay'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? OsPayslipStatus.pending,
      displayNumber: json['displayNumber'] as String?,
      expenseId: json['expenseId'] as String?,
      voucherId: json['voucherId'] as String?,
      advanceId: json['advanceId'] as String?,
      paidAt: _parseDateTime(json['paidAt']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'runId': runId,
        'period': period,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'jobTitle': jobTitle,
        'branchId': branchId,
        'hireDate': hireDate == null ? null : Timestamp.fromDate(hireDate!),
        'basicSalary': basicSalary,
        'allowances': allowances,
        'deductions': deductions,
        'socialSecurity': socialSecurity,
        'advanceDeduction': advanceDeduction,
        'netPay': netPay,
        'status': status,
        if (displayNumber != null) 'displayNumber': displayNumber,
        'expenseId': expenseId,
        'voucherId': voucherId,
        if (advanceId != null) 'advanceId': advanceId,
        'paidAt': paidAt == null ? null : Timestamp.fromDate(paidAt!),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsPayslipModel copyWith({
    String? id,
    String? runId,
    String? period,
    String? employeeId,
    String? employeeName,
    String? jobTitle,
    String? branchId,
    DateTime? hireDate,
    double? basicSalary,
    double? allowances,
    double? deductions,
    double? socialSecurity,
    double? advanceDeduction,
    double? netPay,
    String? status,
    String? displayNumber,
    String? expenseId,
    String? voucherId,
    String? advanceId,
    DateTime? paidAt,
    DateTime? createdAt,
    bool clearJobTitle = false,
    bool clearBranchId = false,
    bool clearHireDate = false,
    bool clearExpenseId = false,
    bool clearVoucherId = false,
    bool clearAdvanceId = false,
    bool clearPaidAt = false,
  }) {
    return OsPayslipModel(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      period: period ?? this.period,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      jobTitle: clearJobTitle ? null : (jobTitle ?? this.jobTitle),
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
      hireDate: clearHireDate ? null : (hireDate ?? this.hireDate),
      basicSalary: basicSalary ?? this.basicSalary,
      allowances: allowances ?? this.allowances,
      deductions: deductions ?? this.deductions,
      socialSecurity: socialSecurity ?? this.socialSecurity,
      advanceDeduction: advanceDeduction ?? this.advanceDeduction,
      netPay: netPay ?? this.netPay,
      status: status ?? this.status,
      displayNumber: displayNumber ?? this.displayNumber,
      expenseId: clearExpenseId ? null : (expenseId ?? this.expenseId),
      voucherId: clearVoucherId ? null : (voucherId ?? this.voucherId),
      advanceId: clearAdvanceId ? null : (advanceId ?? this.advanceId),
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
