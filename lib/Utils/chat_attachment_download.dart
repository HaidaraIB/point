import 'package:point/View/Chats/chat_message_display.dart';

/// URL + optional display name for saving a chat attachment.
class ChatDownloadableAttachment {
  final String url;
  final String? fileName;

  const ChatDownloadableAttachment({required this.url, this.fileName});
}

final _uuidFileStemRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool _httpUrl(String s) =>
    s.startsWith('http://') || s.startsWith('https://');

bool _isStorageStyleUuidName(String? name) {
  if (name == null || name.trim().isEmpty) return false;
  final base = name.trim().split('/').last.split('?').first;
  final dot = base.lastIndexOf('.');
  final stem = dot >= 0 ? base.substring(0, dot) : base;
  return _uuidFileStemRegex.hasMatch(stem);
}

/// Resolves a downloadable attachment for image, video, file, and voice messages.
ChatDownloadableAttachment? chatDownloadableAttachmentFromMessage(
  Map<String, dynamic> m,
) {
  if (m['deleted'] == true) return null;

  final type = (m['messageType'] as String?)?.trim() ?? 'text';
  final attachmentUrl = (m['attachmentUrl'] as String?)?.trim() ?? '';
  final text = (m['text'] ?? '').toString().trim();
  var storedName = (m['fileName'] as String?)?.trim();

  String? url;
  if (_httpUrl(attachmentUrl)) {
    url = attachmentUrl;
  } else if (type == 'voice' && _httpUrl(text)) {
    url = text;
  }
  if (url == null) return null;

  switch (type) {
    case 'image':
    case 'video':
    case 'file':
    case 'voice':
      break;
    case 'text':
    case '':
      final fn = storedName ?? '';
      final isMedia = isImageUrl(url) ||
          isVideoUrl(url) ||
          chatAttachmentIsVideo(fn) ||
          fn.isNotEmpty;
      if (!isMedia) return null;
      break;
    default:
      return null;
  }

  if (_isStorageStyleUuidName(storedName)) {
    storedName = null;
  }

  String? fileName = storedName;
  if (fileName == null || fileName.isEmpty) {
    if (type == 'voice') {
      fileName = 'voice.m4a';
    }
  }

  return ChatDownloadableAttachment(url: url, fileName: fileName);
}
