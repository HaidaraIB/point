import 'package:point/Models/Os/OsQicardSettingsStatus.dart';

class OsActiveCardProviderStatus {
  const OsActiveCardProviderStatus({
    required this.provider,
    required this.defaultBankAccountId,
    required this.qicard,
    required this.enabledMethods,
  });

  final String provider;
  final String defaultBankAccountId;
  final OsQicardToggleStatus qicard;
  final List<String> enabledMethods;

  factory OsActiveCardProviderStatus.empty() => OsActiveCardProviderStatus(
        provider: 'none',
        defaultBankAccountId: '',
        qicard: OsQicardToggleStatus.empty(),
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
      qicard: OsQicardToggleStatus.fromJson(
        json['qicard'] is Map
            ? Map<String, dynamic>.from(json['qicard'] as Map)
            : null,
      ),
      enabledMethods: methods,
    );
  }

  bool get isEnabled => enabledMethods.isNotEmpty;

  bool get isGatewayEnabled =>
      provider == 'paytabs' || provider == 'alqaseh';
}
