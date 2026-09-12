import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/os_expense_constants.dart';

class OsDailyExpenseModel {
  final String? id;
  final String title;
  final double amount;
  final String category;
  final String date;
  final String time;
  final String paymentMethod;
  final String? bankAccountId;
  final String? branchId;
  final String paidBy;
  final String? vendor;
  final String? receiptNumber;
  final String? receiptImageUrl;
  final String? notes;
  final String status;
  final String? voucherId;
  final DateTime createdAt;

  const OsDailyExpenseModel({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.time,
    this.paymentMethod = OsExpensePaymentMethod.cash,
    this.bankAccountId,
    this.branchId,
    required this.paidBy,
    this.vendor,
    this.receiptNumber,
    this.receiptImageUrl,
    this.notes,
    this.status = OsExpenseStatus.approved,
    this.voucherId,
    required this.createdAt,
  });

  bool get hasReceipt =>
      receiptImageUrl != null && receiptImageUrl!.trim().isNotEmpty;

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory OsDailyExpenseModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return OsDailyExpenseModel(
      id: json['id'] as String? ?? docId,
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      paymentMethod:
          json['paymentMethod'] as String? ?? OsExpensePaymentMethod.cash,
      bankAccountId: json['bankAccountId'] as String?,
      branchId: json['branchId'] as String?,
      paidBy: json['paidBy'] as String? ?? '',
      vendor: json['vendor'] as String?,
      receiptNumber: json['receiptNumber'] as String?,
      receiptImageUrl: json['receiptImageUrl'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? OsExpenseStatus.approved,
      voucherId: json['voucherId'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'date': date,
        'time': time,
        'paymentMethod': paymentMethod,
        if (bankAccountId != null) 'bankAccountId': bankAccountId,
        if (branchId != null) 'branchId': branchId,
        'paidBy': paidBy,
        if (vendor != null) 'vendor': vendor,
        if (receiptNumber != null) 'receiptNumber': receiptNumber,
        if (receiptImageUrl != null) 'receiptImageUrl': receiptImageUrl,
        if (notes != null) 'notes': notes,
        'status': status,
        if (voucherId != null) 'voucherId': voucherId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsDailyExpenseModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    String? date,
    String? time,
    String? paymentMethod,
    String? bankAccountId,
    bool clearBankAccountId = false,
    String? branchId,
    bool clearBranchId = false,
    String? paidBy,
    String? vendor,
    bool clearVendor = false,
    String? receiptNumber,
    bool clearReceiptNumber = false,
    String? receiptImageUrl,
    bool clearReceiptImageUrl = false,
    String? notes,
    bool clearNotes = false,
    String? status,
    String? voucherId,
    bool clearVoucherId = false,
    DateTime? createdAt,
  }) {
    return OsDailyExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      time: time ?? this.time,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bankAccountId: clearBankAccountId
          ? null
          : (bankAccountId ?? this.bankAccountId),
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
      paidBy: paidBy ?? this.paidBy,
      vendor: clearVendor ? null : (vendor ?? this.vendor),
      receiptNumber:
          clearReceiptNumber ? null : (receiptNumber ?? this.receiptNumber),
      receiptImageUrl: clearReceiptImageUrl
          ? null
          : (receiptImageUrl ?? this.receiptImageUrl),
      notes: clearNotes ? null : (notes ?? this.notes),
      status: status ?? this.status,
      voucherId: clearVoucherId ? null : (voucherId ?? this.voucherId),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
