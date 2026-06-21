import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:point/Services/upload_errors.dart';
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

String _truncateBody(String body, {int maxLen = 500}) {
  if (body.length <= maxLen) return body;
  return '${body.substring(0, maxLen)}…';
}

UploadFailureException _signFailure({
  required String errorCode,
  int? httpStatus,
  String? message,
}) {
  return UploadFailureException(
    stage: UploadFailureStage.sign,
    errorCode: errorCode,
    httpStatus: httpStatus,
    message: message,
  );
}

Future<R2SignUploadResult> _requestR2SignUploadOnce({
  required String contentType,
  required String ext,
  String? friendlyDownloadName,
  required bool forceRefreshToken,
}) async {
  final base = AppConfig.r2SignerUrl.trim();
  if (base.isEmpty) {
    throw _signFailure(errorCode: 'r2_signer_not_configured');
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw _signFailure(errorCode: 'not_signed_in');
  }

  final token = await user.getIdToken(forceRefreshToken);
  if (token == null || token.isEmpty) {
    throw _signFailure(errorCode: 'missing_id_token');
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
    throw _signFailure(
      errorCode: 'sign_invalid_json',
      httpStatus: res.statusCode,
      message: _truncateBody(res.body),
    );
  }

  if (map['ok'] != true) {
    throw _signFailure(
      errorCode: map['error']?.toString() ?? 'r2_sign_failed',
      httpStatus: res.statusCode,
      message: _truncateBody(res.body),
    );
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
    throw _signFailure(
      errorCode: 'r2_sign_invalid_response',
      httpStatus: res.statusCode,
    );
  }

  return R2SignUploadResult(
    uploadUrl: uploadUrl,
    headers: headers,
    publicUrl: publicUrl,
    key: key,
  );
}

/// Calls the R2 presign worker with the current Firebase ID token.
///
/// Retries once with a forced token refresh when the worker returns
/// [invalid_token] (stale session).
Future<R2SignUploadResult> requestR2SignUpload({
  required String contentType,
  required String ext,
  String? friendlyDownloadName,
}) async {
  try {
    return await _requestR2SignUploadOnce(
      contentType: contentType,
      ext: ext,
      friendlyDownloadName: friendlyDownloadName,
      forceRefreshToken: false,
    );
  } on UploadFailureException catch (e) {
    if (e.errorCode != 'invalid_token') rethrow;
    return _requestR2SignUploadOnce(
      contentType: contentType,
      ext: ext,
      friendlyDownloadName: friendlyDownloadName,
      forceRefreshToken: true,
    );
  }
}
