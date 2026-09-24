import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/SentTranslationController.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// PopupMenuButton does not invoke [PopupMenuButton.onSelected] for `null` values.
const _sentTranslationOffMenuValue = '';

String _sentTranslationLabelFor(String? code) {
  switch (code) {
    case 'en':
      return AppLocaleKeys.chatTranslationEnglish.tr;
    case 'fa':
      return AppLocaleKeys.chatTranslationFarsi.tr;
    case 'ar':
      return AppLocaleKeys.chatTranslationArabic.tr;
    default:
      return AppLocaleKeys.chatSentTranslationOff.tr;
  }
}

List<PopupMenuEntry<String>> _sentTranslationMenuItems() {
  return [
    PopupMenuItem(
      value: _sentTranslationOffMenuValue,
      child: Text(AppLocaleKeys.chatSentTranslationOff.tr),
    ),
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

/// Compact strip above the chat composer for outgoing live translation.
class ChatComposerSentTranslationBar extends StatelessWidget {
  const ChatComposerSentTranslationBar({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(0, 0, 0, 6),
    this.onTargetChanged,
  });

  final EdgeInsetsGeometry padding;
  final VoidCallback? onTargetChanged;

  @override
  Widget build(BuildContext context) {
    final stc = Get.find<SentTranslationController>();
    final theme = context.appTheme;

    return Obx(() {
      final current = stc.targetOrNull;
      return Padding(
        padding: padding,
        child: Material(
          color: theme.panelTint,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Row(
              children: [
                Icon(Icons.g_translate, size: 17, color: theme.accentText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocaleKeys.chatSentTranslationPreference.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.primaryText,
                    ),
                  ),
                ),
                Text(
                  _sentTranslationLabelFor(current),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.accentText,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: AppLocaleKeys.chatSentTranslationPreference.tr,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  color: theme.elevatedSurface,
                  surfaceTintColor: Colors.transparent,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: theme.accentText,
                    size: 20,
                  ),
                  onSelected: (code) async {
                    final target = code == _sentTranslationOffMenuValue
                        ? null
                        : code;
                    await stc.changeTarget(target);
                    onTargetChanged?.call();
                  },
                  itemBuilder: (context) => _sentTranslationMenuItems(),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
