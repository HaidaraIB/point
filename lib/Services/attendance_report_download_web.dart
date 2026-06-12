import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

Future<void> downloadAttendanceReportFile({
  required String contents,
  required String fileName,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(contents));
  final blobParts = <BlobPart>[bytes.toJS].toJS;
  final blob = Blob(blobParts, BlobPropertyBag(type: 'text/plain;charset=utf-8'));
  final objectUrl = URL.createObjectURL(blob);

  final anchor = document.createElement('a') as HTMLAnchorElement
    ..href = objectUrl
    ..download = fileName
    ..style.display = 'none';

  document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(objectUrl);
}
