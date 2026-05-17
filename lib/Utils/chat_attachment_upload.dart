import 'dart:typed_data';

import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/chat_image_compress.dart';
import 'package:point/View/Chats/chat_message_display.dart';
import 'package:point/View/Chats/pending_chat_attachment.dart';

/// Upload bytes and return a staged [PendingChatAttachment], or null on failure.
Future<PendingChatAttachment?> stageChatMediaUpload({
  required Uint8List bytes,
  required String fileName,
  required HomeController home,
}) async {
  var uploadBytes = bytes;
  var uploadName = fileName;
  if (isChatCompressibleImageFileName(fileName) &&
      !chatAttachmentIsVideo(fileName)) {
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

  final isVid = chatAttachmentIsVideo(fileName);
  return PendingChatAttachment(
    messageType: isVid ? 'video' : 'image',
    attachmentUrl: url,
    fileName: isVid ? fileName : null,
  );
}

/// Upload a generic file attachment (no image compression).
Future<PendingChatAttachment?> stageChatFileUpload({
  required Uint8List bytes,
  required String fileName,
  required HomeController home,
}) async {
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
}
