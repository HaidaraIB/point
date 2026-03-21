import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('translations parity between ar and en', () {
    final source = File('lib/Localization/AppTranslations.dart').readAsStringSync();
    final en = _extractKeys(source, "'en': {");
    final ar = _extractKeys(source, "'ar': {");
    const skipKeys = {'en', 'ar'};
    final enKeys = en.where((k) => !skipKeys.contains(k)).toSet();
    final arKeys = ar.where((k) => !skipKeys.contains(k)).toSet();

    final missingInEn = arKeys.difference(enKeys);
    final missingInAr = enKeys.difference(arKeys);

    expect(
      missingInEn,
      isEmpty,
      reason: 'Missing keys in en: ${missingInEn.toList()..sort()}',
    );
    expect(
      missingInAr,
      isEmpty,
      reason: 'Missing keys in ar: ${missingInAr.toList()..sort()}',
    );
  });
}

Set<String> _extractKeys(String source, String marker) {
  final start = source.indexOf(marker);
  if (start == -1) return {};
  final section = source.substring(start);
  final nextLang = section.indexOf("'ar': {");
  final block = nextLang > 0 && marker.contains("'en'") ? section.substring(0, nextLang) : section;
  return RegExp(r"'([^']+)'\s*:")
      .allMatches(block)
      .map((m) => m.group(1)!)
      .where((k) => k.isNotEmpty)
      .toSet()
    ..addAll(
      RegExp(r'"([^"]+)"\s*:')
      .allMatches(block)
      .map((m) => m.group(1)!)
      .where((k) => k.isNotEmpty),
    );
}
