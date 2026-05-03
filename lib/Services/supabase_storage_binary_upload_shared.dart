import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:mime/mime.dart' show lookupMimeType;
import 'package:point/Services/StorageKeys.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Same header injection as [AuthHttpClient.send]: [supabase.storage.headers]
/// alone does not include a fresh JWT; the SDK client adds it per request.
Future<Map<String, String>> resolveStorageUploadHeaders(
  SupabaseClient supabase,
) async {
  final merged = Map<String, String>.from(supabase.storage.headers);

  final access = await _sessionAccessTokenForStorage(supabase);
  final apiKey = _apiKeyForStorage(merged);

  final authBearer = access ?? apiKey;
  merged.putIfAbsent('Authorization', () => 'Bearer $authBearer');
  merged.putIfAbsent('apikey', () => apiKey);
  return merged;
}

Future<String?> _sessionAccessTokenForStorage(SupabaseClient supabase) async {
  if (supabase.accessToken != null) {
    return supabase.accessToken!();
  }
  try {
    final auth = supabase.auth;
    if (auth.currentSession?.isExpired ?? false) {
      try {
        await auth.refreshSession();
      } catch (_) {}
    }
    return auth.currentSession?.accessToken;
  } catch (_) {
    return null;
  }
}

String _apiKeyForStorage(Map<String, String> merged) {
  for (final e in merged.entries) {
    if (e.key.toLowerCase() == 'apikey') {
      return e.value;
    }
  }
  return StorageKeys.supabaseKey;
}

Uri storageObjectUri({
  required SupabaseClient supabase,
  required String bucketId,
  required String objectPath,
}) {
  final base = supabase.storage.url;
  final pathInBucket = objectPath.replaceAll(RegExp(r'^/+|/+$'), '');
  final finalPath = '$bucketId/$pathInBucket';
  return Uri.parse('$base/object/$finalPath');
}

String mimeLookupKey({required String objectPath, String? mimeLookupPath}) {
  if (mimeLookupPath != null && mimeLookupPath.trim().isNotEmpty) {
    return mimeLookupPath.trim();
  }
  return objectPath.replaceAll(RegExp(r'^/+|/+$'), '');
}

MediaType multipartContentType(FileOptions fileOptions, String mimeLookupPath) {
  if (fileOptions.contentType != null && fileOptions.contentType!.isNotEmpty) {
    return MediaType.parse(fileOptions.contentType!);
  }
  final mime = lookupMimeType(mimeLookupPath);
  if (mime != null && mime.isNotEmpty) {
    return MediaType.parse(mime);
  }
  return MediaType('application', 'octet-stream');
}

http.MultipartRequest buildMultipartRequestFromBytes({
  required Uri uri,
  required Map<String, String> headers,
  required Uint8List data,
  required FileOptions fileOptions,
  required MediaType contentType,
}) {
  final request = http.MultipartRequest('POST', uri)
    ..headers.addAll(headers)
    ..headers['x-upsert'] = fileOptions.upsert.toString()
    ..fields['cacheControl'] = fileOptions.cacheControl
    ..files.add(
      http.MultipartFile.fromBytes(
        '',
        data,
        filename: '',
        contentType: contentType,
      ),
    );
  if (fileOptions.metadata != null) {
    request.fields['metadata'] = json.encode(fileOptions.metadata);
  }
  if (fileOptions.headers != null) {
    request.headers.addAll(fileOptions.headers!);
  }
  return request;
}

String parseStorageUploadResponse(http.Response response) {
  final code = response.statusCode;
  if (code >= 200 && code <= 299) {
    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    return jsonBody['Key'] as String;
  }
  try {
    final errMap = json.decode(response.body) as Map<String, dynamic>;
    throw StorageException.fromJson(errMap, '$code');
  } on FormatException {
    throw StorageException(
      response.body.isEmpty ? response.reasonPhrase ?? '' : response.body,
      statusCode: '$code',
    );
  }
}
