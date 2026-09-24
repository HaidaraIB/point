class OsWalletToggleStatus {
  const OsWalletToggleStatus({
    required this.enabled,
    required this.bankAccountId,
    required this.configured,
  });

  final bool enabled;
  final String bankAccountId;
  final bool configured;

  factory OsWalletToggleStatus.empty() => const OsWalletToggleStatus(
        enabled: false,
        bankAccountId: '',
        configured: false,
      );

  factory OsWalletToggleStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsWalletToggleStatus.empty();
    return OsWalletToggleStatus(
      enabled: json['enabled'] == true,
      bankAccountId: (json['bankAccountId'] as String?)?.trim() ?? '',
      configured: json['configured'] == true,
    );
  }
}

typedef OsQicardToggleStatus = OsWalletToggleStatus;
