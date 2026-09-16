class OsAiSettingsStatus {
  const OsAiSettingsStatus({
    required this.hasGeminiKey,
    required this.keyPreview,
    required this.source,
    required this.configuredInFirestore,
    required this.configuredInEnv,
  });

  final bool hasGeminiKey;
  final String keyPreview;
  final String source;
  final bool configuredInFirestore;
  final bool configuredInEnv;

  factory OsAiSettingsStatus.empty() => const OsAiSettingsStatus(
        hasGeminiKey: false,
        keyPreview: '',
        source: 'none',
        configuredInFirestore: false,
        configuredInEnv: false,
      );

  factory OsAiSettingsStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsAiSettingsStatus.empty();
    return OsAiSettingsStatus(
      hasGeminiKey: json['hasGeminiKey'] == true,
      keyPreview: (json['keyPreview'] as String?)?.trim() ?? '',
      source: (json['source'] as String?)?.trim() ?? 'none',
      configuredInFirestore: json['configuredInFirestore'] == true,
      configuredInEnv: json['configuredInEnv'] == true,
    );
  }
}
