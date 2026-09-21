import 'package:flutter_test/flutter_test.dart';
import 'package:point/Utils/phone_ltr.dart';

void main() {
  test('isolatePhoneLtr leaves empty unchanged', () {
    expect(isolatePhoneLtr(''), '');
    expect(isolatePhoneLtr('   '), '   ');
  });

  test('isolatePhoneLtr wraps non-empty value', () {
    const phone = '+964 775 307 7702';
    expect(isolatePhoneLtr(phone), '\u2066$phone\u2069');
  });
}
