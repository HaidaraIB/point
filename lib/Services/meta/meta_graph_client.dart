import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:point/Services/meta/meta_errors.dart';
import 'package:point/Utils/app_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static final Map<String, _MetaCachedResponse> _responseCache = {};
  static const Duration _defaultCacheTtl = Duration(minutes: 5);
  /// Matches upload_to_meta_bot graph_client list timeout (30s).
  static const Duration httpTimeout = Duration(seconds: 30);
  static final http.Client _httpClient = http.Client();

  String get _base => 'https://graph.facebook.com/${settings.graphVersion}';

  static void clearResponseCache() {
    _responseCache.clear();
  }

  /// GET [path] starting with `/`, e.g. `/me/accounts`.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    String? accessToken,
    Duration cacheTtl = _defaultCacheTtl,
    bool useCache = true,
  }) {
    return _request(
      'GET',
      path,
      query: query,
      accessToken: accessToken,
      cacheTtl: cacheTtl,
      useCache: useCache,
    );
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
    final resp = await _httpClient
        .post(
          uri,
          headers: {
            'Authorization': 'OAuth $accessToken',
            'offset': '0',
            'file_size': '${bytes.length}',
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        )
        .timeout(httpTimeout);
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
    Duration cacheTtl = _defaultCacheTtl,
    bool useCache = false,
  }) async {
    final token = accessToken ?? settings.accessToken;
    final q = <String, String>{'access_token': token, ...?query};
    final uri = Uri.parse('$_base${path.startsWith('/') ? path : '/$path'}')
        .replace(queryParameters: q);
    final shouldUseCache = method == 'GET' && useCache;
    final cacheKey = shouldUseCache ? '$method|$uri' : null;
    if (shouldUseCache && cacheKey != null) {
      final cached = _responseCache[cacheKey];
      if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
        appLog(
          'MetaGraph cache HIT ${uri.replace(queryParameters: {...q, 'access_token': '<redacted>'})}',
        );
        return Map<String, dynamic>.from(cached.body);
      }
      _responseCache.remove(cacheKey);
    }

    // Browsers block direct graph.facebook.com calls (CORS). Route through Supabase.
    if (kIsWeb && method == 'GET') {
      return _requestViaEdgeProxy(
        path: path.startsWith('/') ? path : '/$path',
        query: q,
        accessToken: token,
        cacheKey: shouldUseCache ? cacheKey : null,
        cacheTtl: cacheTtl,
      );
    }

    return _requestDirect(
      method: method,
      uri: uri,
      q: q,
      cacheKey: shouldUseCache ? cacheKey : null,
      cacheTtl: cacheTtl,
    );
  }

  Future<Map<String, dynamic>> _requestViaEdgeProxy({
    required String path,
    required Map<String, String> query,
    required String accessToken,
    String? cacheKey,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    appLog('MetaGraph proxy GET $path');
    final firebaseIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw MetaPublishUserError('meta_err_auth');
    }

    final proxyQuery = Map<String, String>.from(query)..remove('access_token');
    final started = DateTime.now();
    try {
      final res = await Supabase.instance.client.functions
          .invoke(
            'meta-graph',
            headers: <String, String>{
              'x-firebase-id-token': 'Bearer $firebaseIdToken',
            },
            body: <String, dynamic>{
              'graphVersion': settings.graphVersion,
              'path': path,
              'query': proxyQuery,
              'accessToken': accessToken,
            },
          )
          .timeout(httpTimeout);

      final data = res.data;
      if (res.status == 504 ||
          (data is Map && data['errorCode'] == 'ERR_GRAPH_TIMEOUT')) {
        throw MetaPublishUserError('meta_err_timeout');
      }
      if (res.status == 401 ||
          (data is Map && data['errorCode'] == 'ERR_MISSING_TOKEN')) {
        throw MetaPublishUserError('meta_err_auth');
      }
      if (res.status == 403 ||
          (data is Map &&
              (data['errorCode'] == 'ERR_FORBIDDEN' ||
                  data['errorCode'] == 'ERR_PATH_NOT_ALLOWED'))) {
        throw MetaPublishUserError('errors.forbidden');
      }
      if (data is! Map) {
        throw MetaPublishUserError('meta_err_graph', {'detail': '$data'});
      }

      final ok = data['ok'] == true;
      final status = data['status'];
      final body = data['body'];
      appLog(
        'MetaGraph proxy ${ok ? 'ok' : 'fail'} status=$status '
        'in ${DateTime.now().difference(started).inMilliseconds}ms',
      );

      if (!ok) {
        final detail = graphErrorDetail(body);
        throw MetaPublishUserError(
          graphErrorMessageKey(detail),
          {'detail': detail, 'status': status},
        );
      }
      if (body is! Map) {
        throw MetaPublishUserError('meta_err_graph', {'detail': '$body'});
      }
      final jsonBody = Map<String, dynamic>.from(body);
      if (cacheKey != null) {
        _responseCache[cacheKey] = _MetaCachedResponse(
          body: Map<String, dynamic>.from(jsonBody),
          expiresAt: DateTime.now().add(cacheTtl),
        );
      }
      return jsonBody;
    } on TimeoutException {
      appLog(
        'MetaGraph proxy timeout after ${DateTime.now().difference(started).inMilliseconds}ms path=$path',
      );
      throw MetaPublishUserError('meta_err_timeout');
    } on FunctionException catch (e) {
      appLog(
        'MetaGraph proxy FunctionException status=${e.status} details=${e.details}',
      );
      final parsed = _metaErrorFromProxyDetails(e.details, e.status);
      if (parsed != null) throw parsed;
      if (e.status == 504) {
        throw MetaPublishUserError('meta_err_timeout');
      }
      throw MetaPublishUserError(
        'meta_err_graph',
        {'detail': e.details?.toString() ?? e.toString(), 'status': e.status},
      );
    }
  }

  MetaPublishUserError? _metaErrorFromProxyDetails(Object? details, int? status) {
    if (details is! Map) return null;
    if (details['errorCode'] == 'ERR_GRAPH_TIMEOUT') {
      return MetaPublishUserError('meta_err_timeout');
    }
    if (details['errorCode'] == 'ERR_FORBIDDEN' ||
        details['errorCode'] == 'ERR_PATH_NOT_ALLOWED') {
      return MetaPublishUserError('errors.forbidden');
    }
    final body = details['body'];
    if (details['ok'] == false || (status != null && status >= 400)) {
      final detail = graphErrorDetail(body ?? details);
      return MetaPublishUserError(
        graphErrorMessageKey(detail),
        {'detail': detail, 'status': details['status'] ?? status},
      );
    }
    return null;
  }

  Future<Map<String, dynamic>> _requestDirect({
    required String method,
    required Uri uri,
    required Map<String, String> q,
    String? cacheKey,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    appLog('MetaGraph $method ${uri.replace(queryParameters: {...q, 'access_token': '<redacted>'})}');
    final started = DateTime.now();
    late final http.Response resp;
    try {
      resp = method == 'GET'
          ? await _httpClient.get(uri).timeout(httpTimeout)
          : await _httpClient.post(uri).timeout(httpTimeout);
    } on TimeoutException {
      appLog(
        'MetaGraph timeout after ${DateTime.now().difference(started).inMilliseconds}ms '
        '$method ${uri.replace(queryParameters: {...q, 'access_token': '<redacted>'})}',
      );
      throw MetaPublishUserError('meta_err_timeout');
    }
    appLog(
      'MetaGraph $method ${resp.statusCode} in ${DateTime.now().difference(started).inMilliseconds}ms',
    );
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
    if (cacheKey != null) {
      _responseCache[cacheKey] = _MetaCachedResponse(
        body: Map<String, dynamic>.from(jsonBody),
        expiresAt: DateTime.now().add(cacheTtl),
      );
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
      useCache: true,
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

class _MetaCachedResponse {
  const _MetaCachedResponse({required this.body, required this.expiresAt});

  final Map<String, dynamic> body;
  final DateTime expiresAt;
}
