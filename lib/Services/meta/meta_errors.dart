import 'dart:async';

import 'package:get/get.dart';

/// User-facing Meta / Graph API errors (message keys in [AppTranslations]).
class MetaPublishUserError implements Exception {
  MetaPublishUserError(this.messageKey, [this.formatArgs = const {}]);

  final String messageKey;
  final Map<String, Object?> formatArgs;

  @override
  String toString() => 'MetaPublishUserError($messageKey, $formatArgs)';
}

String graphErrorDetail(dynamic body, {int maxLen = 400}) {
  if (body is Map) {
    final err = body['error'];
    if (err is Map) {
      final msg = err['message'];
      if (msg != null) {
        final m = msg.toString();
        return m.length > maxLen ? m.substring(0, maxLen) : m;
      }
    }
    final s = body.toString();
    return s.length > maxLen ? s.substring(0, maxLen) : s;
  }
  if (body == null) return '';
  final s = body.toString();
  return s.length > maxLen ? s.substring(0, maxLen) : s;
}

String graphErrorMessageKey(String detail) {
  if (detail.isEmpty) return 'meta_err_graph';
  final dl = detail.toLowerCase();
  if (dl.contains('log in to www.facebook.com') ||
      dl.contains('checkpoint') ||
      dl.contains('follow the instructions given')) {
    return 'meta_err_token_checkpoint';
  }
  if (dl.contains('session has expired') ||
      dl.contains('error validating access token') ||
      dl.contains('invalid oauth')) {
    return 'meta_err_token_expired';
  }
  if (dl.contains('pages_manage_posts') &&
      (dl.contains('not available') ||
          dl.contains('app review') ||
          dl.contains('deprecated'))) {
    return 'meta_err_pages_manage_posts';
  }
  if (dl.contains('scheduled publish time is invalid')) {
    return 'meta_err_meta_schedule_time_invalid';
  }
  return 'meta_err_graph';
}

/// Uses GetX [tr] / [trParams] for the current app locale.
String formatMetaPublishFailure(Object exc, [String _unusedLang = 'ar']) {
  if (exc is TimeoutException) {
    try {
      return 'meta_err_timeout'.tr;
    } catch (_) {
      return 'Meta Graph request timed out.';
    }
  }
  if (exc is MetaPublishUserError) {
    final args = {
      for (final e in exc.formatArgs.entries)
        e.key: e.value?.toString() ?? '',
    };
    try {
      if (args.isEmpty) return exc.messageKey.tr;
      return exc.messageKey.trParams(args);
    } catch (_) {
      return '${exc.messageKey}: ${args.values.join(' ')}';
    }
  }
  try {
    return 'publish.unexpected_error'.trParams({'err': exc.toString()});
  } catch (_) {
    return exc.toString();
  }
}
