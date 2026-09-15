import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Models/Os/os_finance_enums.dart';

class OsInvoiceModel {
  final String? id;
  /// Human-readable ref like `INV-001` (point_os style).
  final String? displayNumber;
  final String clientId;
  final String clientName;
  /// Snapshotted client contact (as issued).
  final String? clientPhone;
  final String? clientEmail;
  final String? clientAddress;
  final String? clientTaxNumber;
  final String date;
  final String dueDate;
  final String status;
  final double amount;
  final double discount;
  final double vat;
  final double total;
  final List<OsLineItem> items;
  final String? bankAccountId;
  /// See [OsPaymentMethod].
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;

  const OsInvoiceModel({
    this.id,
    this.displayNumber,
    required this.clientId,
    required this.clientName,
    this.clientPhone,
    this.clientEmail,
    this.clientAddress,
    this.clientTaxNumber,
    required this.date,
    required this.dueDate,
    this.status = OsInvoiceStatus.sent,
    required this.amount,
    this.discount = 0,
    required this.vat,
    required this.total,
    this.items = const [],
    this.bankAccountId,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
  });

  bool get isPaid => status == OsInvoiceStatus.paid;

  /// `amount - discount + vat` (clamped discount).
  static double computeTotal({
    required double amount,
    required double discount,
    required double vat,
  }) {
    final d = discount < 0 ? 0.0 : discount;
    return amount - d + vat;
  }

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
      clientPhone: json['clientPhone'] as String?,
      clientEmail: json['clientEmail'] as String?,
      clientAddress: json['clientAddress'] as String?,
      clientTaxNumber: json['clientTaxNumber'] as String?,
      date: json['date'] as String? ?? '',
      dueDate: json['dueDate'] as String? ?? '',
      status: json['status'] as String? ?? OsInvoiceStatus.sent,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      vat: (json['vat'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      items: OsLineItem.listFromJson(json['items']),
      bankAccountId: json['bankAccountId'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      notes: json['notes'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (displayNumber != null) 'displayNumber': displayNumber,
        'clientId': clientId,
        'clientName': clientName,
        if (clientPhone != null) 'clientPhone': clientPhone,
        if (clientEmail != null) 'clientEmail': clientEmail,
        if (clientAddress != null) 'clientAddress': clientAddress,
        if (clientTaxNumber != null) 'clientTaxNumber': clientTaxNumber,
        'date': date,
        'dueDate': dueDate,
        'status': status,
        'amount': amount,
        'discount': discount,
        'vat': vat,
        'total': total,
        'items': items.map((e) => e.toJson()).toList(),
        'bankAccountId': bankAccountId,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (notes != null) 'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsInvoiceModel copyWith({
    String? id,
    String? displayNumber,
    String? clientId,
    String? clientName,
    String? clientPhone,
    String? clientEmail,
    String? clientAddress,
    String? clientTaxNumber,
    String? date,
    String? dueDate,
    String? status,
    double? amount,
    double? discount,
    double? vat,
    double? total,
    List<OsLineItem>? items,
    String? bankAccountId,
    bool clearBankAccountId = false,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
  }) {
    return OsInvoiceModel(
      id: id ?? this.id,
      displayNumber: displayNumber ?? this.displayNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      clientAddress: clientAddress ?? this.clientAddress,
      clientTaxNumber: clientTaxNumber ?? this.clientTaxNumber,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      discount: discount ?? this.discount,
      vat: vat ?? this.vat,
      total: total ?? this.total,
      items: items ?? this.items,
      bankAccountId:
          clearBankAccountId ? null : (bankAccountId ?? this.bankAccountId),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
