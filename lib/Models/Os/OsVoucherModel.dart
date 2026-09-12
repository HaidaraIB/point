import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/os_finance_enums.dart';

class OsVoucherModel {
  final String? id;
  /// Human-readable ref like `V-101` (point_os style).
  final String? displayNumber;
  final String type;
  final double amount;
  final String date;
  final String payeeOrPayer;
  final String description;
  final String bankAccountId;
  final String status;
  final String? invoiceId;
  final DateTime createdAt;

  const OsVoucherModel({
    this.id,
    this.displayNumber,
    required this.type,
    required this.amount,
    required this.date,
    required this.payeeOrPayer,
    required this.description,
    required this.bankAccountId,
    this.status = OsVoucherStatus.completed,
    this.invoiceId,
    required this.createdAt,
  });

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  factory OsVoucherModel.fromJson(Map<String, dynamic> json, String docId) {
    return OsVoucherModel(
      id: json['id'] as String? ?? docId,
      displayNumber: json['displayNumber'] as String?,
      type: json['type'] as String? ?? OsVoucherType.receipt,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: json['date'] as String? ?? '',
      payeeOrPayer: json['payeeOrPayer'] as String? ?? '',
      description: json['description'] as String? ?? '',
      bankAccountId: json['bankAccountId'] as String? ?? '',
      status: json['status'] as String? ?? OsVoucherStatus.completed,
      invoiceId: json['invoiceId'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (displayNumber != null) 'displayNumber': displayNumber,
        'type': type,
        'amount': amount,
        'date': date,
        'payeeOrPayer': payeeOrPayer,
        'description': description,
        'bankAccountId': bankAccountId,
        'status': status,
        if (invoiceId != null) 'invoiceId': invoiceId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsVoucherModel copyWith({
    String? id,
    String? displayNumber,
    String? type,
    double? amount,
    String? date,
    String? payeeOrPayer,
    String? description,
    String? bankAccountId,
    String? status,
    String? invoiceId,
    DateTime? createdAt,
  }) {
    return OsVoucherModel(
      id: id ?? this.id,
      displayNumber: displayNumber ?? this.displayNumber,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      payeeOrPayer: payeeOrPayer ?? this.payeeOrPayer,
      description: description ?? this.description,
      bankAccountId: bankAccountId ?? this.bankAccountId,
      status: status ?? this.status,
      invoiceId: invoiceId ?? this.invoiceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
