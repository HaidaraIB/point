import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:point/config/app_config.dart';

/// Response from [POST /sign-upload] on the Cloudflare Worker.
class R2SignUploadResult {
  R2SignUploadResult({
    required this.uploadUrl,
    required this.headers,
    required this.publicUrl,
    required this.key,
  });

  final String uploadUrl;
  final Map<String, String> headers;
  final String publicUrl;
  final String key;
}

/// Calls the R2 presign worker with the current Firebase ID token.
Future<R2SignUploadResult> requestR2SignUpload({
  required String contentType,
  required String ext,
  String? friendlyDownloadName,
}) async {
  final base = AppConfig.r2SignerUrl.trim();
  if (base.isEmpty) {
    throw StateError('R2_SIGNER_URL not configured');
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('Not signed in');
  }
  final token = await user.getIdToken();
  if (token == null || token.isEmpty) {
    throw StateError('Missing Firebase ID token');
  }

  final uri = Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}/sign-upload');
  final res = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'contentType': contentType,
      'ext': ext,
      if (friendlyDownloadName != null && friendlyDownloadName.trim().isNotEmpty)
        'friendlyDownloadName': friendlyDownloadName.trim(),
    }),
  );

  Map<String, dynamic> map;
  try {
    map = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    throw StateError('R2 sign failed: HTTP ${res.statusCode}');
  }

  if (map['ok'] != true) {
    throw StateError(map['error']?.toString() ?? 'r2_sign_failed');
  }

  final headers = <String, String>{};
  final raw = map['headers'];
  if (raw is Map) {
    raw.forEach((dynamic k, dynamic v) {
      if (k != null && v != null) {
        headers[k.toString()] = v.toString();
      }
    });
  }

  final uploadUrl = map['uploadUrl'] as String?;
  final publicUrl = map['publicUrl'] as String?;
  final key = map['key'] as String?;
  if (uploadUrl == null ||
      uploadUrl.isEmpty ||
      publicUrl == null ||
      publicUrl.isEmpty ||
      key == null ||
      key.isEmpty) {
    throw StateError('r2_sign_invalid_response');
  }

  return R2SignUploadResult(
    uploadUrl: uploadUrl,
    headers: headers,
    publicUrl: publicUrl,
    key: key,
  );
}
