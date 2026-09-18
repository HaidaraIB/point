import 'package:flutter_test/flutter_test.dart';
import 'package:point/Models/Os/OsGeneralSettings.dart';
import 'package:point/Utils/os_currency.dart';

void main() {
  group('OsGeneralSettings', () {
    test('defaults to point_os exchange rate', () {
      expect(OsGeneralSettings.defaults().usdToIqdRate, 1530.0);
    });

    test('fromJson uses default when rate missing or invalid', () {
      expect(OsGeneralSettings.fromJson(null).usdToIqdRate, 1530.0);
      expect(OsGeneralSettings.fromJson({}).usdToIqdRate, 1530.0);
      expect(
        OsGeneralSettings.fromJson({'usdToIqdRate': 0}).usdToIqdRate,
        1530.0,
      );
      expect(
        OsGeneralSettings.fromJson({'usdToIqdRate': -10}).usdToIqdRate,
        1530.0,
      );
    });

    test('fromJson parses valid rate', () {
      expect(
        OsGeneralSettings.fromJson({'usdToIqdRate': 1600}).usdToIqdRate,
        1600.0,
      );
    });

    test('defaults include current print contact lines', () {
      final s = OsGeneralSettings.defaults();
      expect(s.printAddressAr, 'البصرة - العراق');
      expect(s.printAddressEn, 'Basra, Iraq');
      expect(s.printPhone, '+964 770 000 0000');
      expect(s.printEmail, 'info@point-iq.com');
      expect(s.printWebsite, 'www.point-iq.com');
      expect(s.printWebsiteUrl, 'https://www.point-iq.com');
    });

    test('fromJson keeps contact fields when rate is invalid', () {
      final s = OsGeneralSettings.fromJson({
        'usdToIqdRate': 0,
        'printPhone': '+964 780 111 2222',
      });
      expect(s.usdToIqdRate, 1530.0);
      expect(s.printPhone, '+964 780 111 2222');
    });

    test('fromJson keeps empty contact strings', () {
      final s = OsGeneralSettings.fromJson({
        'printPhone': '',
        'printEmail': '',
      });
      expect(s.printPhone, isEmpty);
      expect(s.printEmail, isEmpty);
      expect(s.printAddressAr, 'البصرة - العراق');
    });

    test('printWebsiteUrl prefixes https when missing', () {
      expect(
        const OsGeneralSettings(printWebsite: 'point-iq.com').printWebsiteUrl,
        'https://point-iq.com',
      );
      expect(
        const OsGeneralSettings(
          printWebsite: 'https://point-iq.com',
        ).printWebsiteUrl,
        'https://point-iq.com',
      );
    });

    test('printContactToJson omits exchange rate', () {
      final json = OsGeneralSettings.defaults().printContactToJson();
      expect(json.containsKey('usdToIqdRate'), isFalse);
      expect(json['printEmail'], 'info@point-iq.com');
    });
  });

  group('os_currency', () {
    test('convertUsdToIqd multiplies by provided rate', () {
      expect(convertUsdToIqd(100, rate: 1600), 160000.0);
    });

    test('convertUsdToIqd falls back to default rate', () {
      expect(convertUsdToIqd(2), 3060.0);
    });

    test('isValidUsdToIqdRate rejects non-positive values', () {
      expect(isValidUsdToIqdRate(1530), isTrue);
      expect(isValidUsdToIqdRate(0), isFalse);
      expect(isValidUsdToIqdRate(-1), isFalse);
    });
  });
}
