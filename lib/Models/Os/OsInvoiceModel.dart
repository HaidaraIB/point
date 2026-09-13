import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Models/Os/os_finance_enums.dart';

class OsInvoiceModel {
  final String? id;
  /// Human-readable ref like `INV-001` (point_os style).
  final String? displayNumber;
  final String clientId;
  final String clientName;
  final String date;
  final String dueDate;
  final String status;
  final double amount;
  final double vat;
  final double total;
  final List<OsLineItem> items;
  final String? bankAccountId;
  final DateTime createdAt;

  const OsInvoiceModel({
    this.id,
    this.displayNumber,
    required this.clientId,
    required this.clientName,
    required this.date,
    required this.dueDate,
    this.status = OsInvoiceStatus.sent,
    required this.amount,
    required this.vat,
    required this.total,
    this.items = const [],
    this.bankAccountId,
    required this.createdAt,
  });

  bool get isPaid => status == OsInvoiceStatus.paid;

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  factory OsInvoiceModel.fromJson(Map<String, dynamic> json, String docId) {
    return OsInvoiceModel(
      id: json['id'] as String? ?? docId,
      displayNumber: json['displayNumber'] as String?,
      clientId: json['clientId'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      date: json['date'] as String? ?? '',
      dueDate: json['dueDate'] as String? ?? '',
      status: json['status'] as String? ?? OsInvoiceStatus.sent,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      vat: (json['vat'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      items: OsLineItem.listFromJson(json['items']),
      bankAccountId: json['bankAccountId'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (displayNumber != null) 'displayNumber': displayNumber,
        'clientId': clientId,
        'clientName': clientName,
        'date': date,
        'dueDate': dueDate,
        'status': status,
        'amount': amount,
        'vat': vat,
        'total': total,
        'items': items.map((e) => e.toJson()).toList(),
        'bankAccountId': bankAccountId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsInvoiceModel copyWith({
    String? id,
    String? displayNumber,
    String? clientId,
    String? clientName,
    String? date,
    String? dueDate,
    String? status,
    double? amount,
    double? vat,
    double? total,
    List<OsLineItem>? items,
    String? bankAccountId,
    bool clearBankAccountId = false,
    DateTime? createdAt,
  }) {
    return OsInvoiceModel(
      id: id ?? this.id,
      displayNumber: displayNumber ?? this.displayNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      vat: vat ?? this.vat,
      total: total ?? this.total,
      items: items ?? this.items,
      bankAccountId:
          clearBankAccountId ? null : (bankAccountId ?? this.bankAccountId),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
