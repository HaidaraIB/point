class OsGeneralSettings {
  const OsGeneralSettings({this.usdToIqdRate = defaultUsdToIqdRate});

  static const double defaultUsdToIqdRate = 1530.0;

  final double usdToIqdRate;

  factory OsGeneralSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsGeneralSettings.defaults();
    final rate = (json['usdToIqdRate'] as num?)?.toDouble();
    if (rate == null || rate <= 0) return OsGeneralSettings.defaults();
    return OsGeneralSettings(usdToIqdRate: rate);
  }

  Map<String, dynamic> toJson() => {'usdToIqdRate': usdToIqdRate};

  OsGeneralSettings copyWith({double? usdToIqdRate}) {
    return OsGeneralSettings(usdToIqdRate: usdToIqdRate ?? this.usdToIqdRate);
  }

  static OsGeneralSettings defaults() => const OsGeneralSettings();
}
