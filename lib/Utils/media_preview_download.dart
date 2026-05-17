import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/chat_attachment_cache.dart';
import 'package:point/Utils/chat_attachment_save.dart';

String _successMessage(ChatAttachmentSaveResult result) {
  return switch (result.location) {
    ChatAttachmentSaveLocation.gallery => AppLocaleKeys.chatDownloadDoneGallery.tr,
    ChatAttachmentSaveLocation.downloads =>
      AppLocaleKeys.chatDownloadDoneDownloads.tr,
    ChatAttachmentSaveLocation.userSelected =>
      AppLocaleKeys.chatDownloadDoneSaved.tr,
    null => AppLocaleKeys.chatDownloadDone.tr,
  };
}

Future<Uint8List?> _bytesForPreviewDownload(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final cached = await ChatAttachmentCache.bytesFromCacheOnly(trimmed);
  if (cached != null && cached.isNotEmpty) return cached;
  try {
    return await ChatAttachmentCache.bytesForUrl(trimmed);
  } catch (_) {
    return ChatAttachmentCache.bytesFromCacheOnly(trimmed);
  }
}

Future<void> downloadMediaFromPreview(
  String url, {
  String? fileName,
}) async {
  final name = resolveChatDownloadFileName(fileName, url);
  final bytes = await _bytesForPreviewDownload(url);
  final result = bytes == null || bytes.isEmpty
      ? ChatAttachmentSaveResult.fail
      : await saveChatAttachmentBytes(bytes: bytes, fileName: name);
  if (result.ok) {
    FunHelper.showSnackbar(
      AppLocaleKeys.successTitle.tr,
      _successMessage(result),
      backgroundColor: const Color(0xFF2D2D2D),
      snackPosition: SnackPosition.BOTTOM,
      colorText: Colors.white,
    );
    return;
  }
  FunHelper.showSnackbar(
    AppLocaleKeys.errorTitle.tr,
    AppLocaleKeys.errorGeneric.tr,
    backgroundColor: const Color(0xFF8E1A1A),
    snackPosition: SnackPosition.BOTTOM,
    colorText: Colors.white,
  );
}

/// App bar download control for [ImagePreviewPage] / [VideoPlayerPage].
class MediaPreviewDownloadButton extends StatefulWidget {
  final String url;
  final String? fileName;

  const MediaPreviewDownloadButton({
    super.key,
    required this.url,
    this.fileName,
  });

  @override
  State<MediaPreviewDownloadButton> createState() =>
      _MediaPreviewDownloadButtonState();
}

class _MediaPreviewDownloadButtonState extends State<MediaPreviewDownloadButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await downloadMediaFromPreview(widget.url, fileName: widget.fileName);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _busy ? null : () => unawaited(_onPressed()),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
      ),
      tooltip: AppLocaleKeys.chatActionDownload.tr,
      icon: _busy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            )
          : const Icon(Icons.download_outlined, size: 22),
    );
  }
}
