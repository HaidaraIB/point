import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/ContentLanguageController.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Chat translation preference menu — mirrors [AppThemeMenuButton] layout.
class ChatTranslationLanguageMenu extends StatelessWidget {
  const ChatTranslationLanguageMenu({
    super.key,
    this.iconColor,
    this.compact = false,
    this.onDarkSurface = false,
  });

  final Color? iconColor;
  final bool compact;
  final bool onDarkSurface;

  String _labelFor(String? code) {
    switch (code) {
      case 'en':
        return AppLocaleKeys.chatTranslationEnglish.tr;
      case 'fa':
        return AppLocaleKeys.chatTranslationFarsi.tr;
      case 'ar':
        return AppLocaleKeys.chatTranslationArabic.tr;
      default:
        return AppLocaleKeys.chatTranslationPickTitle.tr;
    }
  }

  List<PopupMenuEntry<String>> _buildItems() {
    return [
      PopupMenuItem(
        value: 'ar',
        child: Text(AppLocaleKeys.chatTranslationArabic.tr),
      ),
      PopupMenuItem(
        value: 'en',
        child: Text(AppLocaleKeys.chatTranslationEnglish.tr),
      ),
      PopupMenuItem(
        value: 'fa',
        child: Text(AppLocaleKeys.chatTranslationFarsi.tr),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final clc = Get.find<ContentLanguageController>();
    final resolvedIconColor = iconColor ??
        (onDarkSurface ? Colors.white : context.appTheme.accentText);

    if (compact) {
      return Obx(() {
        clc.contentLanguage.value;
        return PopupMenuButton<String>(
          tooltip: AppLocaleKeys.chatTranslationPreference.tr,
          padding: EdgeInsets.zero,
          color: context.appTheme.elevatedSurface,
          surfaceTintColor: Colors.transparent,
          icon: Icon(Icons.translate, color: resolvedIconColor, size: 22),
          onSelected: clc.changeContentLanguage,
          itemBuilder: (context) => _buildItems(),
        );
      });
    }

    return Obx(() {
      final current = clc.codeOrNull;
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: onDarkSurface ? 4 : 8,
        ),
        child: Row(
          children: [
            Icon(Icons.translate, color: resolvedIconColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocaleKeys.chatTranslationPreference.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: resolvedIconColor,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              _labelFor(current),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: resolvedIconColor.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              color: context.appTheme.elevatedSurface,
              surfaceTintColor: Colors.transparent,
              icon: Icon(Icons.arrow_drop_down, color: resolvedIconColor),
              onSelected: clc.changeContentLanguage,
              itemBuilder: (context) => _buildItems(),
            ),
          ],
        ),
      );
    });
  }
}
