import 'package:flutter_test/flutter_test.dart';
import 'package:point/Models/Os/qicard_config.dart';

// Real 2048-bit SPKI public key (test-only, no matching secret in the repo).
const _pem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiZZE6p1CYskphgm9SM2Y
Ot0jGATECil95naErtyXRi1Gq96Fxh8Y7wM5Q7YFomKRyyjFZWDTDhF1gL5FXYmV
BAtlYUwlOdlFznW7J7Z4193JsyEYFvsW9b+jhdu+mG/tgfeDzX+Pp1nAzCzrGv3P
xxwHiN6FrL6LvKUoBqH9gQCLfoIgTClqAI38f3xLHyJwUSyCEiuq9nUKxwX+qTSS
azlIPbgVL9KwHP7Hieac5Wb+bbuYTyfQETWZnnh8qY/v7s5gNl3ljuV5P1EHdNLk
Oc0ny8DD6EaXcGwJsiyMrA0+gQnQm0z3M4J+nO+R+NWrorSHnBgqpBiK91kMh/xZ
hQIDAQAB
-----END PUBLIC KEY-----''';

void main() {
  group('normalizeQicardBaseUrl', () {
    test('strips trailing slash and /api/v1', () {
      for (final input in [
        'https://3ds-api.qi.iq/api/v1',
        'https://3ds-api.qi.iq/api/v1/',
        '  https://3ds-api.qi.iq/api/v1  ',
        'https://3ds-api.qi.iq/',
        'https://3ds-api.qi.iq',
      ]) {
        expect(normalizeQicardBaseUrl(input), 'https://3ds-api.qi.iq',
            reason: input);
      }
    });

    test('effective root never doubles /api/v1 and defaults to live host', () {
      expect(qicardEffectiveLiveApiRoot('https://3ds-api.qi.iq/api/v1'),
          'https://3ds-api.qi.iq/api/v1');
      expect(qicardEffectiveLiveApiRoot(''), 'https://3ds-api.qi.iq/api/v1');
    });
  });

  test('isValidQicardBaseUrl', () {
    expect(isValidQicardBaseUrl(''), isTrue);
    expect(isValidQicardBaseUrl('https://3ds-api.qi.iq/api/v1'), isTrue);
    expect(isValidQicardBaseUrl('http://3ds-api.qi.iq'), isFalse);
    expect(isValidQicardBaseUrl('3ds-api.qi.iq'), isFalse);
    expect(isValidQicardBaseUrl('https://localhost'), isFalse);
  });

  group('checkQicardPublicKeyPem', () {
    test('valid key, including CRLF and BOM from a file', () {
      expect(checkQicardPublicKeyPem(_pem), QicardPemCheck.valid);
      expect(
        checkQicardPublicKeyPem('﻿${_pem.replaceAll('\n', '\r\n')}\r\n'),
        QicardPemCheck.valid,
      );
    });

    test('empty, private, truncated and garbage', () {
      expect(checkQicardPublicKeyPem('  '), QicardPemCheck.empty);
      expect(
        checkQicardPublicKeyPem(
            '-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----'),
        QicardPemCheck.privateKey,
      );
      expect(
        checkQicardPublicKeyPem(_pem.substring(0, 80)),
        QicardPemCheck.invalid,
      );
      expect(checkQicardPublicKeyPem('hello'), QicardPemCheck.invalid);
      expect(
        checkQicardPublicKeyPem(
            '-----BEGIN PUBLIC KEY-----\n!!!\n-----END PUBLIC KEY-----'),
        QicardPemCheck.invalid,
      );
    });
  });
}
