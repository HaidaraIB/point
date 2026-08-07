import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Progress / completion event while loading attachment bytes from cache or network.
class ChatAttachmentBytesEvent {
  const ChatAttachmentBytesEvent({
    this.downloaded = 0,
    this.totalSize,
    this.bytes,
  });

  final int downloaded;
  final int? totalSize;
  final Uint8List? bytes;

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;

  /// 0..1 when total size is known; null when indeterminate.
  double? get progress {
    if (totalSize == null || totalSize! <= 0 || downloaded > totalSize!) {
      return null;
    }
    return downloaded / totalSize!;
  }
}

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

  /// Stream progress then file info for [url] (`withProgress: true`).
  ///
  /// Throws if no stream event arrives for [idleTimeout] (hung download).
  static Stream<FileResponse> fileStreamForUrl(
    String url, {
    Duration idleTimeout = const Duration(seconds: 45),
  }) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return Stream.error(ArgumentError('empty url'));
    }
    return _manager
        .getFileStream(trimmed, withProgress: true)
        .timeout(idleTimeout);
  }

  /// Stream download progress then decoded bytes for [url].
  ///
  /// Throws if no stream event arrives for [idleTimeout] (hung download).
  static Stream<ChatAttachmentBytesEvent> bytesStreamForUrl(
    String url, {
    Duration idleTimeout = const Duration(seconds: 45),
  }) async* {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('empty url');
    }
    await for (final response in _manager
        .getFileStream(trimmed, withProgress: true)
        .timeout(idleTimeout)) {
      if (response is DownloadProgress) {
        yield ChatAttachmentBytesEvent(
          downloaded: response.downloaded,
          totalSize: response.totalSize,
        );
      } else if (response is FileInfo) {
        final bytes = await response.file.readAsBytes();
        yield ChatAttachmentBytesEvent(
          downloaded: bytes.length,
          totalSize: bytes.length,
          bytes: bytes,
        );
      }
    }
  }

  static Future<void> evictUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    // Drop any in-flight download so retry does not reuse a failed/hung Future.
    _inflightBytes.remove(trimmed);
    await _manager.removeFile(trimmed);
  }
}
