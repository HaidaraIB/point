import 'package:flutter_test/flutter_test.dart';
import 'package:point/Localization/notify_translations_map.dart';

void main() {
  test('notifyTranslationsEn and notifyTranslationsAr have same keys', () {
    final en = notifyTranslationsEn.keys.toSet();
    final ar = notifyTranslationsAr.keys.toSet();
    expect(en.difference(ar), isEmpty,
        reason: 'Missing in AR: ${en.difference(ar).toList()..sort()}');
    expect(ar.difference(en), isEmpty,
        reason: 'Missing in EN: ${ar.difference(en).toList()..sort()}');
  });
}
