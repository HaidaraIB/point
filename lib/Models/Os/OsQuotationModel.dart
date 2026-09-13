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
  final String date;
  final String expiryDate;
  final String status;
  /// Subtotal before VAT (sum of line items, or legacy lump-sum).
  final double amount;
  final double vat;
  final double total;
  final List<OsLineItem> items;
  final DateTime createdAt;

  const OsQuotationModel({
    this.id,
    this.displayNumber,
    required this.clientId,
    required this.clientName,
    required this.date,
    required this.expiryDate,
    this.status = OsQuotationStatus.sent,
    this.amount = 0,
    this.vat = 0,
    required this.total,
    this.items = const [],
    required this.createdAt,
  });

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
    // Legacy lump-sum quotes: amount missing → treat total as amount.
    final resolvedAmount = amount ?? (items.isEmpty ? total : total - vat);

    return OsQuotationModel(
      id: json['id'] as String? ?? docId,
      displayNumber: json['displayNumber'] as String?,
      clientId: json['clientId'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      date: json['date'] as String? ?? '',
      expiryDate: json['expiryDate'] as String? ?? '',
      status: json['status'] as String? ?? OsQuotationStatus.sent,
      amount: resolvedAmount < 0 ? total : resolvedAmount,
      vat: vat,
      total: total,
      items: items,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (displayNumber != null) 'displayNumber': displayNumber,
        'clientId': clientId,
        'clientName': clientName,
        'date': date,
        'expiryDate': expiryDate,
        'status': status,
        'amount': amount,
        'vat': vat,
        'total': total,
        'items': items.map((e) => e.toJson()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  OsQuotationModel copyWith({
    String? id,
    String? displayNumber,
    String? clientId,
    String? clientName,
    String? date,
    String? expiryDate,
    String? status,
    double? amount,
    double? vat,
    double? total,
    List<OsLineItem>? items,
    DateTime? createdAt,
  }) {
    return OsQuotationModel(
      id: id ?? this.id,
      displayNumber: displayNumber ?? this.displayNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      date: date ?? this.date,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      vat: vat ?? this.vat,
      total: total ?? this.total,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Cycle SENT → APPROVED → REJECTED → SENT (point_os toggleStatus).
  String get nextStatus => OsQuotationStatus.next(status);
}
