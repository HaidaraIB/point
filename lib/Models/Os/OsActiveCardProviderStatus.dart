import 'package:point/Models/Os/OsWalletToggleStatus.dart';

class OsActiveCardProviderStatus {
  const OsActiveCardProviderStatus({
    required this.provider,
    required this.defaultBankAccountId,
    required this.qicard,
    required this.zaincash,
    required this.enabledMethods,
  });

  final String provider;
  final String defaultBankAccountId;
  final OsWalletToggleStatus qicard;
  final OsWalletToggleStatus zaincash;
  final List<String> enabledMethods;

  factory OsActiveCardProviderStatus.empty() => OsActiveCardProviderStatus(
        provider: 'none',
        defaultBankAccountId: '',
        qicard: OsWalletToggleStatus.empty(),
        zaincash: OsWalletToggleStatus.empty(),
        enabledMethods: const [],
      );

  factory OsActiveCardProviderStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OsActiveCardProviderStatus.empty();
    final methodsRaw = json['enabledMethods'];
    final methods = <String>[];
    if (methodsRaw is List) {
      for (final item in methodsRaw) {
        if (item is String && item.trim().isNotEmpty) {
          methods.add(item.trim().toLowerCase());
        }
      }
    }
    return OsActiveCardProviderStatus(
      provider: (json['provider'] as String?)?.trim().toLowerCase() ?? 'none',
      defaultBankAccountId:
          (json['defaultBankAccountId'] as String?)?.trim() ?? '',
      qicard: OsWalletToggleStatus.fromJson(
        json['qicard'] is Map
            ? Map<String, dynamic>.from(json['qicard'] as Map)
            : null,
      ),
      zaincash: OsWalletToggleStatus.fromJson(
        json['zaincash'] is Map
            ? Map<String, dynamic>.from(json['zaincash'] as Map)
            : null,
      ),
      enabledMethods: methods,
    );
  }

  OsActiveCardProviderStatus copyWith({
    String? provider,
    String? defaultBankAccountId,
    OsWalletToggleStatus? qicard,
    OsWalletToggleStatus? zaincash,
    List<String>? enabledMethods,
  }) {
    return OsActiveCardProviderStatus(
      provider: provider ?? this.provider,
      defaultBankAccountId:
          defaultBankAccountId ?? this.defaultBankAccountId,
      qicard: qicard ?? this.qicard,
      zaincash: zaincash ?? this.zaincash,
      enabledMethods: enabledMethods ?? this.enabledMethods,
    );
  }

  bool get isEnabled => enabledMethods.isNotEmpty;

  bool get isGatewayEnabled =>
      provider == 'paytabs' || provider == 'alqaseh';
}
