import 'dart:js_interop';
import 'dart:typed_data';

import 'package:mime/mime.dart' show lookupMimeType;
import 'package:web/web.dart';

import 'package:point/Utils/chat_attachment_save_types.dart';

Future<ChatAttachmentSaveResult> writeChatAttachmentBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    final mime = lookupMimeType(fileName) ?? 'application/octet-stream';
    final blobParts = <BlobPart>[bytes.toJS].toJS;
    final blob = Blob(blobParts, BlobPropertyBag(type: mime));
    final objectUrl = URL.createObjectURL(blob);

    final anchor = document.createElement('a') as HTMLAnchorElement
      ..href = objectUrl
      ..download = fileName
      ..style.display = 'none';

    document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(objectUrl);
    return const ChatAttachmentSaveResult(
      ok: true,
      location: ChatAttachmentSaveLocation.downloads,
    );
  } catch (_) {
    return ChatAttachmentSaveResult.fail;
  }
}
