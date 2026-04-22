import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:point/Services/meta/meta_errors.dart';
import 'package:point/Utils/app_log.dart';

/// Global Meta app credentials in Firestore: `app_settings/meta`.
class MetaAppSettings {
  const MetaAppSettings({
    required this.accessToken,
    this.graphVersion = 'v25.0',
  });

  final String accessToken;
  final String graphVersion;

  static const String collection = 'app_settings';
  static const String documentId = 'meta';

  static Future<MetaAppSettings?> load() async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .doc(documentId)
        .get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    final token = (data['accessToken'] as String?)?.trim() ?? '';
    if (token.isEmpty) return null;
    final ver = (data['graphVersion'] as String?)?.trim();
    return MetaAppSettings(
      accessToken: token,
      graphVersion: (ver != null && ver.isNotEmpty) ? ver : 'v25.0',
    );
  }

  static Future<void> save({
    required String accessToken,
    String graphVersion = 'v25.0',
  }) async {
    await FirebaseFirestore.instance.collection(collection).doc(documentId).set(
      {
        'accessToken': accessToken.trim(),
        'graphVersion': graphVersion.trim().isEmpty ? 'v25.0' : graphVersion.trim(),
      },
      SetOptions(merge: true),
    );
  }
}

/// Facebook Page + optional Instagram Business account (from `/me/accounts`).
class MetaBusinessAsset {
  const MetaBusinessAsset({
    required this.pageId,
    required this.pageName,
    required this.pageAccessToken,
    this.instagramUserId,
    this.instagramUserName,
    required this.label,
  });

  final String pageId;
  final String pageName;
  final String pageAccessToken;
  final String? instagramUserId;
  final String? instagramUserName;
  final String label;

  factory MetaBusinessAsset.fromGraphPage(Map<String, dynamic> p) {
    final ig = p['instagram_business_account'];
    Map<String, dynamic>? igMap;
    if (ig is Map<String, dynamic>) {
      igMap = ig;
    }
    final igId = igMap?['id']?.toString();
    final igUser = igMap?['username']?.toString();
    final name = p['name']?.toString() ?? '';
    final pageId = p['id']?.toString() ?? '';
    var label = name;
    if (igUser != null && igUser.isNotEmpty) {
      label = '$name / IG: $igUser';
    }
    return MetaBusinessAsset(
      pageId: pageId,
      pageName: name,
      pageAccessToken: p['access_token']?.toString() ?? '',
      instagramUserId: igId,
      instagramUserName: igUser,
      label: label,
    );
  }
}

class MetaGraphClient {
  MetaGraphClient(this.settings);

  final MetaAppSettings settings;

  String get _base => 'https://graph.facebook.com/${settings.graphVersion}';

  /// GET [path] starting with `/`, e.g. `/me/accounts`.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) {
    return _request('GET', path, query: query, accessToken: accessToken);
  }

  /// POST application/x-www-form-urlencoded (default Graph style).
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) {
    return _request('POST', path, query: query, accessToken: accessToken);
  }

  /// Caller must set [request.url] to full Graph URL including `access_token` query param.
  Future<Map<String, dynamic>> sendMultipartRequest(http.MultipartRequest request) async {
    final streamed = await request.send();
    final bodyStr = await streamed.stream.bytesToString();
    Map<String, dynamic>? jsonBody;
    try {
      jsonBody = jsonDecode(bodyStr) as Map<String, dynamic>?;
    } catch (_) {
      jsonBody = null;
    }
    if (streamed.statusCode >= 400) {
      final detail = graphErrorDetail(jsonBody ?? bodyStr);
      throw MetaPublishUserError(
        graphErrorMessageKey(detail),
        {'detail': detail, 'status': streamed.statusCode},
      );
    }
    if (jsonBody == null) {
      throw MetaPublishUserError('meta_err_graph', {'detail': bodyStr});
    }
    return jsonBody;
  }

  Future<Map<String, dynamic>> postBytes(
    String url, {
    required List<int> bytes,
    required String accessToken,
  }) async {
    final uri = Uri.parse(url);
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'OAuth $accessToken',
        'offset': '0',
        'file_size': '${bytes.length}',
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );
    if (resp.statusCode >= 400) {
      final d = resp.body.length > 400 ? resp.body.substring(0, 400) : resp.body;
      throw MetaPublishUserError(
        'meta_err_upload',
        {'status': resp.statusCode, 'detail': d},
      );
    }
    try {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    final token = accessToken ?? settings.accessToken;
    final q = <String, String>{'access_token': token, ...?query};
    final uri = Uri.parse('$_base${path.startsWith('/') ? path : '/$path'}')
        .replace(queryParameters: q);
    appLog('MetaGraph $method ${uri.replace(queryParameters: {...q, 'access_token': '<redacted>'})}');
    // Graph accepts POST params on query string (matches python-telegram-bot aiohttp usage).
    final resp = method == 'GET' ? await http.get(uri) : await http.post(uri);
    Map<String, dynamic>? jsonBody;
    try {
      jsonBody = jsonDecode(resp.body) as Map<String, dynamic>?;
    } catch (_) {
      jsonBody = null;
    }
    if (resp.statusCode >= 400) {
      final detail = graphErrorDetail(jsonBody ?? resp.body);
      throw MetaPublishUserError(
        graphErrorMessageKey(detail),
        {'detail': detail, 'status': resp.statusCode},
      );
    }
    if (jsonBody == null) {
      throw MetaPublishUserError('meta_err_graph', {'detail': resp.body});
    }
    return jsonBody;
  }

  static Future<List<MetaBusinessAsset>> listBusinessAssets(
    MetaAppSettings settings,
  ) async {
    final client = MetaGraphClient(settings);
    final body = await client.get(
      '/me/accounts',
      query: {
        'fields': 'id,name,access_token,instagram_business_account{id,username}',
      },
    );
    final data = body['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => MetaBusinessAsset.fromGraphPage(Map<String, dynamic>.from(e)))
        .where((a) => a.pageId.isNotEmpty && a.pageAccessToken.isNotEmpty)
        .toList();
  }
}
