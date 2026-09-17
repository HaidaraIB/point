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
