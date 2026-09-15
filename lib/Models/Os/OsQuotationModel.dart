import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Models/Os/os_finance_enums.dart';

/// Price quote with optional line items (embedded like invoices).
class OsQuotationModel {
  final String? id;

  /// Human-readable ref like `Q-2024-001` (point_os style).
  final String? displayNumber;
  final String clientId;
  final String clientName;
  /// Snapshotted client contact (as issued).
  final String? clientPhone;
  final String? clientEmail;
  final String? clientAddress;
  final String date;
  final String expiryDate;
  final String status;
  /// Subtotal before VAT (sum of line items, or legacy lump-sum).
  final double amount;
  final double discount;
  final double vat;
  final double total;
  final List<OsLineItem> items;
  final String? notes;
  final DateTime createdAt;

  const OsQuotationModel({
    this.id,
    this.displayNumber,
    required this.clientId,
    required this.clientName,
    this.clientPhone,
    this.clientEmail,
    this.clientAddress,
    required this.date,
    required this.expiryDate,
    this.status = OsQuotationStatus.sent,
    this.amount = 0,
    this.discount = 0,
    this.vat = 0,
    required this.total,
    this.items = const [],
    this.notes,
    required this.createdAt,
  });

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

  factory OsQuotationModel.fromJson(Map<String, dynamic> json, String docId) {
    final items = OsLineItem.listFromJson(json['items']);
    final total = (json['total'] as num?)?.toDouble() ?? 0;
    final amount = (json['amount'] as num?)?.toDouble();
    final vat = (json['vat'] as num?)?.toDouble() ?? 0;
    final discount = (json['discount'] as num?)?.toDouble() ?? 0;
    // Legacy lump-sum quotes: amount missing → treat total as amount.
    final resolvedAmount = amount ?? (items.isEmpty ? total : total - vat);

    return OsQuotationModel(
      id: json['id'] as String? ?? docId,
      displayNumber: json['displayNumber'] as String?,
      clientId: json['clientId'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      clientPhone: json['clientPhone'] as String?,
      clientEmail: json['clientEmail'] as String?,
      clientAddress: json['clientAddress'] as String?,
      date: json['date'] as String? ?? '',
      expiryDate: json['expiryDate'] as String? ?? '',
      status: json['status'] as String? ?? OsQuotationStatus.sent,
      amount: resolvedAmount < 0 ? total : resolvedAmount,
      discount: discount,
      vat: vat,
      total: total,
      items: items,
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
        'date': date,
        'expiryDate': expiryDate,
        'status': status,
        'amount': amount,
        'discount': discount,
        'vat': vat,
        'total': total,
        'items': items.map((e) => e.toJson()).toList(),
        if (notes != null) 'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsQuotationModel copyWith({
    String? id,
    String? displayNumber,
    String? clientId,
    String? clientName,
    String? clientPhone,
    String? clientEmail,
    String? clientAddress,
    String? date,
    String? expiryDate,
    String? status,
    double? amount,
    double? discount,
    double? vat,
    double? total,
    List<OsLineItem>? items,
    String? notes,
    DateTime? createdAt,
  }) {
    return OsQuotationModel(
      id: id ?? this.id,
      displayNumber: displayNumber ?? this.displayNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      clientAddress: clientAddress ?? this.clientAddress,
      date: date ?? this.date,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      discount: discount ?? this.discount,
      vat: vat ?? this.vat,
      total: total ?? this.total,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Cycle SENT → APPROVED → REJECTED → SENT (point_os toggleStatus).
  String get nextStatus => OsQuotationStatus.next(status);
}
