import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createChatVideoController(
  String url,
  bool isWeb,
) async {
  return VideoPlayerController.networkUrl(Uri.parse(url));
}
