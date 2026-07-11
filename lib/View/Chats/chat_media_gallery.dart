import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/chat_video_controller.dart';
import 'package:point/Utils/media_preview_cached_image.dart';
import 'package:point/Utils/media_preview_download.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:video_player/video_player.dart';

bool _chatAttachmentIsVideo(String fileName) {
  final base = fileName.trim().split('/').last.split('?').first;
  final dot = base.lastIndexOf('.');
  if (dot < 0 || dot >= base.length - 1) return false;
  const v = {'mp4', 'mov', 'webm', 'm4v', 'avi', 'mkv'};
  return v.contains(base.substring(dot + 1).toLowerCase());
}

bool _messageShowsAsVideo(
  String? messageType,
  String attachmentUrl,
  String? fileName,
) {
  if (messageType == 'video') return true;
  if (isVideoMediaUrl(attachmentUrl)) return true;
  if (fileName != null && _chatAttachmentIsVideo(fileName)) return true;
  return false;
}

class ChatMediaItem {
  final String url;
  final String type;
  final String messageId;

  const ChatMediaItem({
    required this.url,
    required this.type,
    required this.messageId,
  });

  bool get isVideo => type == 'video';
}

/// Latest loaded thread media per chat (updated from message list streams).
class ChatMediaGalleryStore {
  ChatMediaGalleryStore._();

  static final Map<String, List<ChatMediaItem>> _itemsByChat = {};

  static void update(
    String chatId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (chatId.isEmpty) return;
    _itemsByChat[chatId] = collectChatGalleryMedia(docs);
  }

  static List<ChatMediaItem> itemsFor(String chatId) =>
      _itemsByChat[chatId] ?? const [];
}

List<ChatMediaItem> collectChatGalleryMedia(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final items = <ChatMediaItem>[];
  for (var i = docs.length - 1; i >= 0; i--) {
    final doc = docs[i];
    final msg = doc.data();
    if (msg['deleted'] == true) continue;
    final type = (msg['messageType'] as String?)?.trim();
    final url = (msg['attachmentUrl'] as String?)?.trim() ?? '';
    if (url.isEmpty) continue;
    if (type == 'image' || (type != 'voice' && isImageMediaUrl(url))) {
      items.add(ChatMediaItem(url: url, type: 'image', messageId: doc.id));
      continue;
    }
    if (type == 'video' ||
        _messageShowsAsVideo(type, url, msg['fileName'] as String?)) {
      items.add(ChatMediaItem(url: url, type: 'video', messageId: doc.id));
    }
  }
  return items;
}

void openChatMediaGallery({
  required List<ChatMediaItem> items,
  String? initialMessageId,
  String? initialUrl,
}) {
  if (items.isEmpty) return;
  var index = 0;
  if (initialMessageId != null) {
    final i = items.indexWhere((e) => e.messageId == initialMessageId);
    if (i >= 0) index = i;
  } else if (initialUrl != null) {
    final i = items.indexWhere((e) => e.url == initialUrl.trim());
    if (i >= 0) index = i;
  }
  if (items.length == 1) {
    final item = items[index];
    if (item.isVideo) {
      Get.to(() => _ChatGalleryVideoPage(url: item.url));
    } else {
      Get.to(() => _ChatGalleryImagePage(url: item.url));
    }
    return;
  }
  Get.to(
    () => ChatMediaGalleryPage(items: items, initialIndex: index),
  );
}

Future<void> openChatMediaFromUrl(
  String url, {
  String? chatId,
  String? messageId,
}) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;

  final normalized = normalizeUrlForLaunch(trimmed);
  if (chatId != null && chatId.isNotEmpty) {
    final items = ChatMediaGalleryStore.itemsFor(chatId);
    final isGalleryMedia = isImageMediaUrl(normalized) || isVideoMediaUrl(normalized);
    if (isGalleryMedia && items.length > 1) {
      openChatMediaGallery(
        items: items,
        initialMessageId: messageId,
        initialUrl: normalized,
      );
      return;
    }
    if (isGalleryMedia && items.length == 1) {
      openChatMediaGallery(items: items, initialMessageId: messageId);
      return;
    }
  }

  await openUrlPreferInAppMedia(trimmed);
}

class ChatMediaGalleryPage extends StatefulWidget {
  final List<ChatMediaItem> items;
  final int initialIndex;

  const ChatMediaGalleryPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<ChatMediaGalleryPage> createState() => _ChatMediaGalleryPageState();
}

class _ChatMediaGalleryPageState extends State<ChatMediaGalleryPage> {
  late final PageController _pageController;
  late final FocusNode _focusNode;
  late int _index;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.items.length - 1);
    if (next == _index) return;
    setState(() => _index = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Get.back();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    const bg = Color(0xFF0A0A0F);

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} / ${items.length}',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          MediaPreviewDownloadButton(url: items[_index].url),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focusNode.requestFocus(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: items.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    if (item.isVideo) {
                      return _ChatGalleryVideoPage(
                        url: item.url,
                        embedded: true,
                      );
                    }
                    return _ChatGalleryZoomableImage(url: item.url);
                  },
                ),
                if (items.length > 1) ...[
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Material(
                        color: Colors.black38,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.west, color: Colors.white),
                          iconSize: 36,
                          onPressed: _index > 0 ? () => _go(-1) : null,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Material(
                        color: Colors.black38,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.east, color: Colors.white),
                          iconSize: 36,
                          onPressed:
                              _index < items.length - 1 ? () => _go(1) : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatGalleryImagePage extends StatelessWidget {
  final String url;

  const _ChatGalleryImagePage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [MediaPreviewDownloadButton(url: url)],
      ),
      body: _ChatGalleryZoomableImage(url: url),
    );
  }
}

class _ChatGalleryZoomableImage extends StatefulWidget {
  final String url;

  const _ChatGalleryZoomableImage({required this.url});

  @override
  State<_ChatGalleryZoomableImage> createState() =>
      _ChatGalleryZoomableImageState();
}

class _ChatGalleryZoomableImageState extends State<_ChatGalleryZoomableImage> {
  final TransformationController _tc = TransformationController();
  double _scale = 1.0;

  static const double _kPanScaleThreshold = 1.06;
  static const double _kResetScale = 1.02;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final nextScale = _tc.value.getMaxScaleOnAxis();
    if (nextScale <= _kResetScale && _scale > _kResetScale) {
      _tc.removeListener(_onTransformChanged);
      _tc.value = Matrix4.identity();
      _tc.addListener(_onTransformChanged);
      setState(() => _scale = 1.0);
      return;
    }
    if ((nextScale - _scale).abs() > 0.008) {
      setState(() => _scale = nextScale);
    }
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransformChanged);
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _tc,
      panEnabled: _scale > _kPanScaleThreshold,
      scaleEnabled: true,
      minScale: 0.55,
      maxScale: 5,
      boundaryMargin: const EdgeInsets.all(48),
      child: Center(
        child: MediaPreviewCachedImage(url: widget.url),
      ),
    );
  }
}

class _ChatGalleryVideoPage extends StatefulWidget {
  final String url;
  final bool embedded;

  const _ChatGalleryVideoPage({required this.url, this.embedded = false});

  @override
  State<_ChatGalleryVideoPage> createState() => _ChatGalleryVideoPageState();
}

class _ChatGalleryVideoPageState extends State<_ChatGalleryVideoPage> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final c = await chatVideoControllerForUrl(widget.url);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _ready = true;
      });
      await c.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(
          AppLocaleKeys.chatPreviewVideoFailed.tr,
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    if (!_ready || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }
    final c = _controller!;
    final content = Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
        child: VideoPlayer(c),
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [MediaPreviewDownloadButton(url: widget.url)],
      ),
      body: content,
    );
  }
}
