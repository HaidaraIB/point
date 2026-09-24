class OsActiveCardProviderStatus {
  const OsActiveCardProviderStatus({
    required this.provider,
    required this.defaultBankAccountId,
  });

  final String provider;
  final String defaultBankAccountId;

  factory OsActiveCardProviderStatus.empty() => const OsActiveCardProviderStatus(
        provider: 'none',
        defaultBankAccountId: '',
      );

  factory OsActiveCardProviderStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsActiveCardProviderStatus.empty();
    return OsActiveCardProviderStatus(
      provider: (json['provider'] as String?)?.trim().toLowerCase() ?? 'none',
      defaultBankAccountId:
          (json['defaultBankAccountId'] as String?)?.trim() ?? '',
    );
  }

  bool get isEnabled => provider == 'paytabs' || provider == 'alqaseh';
}
