import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readVoiceRecordingFileBytes(String path) async {
  final f = File(path);
  for (var attempt = 0; attempt < 40; attempt++) {
    try {
      if (await f.exists()) {
        final len = await f.length();
        if (len > 0) return await f.readAsBytes();
      }
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return null;
}
