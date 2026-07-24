import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/WebUpdateController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';

/// Non-blocking strip shown when a newer web build is deployed.
class WebUpdateBanner extends StatelessWidget {
  const WebUpdateBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !Get.isRegistered<WebUpdateController>()) {
      return child;
    }
    final controller = Get.find<WebUpdateController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Obx(() {
      final show = controller.updateAvailable.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (show)
            Material(
              color: colorScheme.secondaryContainer,
              elevation: 2,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.system_update_alt,
                        size: 20,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppLocaleKeys.webUpdateAvailable.tr,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: controller.reload,
                        child: Text(AppLocaleKeys.webUpdateReload.tr),
                      ),
                      IconButton(
                        tooltip: AppLocaleKeys.webUpdateDismiss.tr,
                        onPressed: controller.dismiss,
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: child),
        ],
      );
    });
  }
}
