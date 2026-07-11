import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Shared/app_theme_menu_button.dart';

Widget buildRightsSection(BuildContext context) {
  final appTheme = context.appTheme;
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppLocaleKeys.authFooterCopyright.trParams({
              'year': '${DateTime.now().year}',
            }),
            style: TextStyle(fontSize: 12, color: appTheme.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Obx(() {
            final lc = Get.find<LanguageController>();
            final code = lc.currentLocale.value.languageCode;
            final activeColor = appTheme.accentText;
            final inactiveColor = appTheme.mutedText;
            return Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: code == 'ar' ? activeColor : inactiveColor,
                    textStyle: TextStyle(
                      fontWeight:
                          code == 'ar' ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () => lc.changeLanguage('ar'),
                  child: Text(AppLocaleKeys.appLanguageArabic.tr),
                ),
                Text(
                  '|',
                  style: TextStyle(fontSize: 12, color: appTheme.border),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: code == 'en' ? activeColor : inactiveColor,
                    textStyle: TextStyle(
                      fontWeight:
                          code == 'en' ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () => lc.changeLanguage('en'),
                  child: Text(AppLocaleKeys.appLanguageEnglish.tr),
                ),
              ],
            );
          }),
          const SizedBox(height: 8),
          const AppThemeMenuButton(compact: true),
        ],
      ),
    ),
  );
}
