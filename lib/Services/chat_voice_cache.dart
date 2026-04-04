import 'dart:collection';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

/// تخزين مؤقت في الذاكرة لملفات الصوت القصيرة (رسائل الدردشة)، مع حدّ حجم وعدد
/// لتفادي نمو غير محدود. يعمل على الويب والموبايل دون `dart:io`.
class ChatVoiceCache {
  ChatVoiceCache._();

  static const int maxEntries = 14;
  static const int maxTotalBytes = 18 * 1024 * 1024;

  static final LinkedHashMap<String, Uint8List> _lru = LinkedHashMap();
  static int _totalBytes = 0;
  static final Map<String, Future<Uint8List>> _inflight = {};

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

  static Future<Uint8List> bytesForUrl(String url) {
    final cached = _lru.remove(url);
    if (cached != null) {
      _lru[url] = cached;
      return Future<Uint8List>.value(cached);
    }
    return _inflight.putIfAbsent(
      url,
      () => _downloadAndStore(url).whenComplete(() {
        _inflight.remove(url);
      }),
    );
  }

  static Future<Uint8List> _downloadAndStore(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('voice_fetch_${res.statusCode}');
    }
    final body = res.bodyBytes;
    _evictUntilRoomFor(body.length);
    _lru[url] = body;
    _totalBytes += body.length;
    return body;
  }

  static void _evictUntilRoomFor(int incoming) {
    while ((_totalBytes + incoming > maxTotalBytes || _lru.length >= maxEntries) &&
        _lru.isNotEmpty) {
      final k = _lru.keys.first;
      final v = _lru.remove(k)!;
      _totalBytes -= v.length;
    }
  }
}
