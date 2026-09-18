class OsGeneralSettings {
  const OsGeneralSettings({
    this.usdToIqdRate = defaultUsdToIqdRate,
    this.printAddressAr = defaultPrintAddressAr,
    this.printAddressEn = defaultPrintAddressEn,
    this.printPhone = defaultPrintPhone,
    this.printEmail = defaultPrintEmail,
    this.printWebsite = defaultPrintWebsite,
  });

  static const double defaultUsdToIqdRate = 1530.0;
  static const defaultPrintAddressAr = 'البصرة - العراق';
  static const defaultPrintAddressEn = 'Basra, Iraq';
  static const defaultPrintPhone = '+964 770 000 0000';
  static const defaultPrintEmail = 'info@point-iq.com';
  static const defaultPrintWebsite = 'www.point-iq.com';

  final double usdToIqdRate;
  final String printAddressAr;
  final String printAddressEn;
  final String printPhone;
  final String printEmail;
  final String printWebsite;

  factory OsGeneralSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsGeneralSettings.defaults();
    final rate = (json['usdToIqdRate'] as num?)?.toDouble();
    return OsGeneralSettings(
      usdToIqdRate: (rate == null || rate <= 0) ? defaultUsdToIqdRate : rate,
      printAddressAr: _str(json['printAddressAr'], defaultPrintAddressAr),
      printAddressEn: _str(json['printAddressEn'], defaultPrintAddressEn),
      printPhone: _str(json['printPhone'], defaultPrintPhone),
      printEmail: _str(json['printEmail'], defaultPrintEmail),
      printWebsite: _str(json['printWebsite'], defaultPrintWebsite),
    );
  }

  Map<String, dynamic> toJson() => {
        'usdToIqdRate': usdToIqdRate,
        'printAddressAr': printAddressAr,
        'printAddressEn': printAddressEn,
        'printPhone': printPhone,
        'printEmail': printEmail,
        'printWebsite': printWebsite,
      };

  Map<String, dynamic> printContactToJson() => {
        'printAddressAr': printAddressAr,
        'printAddressEn': printAddressEn,
        'printPhone': printPhone,
        'printEmail': printEmail,
        'printWebsite': printWebsite,
      };

  /// Absolute URL for QR codes / links, derived from [printWebsite].
  String get printWebsiteUrl {
    final raw = printWebsite.trim();
    if (raw.isEmpty) return 'https://$defaultPrintWebsite';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://$raw';
  }

  OsGeneralSettings copyWith({
    double? usdToIqdRate,
    String? printAddressAr,
    String? printAddressEn,
    String? printPhone,
    String? printEmail,
    String? printWebsite,
  }) {
    return OsGeneralSettings(
      usdToIqdRate: usdToIqdRate ?? this.usdToIqdRate,
      printAddressAr: printAddressAr ?? this.printAddressAr,
      printAddressEn: printAddressEn ?? this.printAddressEn,
      printPhone: printPhone ?? this.printPhone,
      printEmail: printEmail ?? this.printEmail,
      printWebsite: printWebsite ?? this.printWebsite,
    );
  }

  static OsGeneralSettings defaults() => const OsGeneralSettings();

  static String _str(dynamic value, String fallback) {
    if (value is! String) return fallback;
    return value;
  }
}
