import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/os_finance_enums.dart';

/// Lump-sum price quote (point_os Quotations screen).
class OsQuotationModel {
  final String? id;

  /// Human-readable ref like `Q-2024-001` (point_os style).
  final String? displayNumber;
  final String clientId;
  final String clientName;
  final String date;
  final String expiryDate;
  final String status;
  final double total;
  final DateTime createdAt;

  const OsQuotationModel({
    this.id,
    this.displayNumber,
    required this.clientId,
    required this.clientName,
    required this.date,
    required this.expiryDate,
    this.status = OsQuotationStatus.sent,
    required this.total,
    required this.createdAt,
  });

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  factory OsQuotationModel.fromJson(Map<String, dynamic> json, String docId) {
    return OsQuotationModel(
      id: json['id'] as String? ?? docId,
      displayNumber: json['displayNumber'] as String?,
      clientId: json['clientId'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      date: json['date'] as String? ?? '',
      expiryDate: json['expiryDate'] as String? ?? '',
      status: json['status'] as String? ?? OsQuotationStatus.sent,
      total: (json['total'] as num?)?.toDouble() ?? 0,
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
        'total': total,
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
    double? total,
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
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Cycle SENT → APPROVED → REJECTED → SENT (point_os toggleStatus).
  String get nextStatus => OsQuotationStatus.next(status);
}
