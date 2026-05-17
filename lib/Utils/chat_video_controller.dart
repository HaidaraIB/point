import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'chat_video_controller_io.dart'
    if (dart.library.html) 'chat_video_controller_stub.dart' as impl;

/// Prefer cached file on mobile; network URL on web or when cache fails.
Future<VideoPlayerController> chatVideoControllerForUrl(String url) =>
    impl.createChatVideoController(url, kIsWeb);
