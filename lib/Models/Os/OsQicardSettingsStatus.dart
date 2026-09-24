class OsQicardSettingsStatus {
  const OsQicardSettingsStatus({
    required this.enabled,
    required this.environment,
    required this.username,
    required this.terminalId,
    required this.currency,
    required this.bankAccountId,
    required this.liveApiBase,
    required this.hasPassword,
    required this.passwordPreview,
    required this.hasWebhookPublicKey,
    required this.webhookPublicKeyPreview,
    required this.configuredInFirestore,
  });

  final bool enabled;
  final String environment;
  final String username;
  final String terminalId;
  final String currency;
  final String bankAccountId;
  final String liveApiBase;
  final bool hasPassword;
  final String passwordPreview;
  final bool hasWebhookPublicKey;
  final String webhookPublicKeyPreview;
  final bool configuredInFirestore;

  factory OsQicardSettingsStatus.empty() => const OsQicardSettingsStatus(
        enabled: false,
        environment: 'test',
        username: '',
        terminalId: '',
        currency: 'IQD',
        bankAccountId: '',
        liveApiBase: '',
        hasPassword: false,
        passwordPreview: '',
        hasWebhookPublicKey: false,
        webhookPublicKeyPreview: '',
        configuredInFirestore: false,
      );

  factory OsQicardSettingsStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsQicardSettingsStatus.empty();
    return OsQicardSettingsStatus(
      enabled: json['enabled'] == true,
      environment: (json['environment'] as String?)?.trim().toLowerCase() ??
          'test',
      username: (json['username'] as String?)?.trim() ?? '',
      terminalId: (json['terminalId'] as String?)?.trim() ?? '',
      currency: (json['currency'] as String?)?.trim().toUpperCase() ?? 'IQD',
      bankAccountId: (json['bankAccountId'] as String?)?.trim() ?? '',
      liveApiBase: (json['liveApiBase'] as String?)?.trim() ?? '',
      hasPassword: json['hasPassword'] == true,
      passwordPreview: (json['passwordPreview'] as String?)?.trim() ?? '',
      hasWebhookPublicKey: json['hasWebhookPublicKey'] == true,
      webhookPublicKeyPreview:
          (json['webhookPublicKeyPreview'] as String?)?.trim() ?? '',
      configuredInFirestore: json['configuredInFirestore'] == true,
    );
  }
}

class OsQicardToggleStatus {
  const OsQicardToggleStatus({
    required this.enabled,
    required this.bankAccountId,
    required this.configured,
  });

  final bool enabled;
  final String bankAccountId;
  final bool configured;

  factory OsQicardToggleStatus.empty() => const OsQicardToggleStatus(
        enabled: false,
        bankAccountId: '',
        configured: false,
      );

  factory OsQicardToggleStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsQicardToggleStatus.empty();
    return OsQicardToggleStatus(
      enabled: json['enabled'] == true,
      bankAccountId: (json['bankAccountId'] as String?)?.trim() ?? '',
      configured: json['configured'] == true,
    );
  }
}
