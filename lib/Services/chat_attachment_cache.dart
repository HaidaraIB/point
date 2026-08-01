import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Persistent disk cache for chat attachment URLs (images, video, voice, files).
class ChatAttachmentCache {
  ChatAttachmentCache._();

  static const String _cacheKey = 'chat_attachments';

  static final CacheManager _manager = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 400,
    ),
  );

  static final Map<String, Future<Uint8List>> _inflightBytes = {};

  static Future<Uint8List> bytesForUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return Future<Uint8List>.error(ArgumentError('empty url'));
    }
    return _inflightBytes.putIfAbsent(
      trimmed,
      () => _loadBytes(trimmed).whenComplete(() {
        _inflightBytes.remove(trimmed);
      }),
    );
  }

  static Future<Uint8List> _loadBytes(String url) async {
    final cached = await _manager.getFileFromCache(url);
    if (cached != null) {
      return cached.file.readAsBytes();
    }
    final file = await _manager.getSingleFile(url);
    return file.readAsBytes();
  }

  /// Disk cache only (no network). Returns null if not cached.
  static Future<Uint8List?> bytesFromCacheOnly(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final cached = await _manager.getFileFromCache(trimmed);
    if (cached == null) return null;
    return cached.file.readAsBytes();
  }

  /// Cached file on disk only (no network). Returns null if not cached.
  static Future<FileInfo?> fileFromCacheOnly(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    return _manager.getFileFromCache(trimmed);
  }

  /// Cached file on disk (all platforms supported by cache_manager).
  static Future<dynamic> fileForUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return Future<dynamic>.error(ArgumentError('empty url'));
    }
    return _manager.getSingleFile(trimmed);
  }

  static Future<void> evictUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    // Drop any in-flight download so retry does not reuse a failed/hung Future.
    _inflightBytes.remove(trimmed);
    await _manager.removeFile(trimmed);
  }
}
