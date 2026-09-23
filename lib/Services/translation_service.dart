import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Utils/EdgeFunctionRateLimiter.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/Utils/translation_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _functionName = 'translate';

class ChatTranslationResult {
  const ChatTranslationResult({
    required this.translations,
    required this.sourceHash,
    this.source = 'gemini',
  });

  final Map<String, String> translations;
  final String sourceHash;
  final String source;
}

class TaskTranslationResult {
  const TaskTranslationResult({
    required this.titleTranslations,
    required this.descriptionTranslations,
    required this.titleSourceHash,
    required this.descriptionSourceHash,
  });

  final Map<String, String> titleTranslations;
  final Map<String, String> descriptionTranslations;
  final String titleSourceHash;
  final String descriptionSourceHash;
}

class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  Future<ChatTranslationResult?> translateChatMessage(String text) async {
    if (shouldSkipTranslation(text)) return null;
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'translate-chat',
          'text': text.trim(),
        },
      );
      return _parseChatResult(data, text);
    } catch (e, st) {
      appLog('TranslationService.translateChatMessage failed: $e\n$st');
      return null;
    }
  }

  Future<TaskTranslationResult?> translateTaskFields({
    required String title,
    required String description,
  }) async {
    final titleTrim = title.trim();
    final descTrim = description.trim();
    if (titleTrim.isEmpty && descTrim.isEmpty) return null;
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'translate-task',
          if (titleTrim.isNotEmpty) 'title': titleTrim,
          if (descTrim.isNotEmpty) 'description': descTrim,
        },
      );
      return _parseTaskResult(data, titleTrim, descTrim);
    } catch (e, st) {
      appLog('TranslationService.translateTaskFields failed: $e\n$st');
      return null;
    }
  }

  ChatTranslationResult? _parseChatResult(dynamic data, String sourceText) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) return null;
    final translations = parseTranslationMap(map['translations']);
    if (translations.isEmpty) return null;
    final hash = map['sourceHash']?.toString().trim();
    return ChatTranslationResult(
      translations: translations,
      sourceHash: (hash != null && hash.isNotEmpty)
          ? hash
          : translationTextHash(sourceText),
      source: map['source']?.toString() ?? 'gemini',
    );
  }

  TaskTranslationResult? _parseTaskResult(
    dynamic data,
    String title,
    String description,
  ) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) return null;

    final titleTranslations = parseTranslationMap(map['titleTranslations']);
    final descriptionTranslations =
        parseTranslationMap(map['descriptionTranslations']);

    final titleHash = map['titleSourceHash']?.toString().trim();
    final descHash = map['descriptionSourceHash']?.toString().trim();

    return TaskTranslationResult(
      titleTranslations: titleTranslations,
      descriptionTranslations: descriptionTranslations,
      titleSourceHash: title.isNotEmpty
          ? ((titleHash != null && titleHash.isNotEmpty)
              ? titleHash
              : translationTextHash(title))
          : '',
      descriptionSourceHash: description.isNotEmpty
          ? ((descHash != null && descHash.isNotEmpty)
              ? descHash
              : translationTextHash(description))
          : '',
    );
  }

  Future<dynamic> _invokeRaw({required Map<String, dynamic> body}) async {
    final firebaseIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw StateError('Not authenticated');
    }

    final res = await EdgeFunctionRateLimiter.instance.run(() {
      return Supabase.instance.client.functions.invoke(
        _functionName,
        headers: <String, String>{
          'x-firebase-id-token': 'Bearer $firebaseIdToken',
        },
        body: body,
      );
    });

    final data = res.data;
    if (res.status == 429 ||
        (data is Map && data['errorCode'] == 'ERR_RATE_LIMITED')) {
      throw StateError('Rate limited');
    }
    if (res.status == 403 ||
        (data is Map && data['errorCode'] == 'ERR_FORBIDDEN')) {
      throw StateError('Forbidden');
    }

    return data;
  }
}
