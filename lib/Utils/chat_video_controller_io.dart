import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:point/Services/chat_attachment_cache.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createChatVideoController(
  String url,
  bool isWeb, {
  void Function(double? progress)? onProgress,
}) async {
  if (!isWeb) {
    try {
      final cached = await ChatAttachmentCache.fileFromCacheOnly(url);
      if (cached != null) {
        onProgress?.call(1.0);
        return VideoPlayerController.file(cached.file);
      }
      FileInfo? info;
      await for (final response in ChatAttachmentCache.fileStreamForUrl(url)) {
        if (response is DownloadProgress) {
          onProgress?.call(response.progress);
        } else if (response is FileInfo) {
          info = response;
        }
      }
      if (info != null) {
        onProgress?.call(1.0);
        return VideoPlayerController.file(info.file);
      }
    } catch (_) {}
  }
  return VideoPlayerController.networkUrl(Uri.parse(url));
}
