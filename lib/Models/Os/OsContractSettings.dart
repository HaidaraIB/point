class OsContractSettings {
  const OsContractSettings({
    this.agencyLegalName = '',
    this.agencyCommercialReg = '',
    this.agencyTaxNumber = '',
    this.agencyAuthorizedSignatory = '',
    this.agencySignatoryTitle = '',
    this.agencyHeadquarters = '',
    this.agencyPhone = '',
    this.agencyEmail = '',
    this.defaultJurisdiction = '',
    this.defaultLaborLawRef = '',
    this.defaultCivilLawRef = '',
    this.defaultCopyrightLawRef = '',
    this.defaultProbationDays = 90,
    this.defaultWorkHoursWeekly = 48,
    this.defaultAnnualLeaveDays = 20,
    this.defaultLatePenaltyRate = 0.5,
    this.enableDigitalStamp = true,
    this.contractNumberPrefix = 'NOG-CON',
  });

  final String agencyLegalName;
  final String agencyCommercialReg;
  final String agencyTaxNumber;
  final String agencyAuthorizedSignatory;
  final String agencySignatoryTitle;
  final String agencyHeadquarters;
  final String agencyPhone;
  final String agencyEmail;
  final String defaultJurisdiction;
  final String defaultLaborLawRef;
  final String defaultCivilLawRef;
  final String defaultCopyrightLawRef;
  final int defaultProbationDays;
  final int defaultWorkHoursWeekly;
  final int defaultAnnualLeaveDays;
  final double defaultLatePenaltyRate;
  final bool enableDigitalStamp;
  final String contractNumberPrefix;

  factory OsContractSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsContractSettings.defaults();
    return OsContractSettings(
      agencyLegalName: json['agencyLegalName'] as String? ?? '',
      agencyCommercialReg: json['agencyCommercialReg'] as String? ?? '',
      agencyTaxNumber: json['agencyTaxNumber'] as String? ?? '',
      agencyAuthorizedSignatory:
          json['agencyAuthorizedSignatory'] as String? ?? '',
      agencySignatoryTitle: json['agencySignatoryTitle'] as String? ?? '',
      agencyHeadquarters: json['agencyHeadquarters'] as String? ?? '',
      agencyPhone: json['agencyPhone'] as String? ?? '',
      agencyEmail: json['agencyEmail'] as String? ?? '',
      defaultJurisdiction: json['defaultJurisdiction'] as String? ?? '',
      defaultLaborLawRef: json['defaultLaborLawRef'] as String? ?? '',
      defaultCivilLawRef: json['defaultCivilLawRef'] as String? ?? '',
      defaultCopyrightLawRef: json['defaultCopyrightLawRef'] as String? ?? '',
      defaultProbationDays: (json['defaultProbationDays'] as num?)?.toInt() ?? 90,
      defaultWorkHoursWeekly:
          (json['defaultWorkHoursWeekly'] as num?)?.toInt() ?? 48,
      defaultAnnualLeaveDays:
          (json['defaultAnnualLeaveDays'] as num?)?.toInt() ?? 20,
      defaultLatePenaltyRate:
          (json['defaultLatePenaltyRate'] as num?)?.toDouble() ?? 0.5,
      enableDigitalStamp: json['enableDigitalStamp'] as bool? ?? true,
      contractNumberPrefix:
          json['contractNumberPrefix'] as String? ?? 'NOG-CON',
    );
  }

  Map<String, dynamic> toJson() => {
        'agencyLegalName': agencyLegalName,
        'agencyCommercialReg': agencyCommercialReg,
        'agencyTaxNumber': agencyTaxNumber,
        'agencyAuthorizedSignatory': agencyAuthorizedSignatory,
        'agencySignatoryTitle': agencySignatoryTitle,
        'agencyHeadquarters': agencyHeadquarters,
        'agencyPhone': agencyPhone,
        'agencyEmail': agencyEmail,
        'defaultJurisdiction': defaultJurisdiction,
        'defaultLaborLawRef': defaultLaborLawRef,
        'defaultCivilLawRef': defaultCivilLawRef,
        'defaultCopyrightLawRef': defaultCopyrightLawRef,
        'defaultProbationDays': defaultProbationDays,
        'defaultWorkHoursWeekly': defaultWorkHoursWeekly,
        'defaultAnnualLeaveDays': defaultAnnualLeaveDays,
        'defaultLatePenaltyRate': defaultLatePenaltyRate,
        'enableDigitalStamp': enableDigitalStamp,
        'contractNumberPrefix': contractNumberPrefix,
      };

  OsContractSettings copyWith({
    String? agencyLegalName,
    String? agencyCommercialReg,
    String? agencyTaxNumber,
    String? agencyAuthorizedSignatory,
    String? agencySignatoryTitle,
    String? agencyHeadquarters,
    String? agencyPhone,
    String? agencyEmail,
    String? defaultJurisdiction,
    String? defaultLaborLawRef,
    String? defaultCivilLawRef,
    String? defaultCopyrightLawRef,
    int? defaultProbationDays,
    int? defaultWorkHoursWeekly,
    int? defaultAnnualLeaveDays,
    double? defaultLatePenaltyRate,
    bool? enableDigitalStamp,
    String? contractNumberPrefix,
  }) {
    return OsContractSettings(
      agencyLegalName: agencyLegalName ?? this.agencyLegalName,
      agencyCommercialReg: agencyCommercialReg ?? this.agencyCommercialReg,
      agencyTaxNumber: agencyTaxNumber ?? this.agencyTaxNumber,
      agencyAuthorizedSignatory:
          agencyAuthorizedSignatory ?? this.agencyAuthorizedSignatory,
      agencySignatoryTitle: agencySignatoryTitle ?? this.agencySignatoryTitle,
      agencyHeadquarters: agencyHeadquarters ?? this.agencyHeadquarters,
      agencyPhone: agencyPhone ?? this.agencyPhone,
      agencyEmail: agencyEmail ?? this.agencyEmail,
      defaultJurisdiction: defaultJurisdiction ?? this.defaultJurisdiction,
      defaultLaborLawRef: defaultLaborLawRef ?? this.defaultLaborLawRef,
      defaultCivilLawRef: defaultCivilLawRef ?? this.defaultCivilLawRef,
      defaultCopyrightLawRef:
          defaultCopyrightLawRef ?? this.defaultCopyrightLawRef,
      defaultProbationDays: defaultProbationDays ?? this.defaultProbationDays,
      defaultWorkHoursWeekly:
          defaultWorkHoursWeekly ?? this.defaultWorkHoursWeekly,
      defaultAnnualLeaveDays:
          defaultAnnualLeaveDays ?? this.defaultAnnualLeaveDays,
      defaultLatePenaltyRate:
          defaultLatePenaltyRate ?? this.defaultLatePenaltyRate,
      enableDigitalStamp: enableDigitalStamp ?? this.enableDigitalStamp,
      contractNumberPrefix: contractNumberPrefix ?? this.contractNumberPrefix,
    );
  }

  static OsContractSettings defaults() => const OsContractSettings(
        agencyLegalName:
            'وكالة نقطة للإنتاج الإبداعي والتسويق الرقمي ذ.م.م',
        agencyCommercialReg: 'س.ت: 48921 / بغداد',
        agencyTaxNumber: 'ر.ض: 90214432',
        agencyAuthorizedSignatory: 'علي جاسم الموسوي',
        agencySignatoryTitle: 'المدير العام والمفوض القانوني',
        agencyHeadquarters:
            'جمهورية العراق - بغداد - الكرادة - ساحة الأندلس - مبنى نقطة الإبداعي',
        agencyPhone: '+964 780 111 2223',
        agencyEmail: 'legal@nogta.iq',
        defaultJurisdiction:
            'المحاكم العراقية المختصة في بغداد (محكمة بداءة الكرخ / محكمة عمل بغداد)',
        defaultLaborLawRef:
            'قانون العمل العراقي رقم (37) لسنة 2015 المنشور بجريدة الوقائع العراقية',
        defaultCivilLawRef:
            'القانون المدني العراقي رقم (40) لسنة 1951 وتعديلاته النافذة',
        defaultCopyrightLawRef:
            'قانون حماية حق المؤلف العراقي رقم (3) لسنة 1971 وقوانين حماية الملكية الفكرية',
      );
}
