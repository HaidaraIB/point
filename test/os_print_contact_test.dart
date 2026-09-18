import 'package:flutter_test/flutter_test.dart';
import 'package:point/Models/Os/OsGeneralSettings.dart';
import 'package:point/View/Os/Print/os_print_contact.dart';

void main() {
  group('OsPrintContact', () {
    test('html includes contact lines', () {
      const settings = OsGeneralSettings(
        printAddressAr: 'بغداد',
        printAddressEn: 'Baghdad',
        printPhone: '+964 1',
        printEmail: 'hello@point-iq.com',
        printWebsite: 'point-iq.com',
      );
      final html = OsPrintContact.previewHtml(settings);
      expect(html, contains('بغداد'));
      expect(html, contains('Baghdad'));
      expect(html, contains('+964 1'));
      expect(html, contains('hello@point-iq.com'));
      expect(html, contains('point-iq.com'));
      expect(html.contains('pc-corner'), isFalse);
      expect(html.contains(' voucher'), isFalse);
    });

    test('css keeps Arabic address line ltr like print', () {
      final css = OsPrintContact.css();
      expect(css, contains('.print-contact .pc-ar'));
      expect(
        css,
        matches(RegExp(r'\.print-contact \.pc-ar\s*\{[^}]*direction:\s*ltr')),
      );
      expect(
        css,
        isNot(matches(RegExp(r'\.print-contact \.pc-ar\s*\{[^}]*direction:\s*rtl'))),
      );
    });

    test('empty fields omit their rows', () {
      const settings = OsGeneralSettings(
        printAddressAr: '',
        printAddressEn: '',
        printPhone: '',
        printEmail: 'info@point-iq.com',
        printWebsite: '',
      );
      final html = OsPrintContact.previewHtml(settings);
      expect(html, contains('info@point-iq.com'));
      expect(html.contains('pc-ar'), isFalse);
      expect(html.contains('+964'), isFalse);
    });
  });
}
