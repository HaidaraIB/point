import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsContractClause.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';

class OsLegalContractModel {
  const OsLegalContractModel({
    required this.id,
    required this.contractNumber,
    required this.title,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.totalValue,
    required this.currency,
    required this.governingLaw,
    required this.jurisdiction,
    required this.clauses,
    this.notes,
    this.signedAt,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String contractNumber;
  final String title;
  final String targetType;
  final String targetId;
  final String targetName;
  final String status;
  final DateTime startDate;
  final DateTime? endDate;
  final double totalValue;
  final String currency;
  final String governingLaw;
  final String jurisdiction;
  final List<OsContractClause> clauses;
  final String? notes;
  final DateTime? signedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory OsLegalContractModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return OsLegalContractModel.fromJson(doc.id, data);
  }

  factory OsLegalContractModel.fromJson(String id, Map<String, dynamic> json) {
    return OsLegalContractModel(
      id: id,
      contractNumber: json['contractNumber'] as String? ?? '',
      title: json['title'] as String? ?? '',
      targetType: json['targetType'] as String? ??
          OsLegalContractTargetType.client,
      targetId: json['targetId'] as String? ?? '',
      targetName: json['targetName'] as String? ?? '',
      status: json['status'] as String? ?? OsLegalContractStatus.draft,
      startDate: _parseDate(json['startDate']) ?? DateTime.now(),
      endDate: _parseDate(json['endDate']),
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? OsLegalContractCurrency.iqd,
      governingLaw: json['governingLaw'] as String? ?? '',
      jurisdiction: json['jurisdiction'] as String? ?? '',
      clauses: OsContractClause.listFromJson(json['clauses']),
      notes: json['notes'] as String?,
      signedAt: _parseDate(json['signedAt']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      createdBy: json['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'contractNumber': contractNumber,
        'title': title,
        'targetType': targetType,
        'targetId': targetId,
        'targetName': targetName,
        'status': status,
        'startDate': Timestamp.fromDate(startDate),
        if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
        'totalValue': totalValue,
        'currency': currency,
        'governingLaw': governingLaw,
        'jurisdiction': jurisdiction,
        'clauses': clauses.map((c) => c.toJson()).toList(),
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (signedAt != null) 'signedAt': Timestamp.fromDate(signedAt!),
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
        if (createdBy != null) 'createdBy': createdBy,
      };

  OsLegalContractModel copyWith({
    String? id,
    String? contractNumber,
    String? title,
    String? targetType,
    String? targetId,
    String? targetName,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    double? totalValue,
    String? currency,
    String? governingLaw,
    String? jurisdiction,
    List<OsContractClause>? clauses,
    String? notes,
    DateTime? signedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return OsLegalContractModel(
      id: id ?? this.id,
      contractNumber: contractNumber ?? this.contractNumber,
      title: title ?? this.title,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      targetName: targetName ?? this.targetName,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalValue: totalValue ?? this.totalValue,
      currency: currency ?? this.currency,
      governingLaw: governingLaw ?? this.governingLaw,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      clauses: clauses ?? this.clauses,
      notes: notes ?? this.notes,
      signedAt: signedAt ?? this.signedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }
}
