class OsZaincashSettingsStatus {
  const OsZaincashSettingsStatus({
    required this.enabled,
    required this.environment,
    required this.clientId,
    required this.serviceType,
    required this.liveApiBase,
    required this.hasClientSecret,
    required this.clientSecretPreview,
    required this.hasApiKey,
    required this.apiKeyPreview,
    required this.configuredInFirestore,
  });

  final bool enabled;
  final String environment;
  final String clientId;
  final String serviceType;
  final String liveApiBase;
  final bool hasClientSecret;
  final String clientSecretPreview;
  final bool hasApiKey;
  final String apiKeyPreview;
  final bool configuredInFirestore;

  factory OsZaincashSettingsStatus.empty() => const OsZaincashSettingsStatus(
        enabled: false,
        environment: 'test',
        clientId: '',
        serviceType: 'Invoice',
        liveApiBase: '',
        hasClientSecret: false,
        clientSecretPreview: '',
        hasApiKey: false,
        apiKeyPreview: '',
        configuredInFirestore: false,
      );

  factory OsZaincashSettingsStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsZaincashSettingsStatus.empty();
    return OsZaincashSettingsStatus(
      enabled: json['enabled'] == true,
      environment: (json['environment'] as String?)?.trim().toLowerCase() ??
          'test',
      clientId: (json['clientId'] as String?)?.trim() ?? '',
      serviceType: (json['serviceType'] as String?)?.trim() ?? 'Invoice',
      liveApiBase: (json['liveApiBase'] as String?)?.trim() ?? '',
      hasClientSecret: json['hasClientSecret'] == true,
      clientSecretPreview:
          (json['clientSecretPreview'] as String?)?.trim() ?? '',
      hasApiKey: json['hasApiKey'] == true,
      apiKeyPreview: (json['apiKeyPreview'] as String?)?.trim() ?? '',
      configuredInFirestore: json['configuredInFirestore'] == true,
    );
  }
}
