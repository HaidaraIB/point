import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_storage_binary_upload_io.dart'
    if (dart.library.html) 'supabase_storage_binary_upload_web.dart' as impl;

/// Same REST contract as [StorageFileApi.uploadBinary], with upload progress
/// that reflects bytes on the wire (IO: chunked multipart stream; web:
/// [XMLHttpRequest.upload] progress — the stock [http] browser client buffers
/// the full body before send, so it is not used on web).
Future<String> uploadStorageObjectBinary({
  required SupabaseClient supabase,
  required String bucketId,
  required String objectPath,
  required Uint8List data,
  FileOptions fileOptions = const FileOptions(),
  void Function(int sent, int total)? onProgress,
  int retryAttempts = 0,
  StorageRetryController? retryController,
  String? mimeLookupPath,
}) =>
    impl.uploadStorageObjectBinary(
      supabase: supabase,
      bucketId: bucketId,
      objectPath: objectPath,
      data: data,
      fileOptions: fileOptions,
      onProgress: onProgress,
      retryAttempts: retryAttempts,
      retryController: retryController,
      mimeLookupPath: mimeLookupPath,
    );
