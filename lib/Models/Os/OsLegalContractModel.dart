import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Models/Os/OsContractClause.dart';
import 'package:point/Models/Os/OsContractPaymentTerm.dart';
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
    this.templateId,
    this.partyOneName = '',
    this.partyOneRep = '',
    this.partyOneTitle = '',
    this.partyOneAddress = '',
    this.partyOnePhone = '',
    this.partyOneEmail = '',
    this.partyOneRegistrationNo = '',
    this.partyTwoCompany = '',
    this.partyTwoNationalId = '',
    this.partyTwoAddress = '',
    this.partyTwoPhone = '',
    this.partyTwoEmail = '',
    this.partyTwoJobTitle = '',
    this.probationPeriodDays,
    this.noticePeriodDays,
    this.salaryMonthly,
    this.penaltyDailyRate,
    this.paymentTerms = const [],
    this.scopeOfWork = '',
    this.customTerms = '',
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
  final String? templateId;
  final String partyOneName;
  final String partyOneRep;
  final String partyOneTitle;
  final String partyOneAddress;
  final String partyOnePhone;
  final String partyOneEmail;
  final String partyOneRegistrationNo;
  final String partyTwoCompany;
  final String partyTwoNationalId;
  final String partyTwoAddress;
  final String partyTwoPhone;
  final String partyTwoEmail;
  final String partyTwoJobTitle;
  final int? probationPeriodDays;
  final int? noticePeriodDays;
  final double? salaryMonthly;
  final double? penaltyDailyRate;
  final List<OsContractPaymentTerm> paymentTerms;
  final String scopeOfWork;
  final String customTerms;
  final String? notes;
  final DateTime? signedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  /// Alias for [targetName] (Point OS naming).
  String get partyTwoName => targetName;

  /// Alias for [targetId] (Point OS naming).
  String get partyTwoId => targetId;

  List<OsContractClause> get enabledClauses =>
      clauses.where((c) => c.isEnabled).toList(growable: false);

  factory OsLegalContractModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return OsLegalContractModel.fromJson(doc.id, data);
  }

  factory OsLegalContractModel.fromJson(String id, Map<String, dynamic> json) {
    final scope = json['scopeOfWork'] as String? ?? '';
    final notes = json['notes'] as String? ?? '';
    return OsLegalContractModel(
      id: id,
      contractNumber: json['contractNumber'] as String? ?? '',
      title: json['title'] as String? ?? '',
      targetType: json['targetType'] as String? ??
          OsLegalContractTargetType.client,
      targetId: json['targetId'] as String? ??
          json['partyTwoId'] as String? ??
          '',
      targetName: json['targetName'] as String? ??
          json['partyTwoName'] as String? ??
          '',
      status: json['status'] as String? ?? OsLegalContractStatus.draft,
      startDate: _parseDate(json['startDate']) ?? DateTime.now(),
      endDate: _parseDate(json['endDate']),
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? OsLegalContractCurrency.iqd,
      governingLaw: json['governingLaw'] as String? ?? '',
      jurisdiction: json['jurisdiction'] as String? ?? '',
      clauses: OsContractClause.listFromJson(json['clauses']),
      templateId: json['templateId'] as String?,
      partyOneName: json['partyOneName'] as String? ?? '',
      partyOneRep: json['partyOneRep'] as String? ?? '',
      partyOneTitle: json['partyOneTitle'] as String? ?? '',
      partyOneAddress: json['partyOneAddress'] as String? ?? '',
      partyOnePhone: json['partyOnePhone'] as String? ?? '',
      partyOneEmail: json['partyOneEmail'] as String? ?? '',
      partyOneRegistrationNo: json['partyOneRegistrationNo'] as String? ?? '',
      partyTwoCompany: json['partyTwoCompany'] as String? ?? '',
      partyTwoNationalId: json['partyTwoNationalId'] as String? ?? '',
      partyTwoAddress: json['partyTwoAddress'] as String? ?? '',
      partyTwoPhone: json['partyTwoPhone'] as String? ?? '',
      partyTwoEmail: json['partyTwoEmail'] as String? ?? '',
      partyTwoJobTitle: json['partyTwoJobTitle'] as String? ?? '',
      probationPeriodDays: (json['probationPeriodDays'] as num?)?.toInt(),
      noticePeriodDays: (json['noticePeriodDays'] as num?)?.toInt(),
      salaryMonthly: (json['salaryMonthly'] as num?)?.toDouble(),
      penaltyDailyRate: (json['penaltyDailyRate'] as num?)?.toDouble(),
      paymentTerms: OsContractPaymentTerm.listFromJson(json['paymentTerms']),
      scopeOfWork: scope.isNotEmpty ? scope : notes,
      customTerms: json['customTerms'] as String? ?? '',
      notes: notes.isNotEmpty && scope.isNotEmpty ? notes : notes,
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
        'partyTwoId': targetId,
        'partyTwoName': targetName,
        'status': status,
        'startDate': Timestamp.fromDate(startDate),
        if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
        'totalValue': totalValue,
        'currency': currency,
        'governingLaw': governingLaw,
        'jurisdiction': jurisdiction,
        'clauses': clauses.map((c) => c.toJson()).toList(),
        if (templateId != null && templateId!.isNotEmpty)
          'templateId': templateId,
        if (partyOneName.isNotEmpty) 'partyOneName': partyOneName,
        if (partyOneRep.isNotEmpty) 'partyOneRep': partyOneRep,
        if (partyOneTitle.isNotEmpty) 'partyOneTitle': partyOneTitle,
        if (partyOneAddress.isNotEmpty) 'partyOneAddress': partyOneAddress,
        if (partyOnePhone.isNotEmpty) 'partyOnePhone': partyOnePhone,
        if (partyOneEmail.isNotEmpty) 'partyOneEmail': partyOneEmail,
        if (partyOneRegistrationNo.isNotEmpty)
          'partyOneRegistrationNo': partyOneRegistrationNo,
        if (partyTwoCompany.isNotEmpty) 'partyTwoCompany': partyTwoCompany,
        if (partyTwoNationalId.isNotEmpty)
          'partyTwoNationalId': partyTwoNationalId,
        if (partyTwoAddress.isNotEmpty) 'partyTwoAddress': partyTwoAddress,
        if (partyTwoPhone.isNotEmpty) 'partyTwoPhone': partyTwoPhone,
        if (partyTwoEmail.isNotEmpty) 'partyTwoEmail': partyTwoEmail,
        if (partyTwoJobTitle.isNotEmpty) 'partyTwoJobTitle': partyTwoJobTitle,
        if (probationPeriodDays != null)
          'probationPeriodDays': probationPeriodDays,
        if (noticePeriodDays != null) 'noticePeriodDays': noticePeriodDays,
        if (salaryMonthly != null) 'salaryMonthly': salaryMonthly,
        if (penaltyDailyRate != null) 'penaltyDailyRate': penaltyDailyRate,
        if (paymentTerms.isNotEmpty)
          'paymentTerms': paymentTerms.map((p) => p.toJson()).toList(),
        if (scopeOfWork.isNotEmpty) 'scopeOfWork': scopeOfWork,
        if (customTerms.isNotEmpty) 'customTerms': customTerms,
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
    String? templateId,
    String? partyOneName,
    String? partyOneRep,
    String? partyOneTitle,
    String? partyOneAddress,
    String? partyOnePhone,
    String? partyOneEmail,
    String? partyOneRegistrationNo,
    String? partyTwoCompany,
    String? partyTwoNationalId,
    String? partyTwoAddress,
    String? partyTwoPhone,
    String? partyTwoEmail,
    String? partyTwoJobTitle,
    int? probationPeriodDays,
    int? noticePeriodDays,
    double? salaryMonthly,
    double? penaltyDailyRate,
    List<OsContractPaymentTerm>? paymentTerms,
    String? scopeOfWork,
    String? customTerms,
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
      templateId: templateId ?? this.templateId,
      partyOneName: partyOneName ?? this.partyOneName,
      partyOneRep: partyOneRep ?? this.partyOneRep,
      partyOneTitle: partyOneTitle ?? this.partyOneTitle,
      partyOneAddress: partyOneAddress ?? this.partyOneAddress,
      partyOnePhone: partyOnePhone ?? this.partyOnePhone,
      partyOneEmail: partyOneEmail ?? this.partyOneEmail,
      partyOneRegistrationNo:
          partyOneRegistrationNo ?? this.partyOneRegistrationNo,
      partyTwoCompany: partyTwoCompany ?? this.partyTwoCompany,
      partyTwoNationalId: partyTwoNationalId ?? this.partyTwoNationalId,
      partyTwoAddress: partyTwoAddress ?? this.partyTwoAddress,
      partyTwoPhone: partyTwoPhone ?? this.partyTwoPhone,
      partyTwoEmail: partyTwoEmail ?? this.partyTwoEmail,
      partyTwoJobTitle: partyTwoJobTitle ?? this.partyTwoJobTitle,
      probationPeriodDays: probationPeriodDays ?? this.probationPeriodDays,
      noticePeriodDays: noticePeriodDays ?? this.noticePeriodDays,
      salaryMonthly: salaryMonthly ?? this.salaryMonthly,
      penaltyDailyRate: penaltyDailyRate ?? this.penaltyDailyRate,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      scopeOfWork: scopeOfWork ?? this.scopeOfWork,
      customTerms: customTerms ?? this.customTerms,
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
