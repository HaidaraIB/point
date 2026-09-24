import 'package:flutter_test/flutter_test.dart';
import 'package:point/Models/Os/OsActiveCardProviderStatus.dart';

void main() {
  test('OsActiveCardProviderStatus parses enabledMethods and qicard', () {
    final status = OsActiveCardProviderStatus.fromJson({
      'provider': 'alqaseh',
      'defaultBankAccountId': 'bank-1',
      'qicard': {'enabled': true, 'bankAccountId': 'bank-2', 'configured': true},
      'enabledMethods': ['alqaseh', 'qicard'],
    });

    expect(status.provider, 'alqaseh');
    expect(status.isEnabled, isTrue);
    expect(status.isGatewayEnabled, isTrue);
    expect(status.enabledMethods, ['alqaseh', 'qicard']);
    expect(status.qicard.enabled, isTrue);
    expect(status.qicard.bankAccountId, 'bank-2');
  });

  test('isEnabled is false when no methods', () {
    final status = OsActiveCardProviderStatus.fromJson({
      'provider': 'none',
      'defaultBankAccountId': '',
      'enabledMethods': [],
    });
    expect(status.isEnabled, isFalse);
    expect(status.isGatewayEnabled, isFalse);
  });

}
