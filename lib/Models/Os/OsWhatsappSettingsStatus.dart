class OsWhatsappSettingsStatus {
  const OsWhatsappSettingsStatus({
    required this.phoneNumberId,
    required this.businessAccountId,
    required this.isEnabled,
    required this.hasAccessToken,
    required this.accessTokenPreview,
    required this.displayPhoneNumber,
    required this.verifiedName,
    required this.configuredInFirestore,
  });

  final String phoneNumberId;
  final String businessAccountId;
  final bool isEnabled;
  final bool hasAccessToken;
  final String accessTokenPreview;
  final String displayPhoneNumber;
  final String verifiedName;
  final bool configuredInFirestore;

  bool get isReadyForSend =>
      isEnabled &&
      hasAccessToken &&
      phoneNumberId.isNotEmpty &&
      businessAccountId.isNotEmpty;

  factory OsWhatsappSettingsStatus.empty() => const OsWhatsappSettingsStatus(
        phoneNumberId: '',
        businessAccountId: '',
        isEnabled: false,
        hasAccessToken: false,
        accessTokenPreview: '',
        displayPhoneNumber: '',
        verifiedName: '',
        configuredInFirestore: false,
      );

  factory OsWhatsappSettingsStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsWhatsappSettingsStatus.empty();
    return OsWhatsappSettingsStatus(
      phoneNumberId: (json['phoneNumberId'] as String?)?.trim() ?? '',
      businessAccountId:
          (json['businessAccountId'] as String?)?.trim() ?? '',
      isEnabled: json['isEnabled'] == true,
      hasAccessToken: json['hasAccessToken'] == true,
      accessTokenPreview: (json['accessTokenPreview'] as String?)?.trim() ?? '',
      displayPhoneNumber:
          (json['displayPhoneNumber'] as String?)?.trim() ?? '',
      verifiedName: (json['verifiedName'] as String?)?.trim() ?? '',
      configuredInFirestore: json['configuredInFirestore'] == true,
    );
  }
}
