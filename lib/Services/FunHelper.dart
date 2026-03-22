import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/AppTranslations.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How to resolve a stored/raw value to a translation key (legacy DB text vs keys).
enum StoredValueKind {
  generic,
  contentType,
  taskStatus,
  promotion,
  priority,
  platform,
}

class FunHelper {
  static final Map<String, String> _legacyPriorityToKey = {
    'normal': 'normal',
    'important': 'imp',
    'very important': 'veryimp',
    'veryimportant': 'veryimp',
    'urgent': 'veryveryimp',
  };

  static final Map<String, String> _legacyPromotionToKey = {
    'under promotion': 'under_promotion',
    'not promoted': 'no_promotion',
    'promotion ended': 'end_promotion',
  };

  static final Map<String, String> _legacyStatusToKey = {
    'under review': StorageKeys.status_under_revision,
    'in progress': StorageKeys.status_processing,
    'ready to publish': StorageKeys.status_ready_to_publish,
    'approved': StorageKeys.status_approved,
    'scheduled': StorageKeys.status_scheduled,
    'published': StorageKeys.status_published,
    'rejected': StorageKeys.status_rejected,
    'in edit': StorageKeys.status_in_edit,
    'not started yet': StorageKeys.status_not_start_yet,
    'not started': StorageKeys.status_not_start_yet,
    'edit requested': StorageKeys.status_edit_requested,
  };

  static final Map<String, String> _legacyContentTypeToKey = {
    'image': 'content_image',
    'video': 'content_video',
    'reel': 'content_reel',
    'story': 'content_story',
    'sponsored ad': 'content_ads',
    'article': 'content_article',
    'text post': 'content_text',
    'graphic design': 'content_graphic',
    'podcast': 'content_podcast',
    'live': 'content_live',
  };

  static final Map<String, String> _legacyPlatformToKey = {
    'facebook': 'platform_facebook',
    'instagram': 'platform_instagram',
    'messenger': 'platform_messenger',
    'whatsapp': 'platform_whatsapp',
    'twitter': 'platform_twitter',
    'linkedin': 'platform_linkedin',
    'youtube': 'platform_youtube',
    'tiktok': 'platform_tiktok',
    'snapchat': 'platform_snapchat',
    'pinterest': 'platform_pinterest',
    'telegram': 'platform_telegram',
    'threads': 'platform_threads',
    'meta ads': 'platform_meta_ads',
    'google ads': 'platform_google_ads',
  };

  static String _appLanguageCode() {
    try {
      if (Get.isRegistered<LanguageController>()) {
        return Get.find<LanguageController>().currentLocale.value.languageCode;
      }
    } catch (_) {}
    return Get.locale?.languageCode ?? 'ar';
  }

  static bool _isArabicAppLanguage() => _appLanguageCode() == 'ar';

  /// Looks up [key] in the static translation map for the **app** language (not only Get.locale).
  static String? _translationForAppLanguage(String key) {
    final code = _appLanguageCode();
    final maps = AppTranslations().keys;
    final v = maps[code]?[key];
    if (v != null) return v;
    return maps['ar']?[key] ?? maps['en']?[key];
  }

  /// Public: translate a translation [key] using app language (sidebar / Get.locale sync).
  static String translateAppKey(String key) {
    return _translationForAppLanguage(key) ?? key.tr;
  }

  /// Localize known placeholder client/role strings (e.g. "from mobile").
  static String localizeUiPhrase(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return t;
    return t;
  }

  /// Normalizes raw priority (e.g. English labels) to canonical keys for switches/colors.
  static String canonicalStoredPriority(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return t;
    if (StorageKeys.priority.contains(t)) return t;
    final byLegacy = _legacyPriorityToKey[t.toLowerCase()];
    if (byLegacy != null) return byLegacy;
    return t;
  }

  /// Normalizes raw status to canonical [StorageKeys.status_*] when possible.
  static String canonicalStoredStatus(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return t;
    if (StorageKeys.statusList.contains(t)) return t;
    final byLegacy = _legacyStatusToKey[t.toLowerCase()];
    if (byLegacy != null) return byLegacy;
    return t;
  }

  /// Normalizes promotion field to canonical keys in [StorageKeys.promations].
  static String? canonicalStoredPromotion(String? raw) {
    if (raw == null || raw.trim().isEmpty) return raw;
    final t = raw.trim();
    if (StorageKeys.promations.contains(t)) return t;
    final byLegacy = _legacyPromotionToKey[t.toLowerCase()];
    if (byLegacy != null) return byLegacy;
    return t;
  }

  static String _slugifyForKey(String s) {
    final trimmed = s.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(s)) return '';
    return trimmed
        .replaceAll(RegExp(r'[\[\]]'), '')
        .replaceAll(RegExp(r'[-\s]+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  static Iterable<String> _candidatesForStored(
    String t,
    StoredValueKind kind,
  ) sync* {
    yield t;
    final lower = t.toLowerCase();
    if (lower != t) yield lower;

    switch (kind) {
      case StoredValueKind.contentType:
        final m = _legacyContentTypeToKey[lower];
        if (m != null) yield m;
        break;
      case StoredValueKind.taskStatus:
        final m = _legacyStatusToKey[lower];
        if (m != null) yield m;
        break;
      case StoredValueKind.promotion:
        final m = _legacyPromotionToKey[lower];
        if (m != null) yield m;
        break;
      case StoredValueKind.priority:
        final m = _legacyPriorityToKey[lower];
        if (m != null) yield m;
        break;
      case StoredValueKind.platform:
        final m = _legacyPlatformToKey[lower];
        if (m != null) yield m;
        break;
      case StoredValueKind.generic:
        break;
    }

    final slug = _slugifyForKey(t);
    if (slug.isNotEmpty) {
      yield slug;
    }
  }

  /// Translate values saved as English text, legacy labels, or real keys.
  static String trStored(
    String? raw, {
    StoredValueKind kind = StoredValueKind.generic,
  }) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return t;
    for (final c in _candidatesForStored(t, kind)) {
      if (c.isEmpty) continue;
      final fromApp = _translationForAppLanguage(c);
      if (fromApp != null && fromApp != c) return fromApp;
      final out = c.tr;
      if (out != c) return out;
    }
    return t;
  }

  /// Format a platform field (List or single value) for display.
  static String formatStoredPlatforms(dynamic platform) {
    if (platform == null) return '';
    if (platform is List) {
      if (platform.isEmpty) return '';
      return platform
          .map((e) => trStored(e.toString(), kind: StoredValueKind.platform))
          .join('، ');
    }
    return trStored(platform.toString(), kind: StoredValueKind.platform);
  }

  static errorsnackbar(error) {
    final messageKey = mapErrorToKey(error);
    return FunHelper.showsnackbar(
      AppLocaleKeys.errorTitle.tr,
      messageKey.tr,
      backgroundColor: Colors.red,

      colorText: Colors.white,
    );
  }

  static succssessnackbar(Succsses) {
    return FunHelper.showsnackbar(
      AppLocaleKeys.successTitle.tr,
      Succsses?.toString().isNotEmpty == true
          ? Succsses.toString()
          : AppLocaleKeys.successGeneric.tr,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  static String mapErrorToKey(Object? error) {
    final raw = (error ?? '').toString().toLowerCase();
    if (raw.contains('method not allowed'))
      return AppLocaleKeys.errorsMethodNotAllowed;
    if (raw.contains('unauthorized')) return AppLocaleKeys.errorsUnauthorized;
    if (raw.contains('forbidden')) return AppLocaleKeys.errorsForbidden;
    if (raw.contains('missing authorization') || raw.contains('token')) {
      return AppLocaleKeys.errorsMissingToken;
    }
    if (raw.contains('required') ||
        raw.contains('invalid') ||
        raw.contains('malformed')) {
      return AppLocaleKeys.errorsInvalidData;
    }
    return AppLocaleKeys.errorGeneric;
  }

  static Future<String> imageToBase64(String assetPath) async {
    ByteData bytes = await rootBundle.load(assetPath);
    Uint8List byteList = bytes.buffer.asUint8List();
    return base64Encode(byteList);
  }

  static animatedNavigate(Widget page, {Function()? thenMehode}) {
    Get.to(
      () => page,
      transition: Transition.fadeIn,
      duration: Duration(milliseconds: 500),
    )?.then((v) {
      if (thenMehode != null) thenMehode();
    });
  }

  static String? formatdate(DateTime? date) {
    try {
      if (date == null) return null;
      final useAr = _isArabicAppLanguage();
      final loc =
          useAr ? const Locale('ar') : (Get.locale ?? const Locale('en'));
      final localeName =
          loc.countryCode != null && loc.countryCode!.isNotEmpty
              ? '${loc.languageCode}_${loc.countryCode}'
              : loc.languageCode;
      final pattern = useAr ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy hh:mm a';
      return DateFormat(pattern, localeName).format(date.toLocal());
    } catch (e) {
      return null;
    }
  }

  static String? formatdateTime(DateTime? date) {
    try {
      if (date == null) return null;
      final useAr = _isArabicAppLanguage();
      final loc =
          useAr ? const Locale('ar') : (Get.locale ?? const Locale('en'));
      final localeName =
          loc.countryCode != null && loc.countryCode!.isNotEmpty
              ? '${loc.languageCode}_${loc.countryCode}'
              : loc.languageCode;
      final pattern = useAr ? 'yyyy-MM-dd HH:mm' : 'yyyy-MM-dd hh:mm a';
      return DateFormat(pattern, localeName).format(date.toLocal());
    } catch (e) {
      return null;
    }
  }

  static Color hexToColor(String hexCode) {
    hexCode = hexCode.replaceAll("#", "");
    if (hexCode.length == 6) {
      hexCode = "FF" + hexCode;
    }
    return Color(int.parse("0x$hexCode"));
  }

  static showConfirmDailog(
    BuildContext context, {
    required FutureOr<void> Function() onTap,
    String? title,
    String? message,
    String? confirmText,
    Color? confirmColor,
    String? cancelText,
    Color cancelColor = const Color(0xFF7A8194),
  }) async {
    final resolvedTitle = title ?? AppLocaleKeys.funConfirmTitle.tr;
    final resolvedMessage = message ?? AppLocaleKeys.funConfirmMessage.tr;
    final resolvedConfirm = confirmText ?? AppLocaleKeys.commonConfirm.tr;
    final dialogWidth = Get.width > 900 ? 420.0 : Get.width * 0.82;
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            contentPadding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
            actionsPadding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            actionsAlignment: MainAxisAlignment.center,
            actionsOverflowAlignment: OverflowBarAlignment.center,
            actionsOverflowDirection: VerticalDirection.down,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            content: SizedBox(
              width: dialogWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    resolvedTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resolvedMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),

            actions: [
              MainButton(
                icon: false,
                title: cancelText ?? 'cancel'.tr,
                fontcolor: Colors.white,
                backgroundcolor: cancelColor,
                width: 126,
                bordersize: 5,
                height: 38,
                onpress: () {
                  Get.back();
                },
              ),
              const SizedBox(width: 10),
              MainButton(
                icon: false,
                title: resolvedConfirm,
                fontcolor: Colors.white,
                backgroundcolor: confirmColor ?? AppColors.primary,
                width: 126,
                bordersize: 5,
                height: 38,
                onpress: () async {
                  await Future.sync(onTap);
                  Get.back();
                },
              ),
            ],
          ),
    );
  }

  static String getFileNameFromUrl(String url) {
    Uri uri = Uri.parse(url);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
  }

  String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return AppLocaleKeys.commonNow.tr;
    } else if (diff.inMinutes < 60) {
      return AppLocaleKeys.commonMinutesAgo.trParams({
        'count': '${diff.inMinutes}',
      });
    } else if (diff.inHours < 24) {
      return AppLocaleKeys.commonHoursAgo.trParams({
        'count': '${diff.inHours}',
      });
    } else {
      // لو أكتر من يوم → نعرض التاريخ والوقت
      final formatter = DateFormat('dd/MM/yyyy HH:mm');
      return formatter.format(dateTime);
    }
  }

  static showsnackbar(
    String? title,
    String? subtitle, {
    snackPosition = SnackPosition.TOP,
    backgroundColor = Colors.red,
    colorText = Colors.white,
  }) {
    ScaffoldMessenger.of(Get.context!).showMaterialBanner(
      MaterialBanner(
        backgroundColor: backgroundColor,
        content: Text(
          '$title: $subtitle',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(Get.context!).hideCurrentMaterialBanner();
            },
            child: Text(
              AppLocaleKeys.appClose.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  static savelogindata(email) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    await pref.setBool('isLoggedIn', true);
    await pref.setString('email', email);
  }

  static removelogindata() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    await pref.remove('isLoggedIn');
    await pref.remove('email');
  }

  /// الوقت المتبقي حتى موعد التسليم (نص مترجم). يطابق سلوك بطاقة المهام السابقة.
  static String taskTimeUntilDeadline(DateTime endDate) {
    final now = DateTime.now();
    final difference = endDate.difference(now);
    if (difference.isNegative) {
      return 'tasks.deadline_expired'.tr;
    }
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final parts = <String>[];
    if (days > 0) {
      parts.add('tasks.time_days'.trParams({'count': '$days'}));
    }
    if (hours > 0) {
      parts.add('tasks.time_hours'.trParams({'count': '$hours'}));
    }
    if (minutes > 0) {
      parts.add('tasks.time_minutes'.trParams({'count': '$minutes'}));
    }
    if (parts.isEmpty) {
      return 'tasks.time_minutes'.trParams({'count': '1'});
    }
    return parts.join(' ');
  }
}

class TopToast {
  static void show({
    required String title,
    required String subtitle,
    Color backgroundColor = Colors.red,
    Duration duration = const Duration(seconds: 3),
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder:
          (_) => Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$title\n$subtitle',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    overlay.insert(entry);

    Future.delayed(duration, () {
      entry.remove();
    });
  }
}
