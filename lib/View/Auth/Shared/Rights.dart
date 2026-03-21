import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/LanguageController.dart';

Widget buildRightsSection() {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 20, horizontal: 15),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppLocaleKeys.authFooterCopyright.tr,
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Obx(() {
            final lc = Get.find<LanguageController>();
            final code = lc.currentLocale.value.languageCode;
            const activeColor = Color(0xff19133F);
            return Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor:
                        code == 'ar' ? activeColor : Colors.grey.shade600,
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor:
                        code == 'en' ? activeColor : Colors.grey.shade600,
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
        ],
      ),
    ),
  );
}
