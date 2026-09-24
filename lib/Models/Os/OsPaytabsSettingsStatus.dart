class OsPaytabsSettingsStatus {
  const OsPaytabsSettingsStatus({
    required this.environment,
    required this.profileId,
    required this.region,
    required this.currency,
    required this.isEnabled,
    required this.defaultBankAccountId,
    required this.hasServerKey,
    required this.serverKeyPreview,
    required this.hasClientKey,
    required this.clientKeyPreview,
    required this.configuredInFirestore,
  });

  final String environment;
  final String profileId;
  final String region;
  final String currency;
  final bool isEnabled;
  final String defaultBankAccountId;
  final bool hasServerKey;
  final String serverKeyPreview;
  final bool hasClientKey;
  final String clientKeyPreview;
  final bool configuredInFirestore;

  factory OsPaytabsSettingsStatus.empty() => const OsPaytabsSettingsStatus(
        environment: 'test',
        profileId: '',
        region: 'IRQ',
        currency: 'IQD',
        isEnabled: false,
        defaultBankAccountId: '',
        hasServerKey: false,
        serverKeyPreview: '',
        hasClientKey: false,
        clientKeyPreview: '',
        configuredInFirestore: false,
      );

  factory OsPaytabsSettingsStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsPaytabsSettingsStatus.empty();
    return OsPaytabsSettingsStatus(
      environment: (json['environment'] as String?)?.trim().toLowerCase() ??
          'test',
      profileId: (json['profileId'] as String?)?.trim() ?? '',
      region: (json['region'] as String?)?.trim().toUpperCase() ?? 'IRQ',
      currency: (json['currency'] as String?)?.trim().toUpperCase() ?? 'IQD',
      isEnabled: json['isEnabled'] == true,
      defaultBankAccountId:
          (json['defaultBankAccountId'] as String?)?.trim() ?? '',
      hasServerKey: json['hasServerKey'] == true,
      serverKeyPreview: (json['serverKeyPreview'] as String?)?.trim() ?? '',
      hasClientKey: json['hasClientKey'] == true,
      clientKeyPreview: (json['clientKeyPreview'] as String?)?.trim() ?? '',
      configuredInFirestore: json['configuredInFirestore'] == true,
    );
  }
}
