import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Upload-friendly picked file shape (file_picker 12+ no longer exposes [PlatformFile.bytes]).
class PickedPlatformFile {
  const PickedPlatformFile({
    required this.name,
    required this.bytes,
    this.path,
    this.size,
  });

  final String name;
  final Uint8List bytes;
  final String? path;
  final int? size;

  static Future<PickedPlatformFile> fromPlatformFile(PlatformFile file) async {
    final data = await file.readAsBytes();
    return PickedPlatformFile(
      name: file.name,
      bytes: data,
      path: file.path,
      size: data.lengthInBytes,
    );
  }

  static Future<List<PickedPlatformFile>> fromPlatformFiles(
    List<PlatformFile> files,
  ) async {
    if (files.isEmpty) return const [];
    return Future.wait(files.map(fromPlatformFile));
  }

  static Future<List<PickedPlatformFile>> fromOptionalPlatformFile(
    PlatformFile? file,
  ) async {
    if (file == null) return const [];
    return [await fromPlatformFile(file)];
  }
}
