import 'dart:io';

void main() {
  final root = Directory.current.path;
  final translations = File('$root/lib/Localization/AppTranslations.dart').readAsStringSync();
  final en = _extractKeys(translations, "'en': {");
  final ar = _extractKeys(translations, "'ar': {");

  final missingInEn = ar.difference(en).toList()..sort();
  final missingInAr = en.difference(ar).toList()..sort();

  final hardcodedView = <String>[];
  final viewDir = Directory('$root/lib/View');
  for (final entity in viewDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    final matches = RegExp(r"Text\(\s*'[^']*[\u0600-\u06FF][^']*'").allMatches(content);
    for (final _ in matches) {
      hardcodedView.add(entity.path.replaceAll('\\', '/'));
      break;
    }
  }
  hardcodedView.sort();

  final hardcodedServices = <String>[];
  final servicesDir = Directory('$root/lib/Services');
  if (servicesDir.existsSync()) {
    for (final entity in servicesDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      if (RegExp(r"[\u0600-\u06FF]").hasMatch(content) &&
          !entity.path.endsWith('NotificationService.dart')) {
        hardcodedServices.add(entity.path.replaceAll('\\', '/'));
      }
    }
  }
  hardcodedServices.sort();

  final report = StringBuffer()
    ..writeln('# i18n audit report')
    ..writeln()
    ..writeln('missingInEn: ${missingInEn.length}')
    ..writeln('missingInAr: ${missingInAr.length}')
    ..writeln('hardcodedViewFiles: ${hardcodedView.length}')
    ..writeln()
    ..writeln('## Missing in en')
    ..writeln(missingInEn.join('\n'))
    ..writeln()
    ..writeln('## Missing in ar')
    ..writeln(missingInAr.join('\n'))
    ..writeln()
    ..writeln('## View files with hardcoded Arabic Text literals')
    ..writeln(hardcodedView.join('\n'))
    ..writeln()
    ..writeln('## Service files containing Arabic (comments/strings; review manually)')
    ..writeln(hardcodedServices.join('\n'));

  final out = File('$root/docs/i18n_audit_report.md');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(report.toString());
  stdout.writeln('i18n audit saved to ${out.path}');
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
