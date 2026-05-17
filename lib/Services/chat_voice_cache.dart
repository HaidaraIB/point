import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:point/Services/chat_attachment_cache.dart';

/// Voice playback uses the shared [ChatAttachmentCache] (disk + in-flight dedupe).
class ChatVoiceCache {
  ChatVoiceCache._();

  static String? mimeTypeForUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.mp3')) return 'audio/mpeg';
    if (u.contains('.m4a')) return 'audio/mp4';
    if (u.contains('.wav')) return 'audio/wav';
    if (u.contains('.aac')) return 'audio/aac';
    if (u.contains('.ogg')) return 'audio/ogg';
    return 'audio/mp4';
  }

  static Future<Source> sourceForUrl(String url) async {
    final bytes = await bytesForUrl(url);
    return BytesSource(bytes, mimeType: mimeTypeForUrl(url));
  }

  static Future<Uint8List> bytesForUrl(String url) =>
      ChatAttachmentCache.bytesForUrl(url);
}
