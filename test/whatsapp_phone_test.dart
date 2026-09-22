import 'package:flutter_test/flutter_test.dart';
import 'package:point/Utils/whatsapp_phone.dart';

void main() {
  test('normalizeWhatsappPhone handles Iraqi local leading zero', () {
    expect(normalizeWhatsappPhone('07701234567'), '9647701234567');
  });

  test('normalizeWhatsappPhoneParts uses selected dial code', () {
    expect(
      normalizeWhatsappPhoneParts(dialCode: '966', nationalNumber: '0501234567'),
      '966501234567',
    );
  });

  test('splitWhatsappPhone separates stored digits', () {
    final split = splitWhatsappPhone('9647701234567');
    expect(split.dialCode, '964');
    expect(split.national, '7701234567');
  });

  test('sanitizeNationalPhoneInput strips pasted international prefix', () {
    expect(
      sanitizeNationalPhoneInput('+9647701234567', dialCode: '964'),
      '7701234567',
    );
    expect(
      sanitizeNationalPhoneInput('009647701234567', dialCode: '964'),
      '7701234567',
    );
    expect(
      sanitizeNationalPhoneInput('07701234567', dialCode: '964'),
      '7701234567',
    );
  });

  test('sanitizeNationalPhoneInput does not double non-Iraq dial code', () {
    expect(
      sanitizeNationalPhoneInput('0501234567', dialCode: '966'),
      '501234567',
    );
    expect(
      normalizeWhatsappPhoneParts(dialCode: '966', nationalNumber: '966501234567'),
      '966501234567',
    );
  });

  test('formatWhatsappPhoneDisplay adds plus and separates country code', () {
    expect(formatWhatsappPhoneDisplay('9647701234567'), '+964 7701234567');
    expect(formatWhatsappPhoneDisplay('+964 770 123 4567'), '+964 7701234567');
    expect(formatWhatsappPhoneDisplay('9647812113063'), '+964 7812113063');
  });
}
