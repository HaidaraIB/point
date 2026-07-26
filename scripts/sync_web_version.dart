/// Writes [web/version.json] from [pubspec.yaml] `version: x.y.z+build`.
///
/// Run after bumping pubspec (CI also runs this before web deploy):
///   dart run scripts/sync_web_version.dart
library;

import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('Run from the repo root (pubspec.yaml not found).');
    exitCode = 1;
    return;
  }

  final match = RegExp(
    r'^version:\s*([^\s+#]+)(?:\+(\d+))?',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());

  if (match == null) {
    stderr.writeln('Could not parse version: from pubspec.yaml');
    exitCode = 1;
    return;
  }

  final version = match.group(1)!;
  final build = match.group(2) ?? '0';
  final out = File('web/version.json');
  out.writeAsStringSync('{"version":"$version","build_number":"$build"}\n');
  stdout.writeln('Wrote ${out.path} → $version+$build');
}
