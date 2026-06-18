import 'dart:typed_data';

import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/chat_image_compress.dart';
import 'package:point/View/Chats/chat_message_display.dart';
import 'package:point/View/Chats/chat_private_typing.dart';
import 'package:point/View/Chats/pending_chat_attachment.dart';

/// Upload bytes and return a staged [PendingChatAttachment], or null on failure.
Future<PendingChatAttachment?> stageChatMediaUpload({
  required Uint8List bytes,
  required String fileName,
  required HomeController home,
  ChatActivityWriter? activityWriter,
}) async {
  final isVid = chatAttachmentIsVideo(fileName);
  try {
    activityWriter?.setUploading(isVid ? ChatUploadKind.video : ChatUploadKind.image);
    var uploadBytes = bytes;
    var uploadName = fileName;
    if (isChatCompressibleImageFileName(fileName) && !isVid) {
      uploadBytes = await compressChatImage(bytes, fileName);
      final lower = fileName.toLowerCase();
      if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg')) {
        final dot = uploadName.lastIndexOf('.');
        uploadName = dot > 0
            ? '${uploadName.substring(0, dot)}.jpg'
            : '$uploadName.jpg';
      }
    }

    final url = await home.uploadFiles(
      filePathOrBytes: uploadBytes,
      fileName: uploadName,
      useBlockingUploadDialog: false,
    );
    if (url == null) return null;

    return PendingChatAttachment(
      messageType: isVid ? 'video' : 'image',
      attachmentUrl: url,
      fileName: isVid ? fileName : null,
    );
  } finally {
    activityWriter?.setUploading(null);
  }
}

/// Upload a generic file attachment (no image compression).
Future<PendingChatAttachment?> stageChatFileUpload({
  required Uint8List bytes,
  required String fileName,
  required HomeController home,
  ChatActivityWriter? activityWriter,
}) async {
  try {
    activityWriter?.setUploading(ChatUploadKind.file);
    final url = await home.uploadFiles(
      filePathOrBytes: bytes,
      fileName: fileName,
      useBlockingUploadDialog: false,
    );
    if (url == null) return null;
    return PendingChatAttachment(
      messageType: 'file',
      attachmentUrl: url,
      fileName: fileName,
    );
  } finally {
    activityWriter?.setUploading(null);
  }
}
