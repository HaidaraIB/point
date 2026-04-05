import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/app_version.dart';

Future<AppVersionInfo>? _cachedAppVersionFuture;

Future<AppVersionInfo> _resolveAppVersionFuture() {
  _cachedAppVersionFuture ??= loadAppVersionInfo();
  return _cachedAppVersionFuture!;
}

/// عرض إصدار التطبيق بشكل موحّد (شريط جانبي، عميل، موظف، إلخ).
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({
    super.key,
    this.compact = false,
    this.padding = EdgeInsets.zero,
    this.textStyle,
    this.iconColor,
    this.textAlign = TextAlign.center,
    this.safeAreaBottom = false,
  });

  /// إن `true` يعرض أيقونة مع [Tooltip] (مثل الشريط المطوي).
  final bool compact;

  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final Color? iconColor;
  final TextAlign textAlign;

  /// يضيف [SafeArea] سفليًّا فوق شريط تنقل الجهاز.
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    final fallbackStyle = TextStyle(
      fontSize: 12,
      height: 1.25,
      color: Theme.of(context).hintColor,
    );
    final effectiveStyle = textStyle ?? fallbackStyle;
    final iconTint =
        iconColor ?? effectiveStyle.color ?? Theme.of(context).hintColor;

    return FutureBuilder<AppVersionInfo>(
      future: _resolveAppVersionFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final info = snapshot.data!;
        final line = AppLocaleKeys.appVersionLine.trParams({
          'version': info.version,
          'build': info.buildNumber,
        });
        Widget child =
            compact
                ? Center(
                  child: Tooltip(
                    message: line,
                    child: Icon(
                      Icons.info_outline,
                      color: iconTint,
                      size: 20,
                    ),
                  ),
                )
                : Text(line, textAlign: textAlign, style: effectiveStyle);

        child = Padding(padding: padding, child: child);
        if (safeAreaBottom) {
          child = SafeArea(top: false, minimum: EdgeInsets.zero, child: child);
        }
        return child;
      },
    );
  }
}
