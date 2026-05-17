import 'dart:typed_data';

import 'package:point/Services/chat_attachment_cache.dart';
import 'package:point/Utils/chat_attachment_save_types.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';

import 'chat_attachment_save_io.dart'
    if (dart.library.html) 'chat_attachment_save_web.dart' as impl;

export 'chat_attachment_save_types.dart';

String sanitizeChatDownloadFileName(String name) {
  var s = name.trim();
  if (s.isEmpty) return 'download';
  s = s.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return 'download';
  if (s.length > 180) {
    final dot = s.lastIndexOf('.');
    if (dot > 0 && dot < s.length - 1) {
      final ext = s.substring(dot);
      final stemMax = 180 - ext.length;
      if (stemMax > 1) s = '${s.substring(0, stemMax)}$ext';
    } else {
      s = s.substring(0, 180);
    }
  }
  return s;
}

String resolveChatDownloadFileName(String? preferred, String url) {
  final p = preferred?.trim() ?? '';
  final derived = TaskDetailsDialogHelpers.attachmentFileNameFromUrl(url.trim());
  return sanitizeChatDownloadFileName(p.isNotEmpty ? p : derived);
}

Future<Uint8List?> fetchChatAttachmentBytes(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  try {
    return await ChatAttachmentCache.bytesForUrl(trimmed);
  } catch (_) {
    return null;
  }
}

/// Writes already-loaded bytes (e.g. from [ChatAttachmentCache]) to gallery/downloads.
Future<ChatAttachmentSaveResult> saveChatAttachmentBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  final name = sanitizeChatDownloadFileName(fileName);
  return impl.writeChatAttachmentBytes(bytes: bytes, fileName: name);
}

/// Downloads a chat attachment in-app (no external browser).
Future<ChatAttachmentSaveResult> saveChatAttachment({
  required String url,
  String? fileName,
}) async {
  final name = resolveChatDownloadFileName(fileName, url);
  final bytes = await fetchChatAttachmentBytes(url);
  if (bytes == null) return ChatAttachmentSaveResult.fail;
  return saveChatAttachmentBytes(bytes: bytes, fileName: name);
}
