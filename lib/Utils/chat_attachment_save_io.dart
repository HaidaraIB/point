import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:mime/mime.dart' show lookupMimeType;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:point/Utils/chat_attachment_save_types.dart';
import 'package:point/View/Chats/chat_message_display.dart';

const _androidDownloadsChannel = MethodChannel('com.point.agency/chat_download');

bool _isMobileGalleryTarget(String fileName) {
  final probe = 'https://save.local/${fileName.split('/').last}';
  return isImageUrl(probe) ||
      isVideoUrl(probe) ||
      chatAttachmentIsVideo(fileName);
}

Future<String> _writeTempFile(Uint8List bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final safe = fileName.split('/').last.split(r'\').last;
  final path = p.join(dir.path, safe);
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return path;
}

Future<void> _deleteQuietly(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

Future<bool> _ensureGalleryAccess() async {
  if (await Gal.hasAccess()) return true;
  await Gal.requestAccess();
  return Gal.hasAccess();
}

Future<ChatAttachmentSaveResult> writeChatAttachmentBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    if (_isMobileGalleryTarget(fileName)) {
      if (!await _ensureGalleryAccess()) {
        return ChatAttachmentSaveResult.fail;
      }
      if (isImageUrl('https://save.local/${fileName.split('/').last}')) {
        await Gal.putImageBytes(bytes, name: fileName.split('/').last);
      } else {
        final temp = await _writeTempFile(bytes, fileName);
        try {
          await Gal.putVideo(temp);
        } finally {
          await _deleteQuietly(temp);
        }
      }
      return const ChatAttachmentSaveResult(
        ok: true,
        location: ChatAttachmentSaveLocation.gallery,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final temp = await _writeTempFile(bytes, fileName);
      try {
        final mime =
            lookupMimeType(fileName) ?? 'application/octet-stream';
        final ok =
            await _androidDownloadsChannel.invokeMethod<bool>(
              'saveToDownloads',
              {
                'path': temp,
                'fileName': fileName.split('/').last,
                'mimeType': mime,
              },
            ) ??
            false;
        return ChatAttachmentSaveResult(
          ok: ok,
          location: ok ? ChatAttachmentSaveLocation.downloads : null,
        );
      } finally {
        await _deleteQuietly(temp);
      }
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final savedPath = await FilePicker.saveFile(
        fileName: fileName.split('/').last,
        bytes: bytes,
        type: FileType.any,
      );
      final ok = savedPath != null && savedPath.isNotEmpty;
      return ChatAttachmentSaveResult(
        ok: ok,
        location: ok ? ChatAttachmentSaveLocation.userSelected : null,
      );
    }

    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = await _uniqueFileInDirectory(dir, fileName.split('/').last);
    await file.writeAsBytes(bytes, flush: true);
    return const ChatAttachmentSaveResult(
      ok: true,
      location: ChatAttachmentSaveLocation.downloads,
    );
  } on GalException {
    return ChatAttachmentSaveResult.fail;
  } catch (_) {
    return ChatAttachmentSaveResult.fail;
  }
}

Future<File> _uniqueFileInDirectory(Directory dir, String baseName) async {
  var candidate = File(p.join(dir.path, baseName));
  if (!await candidate.exists()) return candidate;

  final dot = baseName.lastIndexOf('.');
  final stem = dot > 0 ? baseName.substring(0, dot) : baseName;
  final ext = dot > 0 ? baseName.substring(dot) : '';

  var i = 1;
  while (await candidate.exists()) {
    candidate = File(p.join(dir.path, '$stem ($i)$ext'));
    i++;
    if (i > 999) break;
  }
  return candidate;
}
