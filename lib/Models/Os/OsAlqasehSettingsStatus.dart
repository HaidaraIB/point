class OsAlqasehSettingsStatus {
  const OsAlqasehSettingsStatus({
    required this.environment,
    required this.clientId,
    required this.currency,
    required this.tokenExpiryHours,
    required this.defaultBankAccountId,
    required this.hasClientSecret,
    required this.clientSecretPreview,
    required this.configuredInFirestore,
  });

  final String environment;
  final String clientId;
  final String currency;
  final int tokenExpiryHours;
  final String defaultBankAccountId;
  final bool hasClientSecret;
  final String clientSecretPreview;
  final bool configuredInFirestore;

  factory OsAlqasehSettingsStatus.empty() => const OsAlqasehSettingsStatus(
        environment: 'test',
        clientId: '',
        currency: 'IQD',
        tokenExpiryHours: 72,
        defaultBankAccountId: '',
        hasClientSecret: false,
        clientSecretPreview: '',
        configuredInFirestore: false,
      );

  factory OsAlqasehSettingsStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsAlqasehSettingsStatus.empty();
    return OsAlqasehSettingsStatus(
      environment: (json['environment'] as String?)?.trim().toLowerCase() ??
          'test',
      clientId: (json['clientId'] as String?)?.trim() ?? '',
      currency: (json['currency'] as String?)?.trim().toUpperCase() ?? 'IQD',
      tokenExpiryHours: (json['tokenExpiryHours'] as num?)?.toInt() ?? 72,
      defaultBankAccountId:
          (json['defaultBankAccountId'] as String?)?.trim() ?? '',
      hasClientSecret: json['hasClientSecret'] == true,
      clientSecretPreview:
          (json['clientSecretPreview'] as String?)?.trim() ?? '',
      configuredInFirestore: json['configuredInFirestore'] == true,
    );
  }
}
