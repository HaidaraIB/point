import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FunHelper {

  static errorsnackbar(error) {
    return FunHelper.showsnackbar(
      'Error',
      error.toString(),
      backgroundColor: Colors.red,

      colorText: Colors.white,
    );
  }

  static succssessnackbar(Succsses) {
    return FunHelper.showsnackbar(
      'Succsses',
      Succsses.toString(),
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
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
      if (date != null)
        return DateFormat('dd MM yyyy - hh:mm a').format(date.toLocal());
      //  DateFormat.yMMMMd().format(date);
    } catch (e) {
      return null;
    }
    return null;
  }

  static String? formatdateTime(DateTime? date) {
    try {
      if (date != null) return DateFormat('yyyy-MM-dd – HH:mm a').format(date);
    } catch (e) {
      return null;
    }
    return null;
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
    String title = 'تحذير',
    String message = 'هل متأكد من اتمام العمليه',
    String confirmText = 'تأكيد',
    Color? confirmColor,
    String? cancelText,
    Color cancelColor = const Color(0xFF7A8194),
  }) async {
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
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
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
                title: confirmText,
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
      return 'الآن';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
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
            child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
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
