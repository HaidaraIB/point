import 'dart:io';

import 'package:point/Services/chat_attachment_cache.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createChatVideoController(
  String url,
  bool isWeb,
) async {
  if (!isWeb) {
    try {
      final file = await ChatAttachmentCache.fileForUrl(url);
      if (file is File) {
        return VideoPlayerController.file(file);
      }
    } catch (_) {}
  }
  return VideoPlayerController.networkUrl(Uri.parse(url));
}
