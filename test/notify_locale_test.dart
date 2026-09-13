import 'package:flutter_test/flutter_test.dart';
import 'package:point/Localization/notify_locale.dart';

void main() {
  group('NotifyLocale.normalize', () {
    test('defaults empty to ar', () {
      expect(NotifyLocale.normalize(null), 'ar');
      expect(NotifyLocale.normalize(''), 'ar');
      expect(NotifyLocale.normalize('  '), 'ar');
    });

    test('accepts ar and en variants', () {
      expect(NotifyLocale.normalize('ar'), 'ar');
      expect(NotifyLocale.normalize('AR'), 'ar');
      expect(NotifyLocale.normalize('ar-IQ'), 'ar');
      expect(NotifyLocale.normalize('en'), 'en');
      expect(NotifyLocale.normalize('en-US'), 'en');
    });

    test('unknown codes fall back to ar', () {
      expect(NotifyLocale.normalize('fr'), 'ar');
    });
  });

  group('NotifyLocale.tr', () {
    test('returns English for en locale', () {
      expect(
        NotifyLocale.tr('en', 'notify.emp.assigned.title'),
        'You have been assigned a new task',
      );
    });

    test('returns Arabic for ar locale', () {
      final ar = NotifyLocale.tr('ar', 'notify.emp.assigned.title');
      expect(ar, isNot(equals('You have been assigned a new task')));
      expect(ar, isNotEmpty);
    });

    test('substitutes @params', () {
      expect(
        NotifyLocale.tr('en', 'notify.emp.rejected.body', {
          'title': 'Design logo',
        }),
        contains('Design logo'),
      );
      expect(
        NotifyLocale.tr('en', 'notify.emp.rejected.body', {
          'title': 'Design logo',
        }),
        isNot(contains('@title')),
      );
    });

    test('unknown key returns the key itself after fallbacks', () {
      expect(
        NotifyLocale.tr('en', 'notify.does.not.exist.xyz'),
        'notify.does.not.exist.xyz',
      );
    });
  });
}
