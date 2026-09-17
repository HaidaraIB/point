import 'package:flutter_test/flutter_test.dart';
import 'package:point/Models/Os/OsEmailSettings.dart';

void main() {
  group('OsEmailSettings', () {
    test('fromJson uses defaults when json is null', () {
      final settings = OsEmailSettings.fromJson(null);
      expect(settings.senderName, '');
      expect(settings.senderEmail, '');
    });

    test('fromJson preserves explicit empty strings', () {
      final settings = OsEmailSettings.fromJson({
        'senderName': '',
        'senderEmail': '',
        'replyToEmail': '',
        'signatureText': '',
        'autoBccEmail': '',
        'companyAddress': '',
        'companyPhone': '',
        'companyWebsite': '',
        'enableAutoBcc': false,
      });

      expect(settings.senderName, '');
      expect(settings.senderEmail, '');
      expect(settings.replyToEmail, '');
      expect(settings.signatureText, '');
      expect(settings.autoBccEmail, '');
      expect(settings.companyAddress, '');
      expect(settings.companyPhone, '');
      expect(settings.companyWebsite, '');
      expect(settings.enableAutoBcc, false);
    });

    test('fromJson uses defaults only for missing keys', () {
      final settings = OsEmailSettings.fromJson({
        'senderName': 'Custom Agency',
      });

      expect(settings.senderName, 'Custom Agency');
      expect(settings.senderEmail, '');
    });

    test('toJson round-trips explicit empty strings', () {
      const settings = OsEmailSettings(
        senderName: '',
        senderEmail: '',
        replyToEmail: '',
        signatureText: '',
        enableAutoBcc: false,
        autoBccEmail: '',
        companyAddress: '',
        companyPhone: '',
        companyWebsite: '',
      );

      final restored = OsEmailSettings.fromJson(settings.toJson());
      expect(restored.senderName, '');
      expect(restored.senderEmail, '');
      expect(restored.enableAutoBcc, false);
    });
  });
}
