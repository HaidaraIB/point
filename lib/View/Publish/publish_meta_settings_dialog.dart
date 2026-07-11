import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/meta/meta_graph_client.dart';
import 'package:point/Services/meta/meta_errors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';

/// Dialog to save global Meta token and optionally verify against Graph API.
Future<void> showPublishMetaSettingsDialog() async {
  MetaAppSettings? existing;
  try {
    existing = await MetaAppSettings.load();
  } catch (_) {
    FunHelper.showSnackbar(
      'error'.tr,
      'publish.settings_load_failed'.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }
  final tokenController = TextEditingController(text: existing?.accessToken ?? '');
  final versionController = TextEditingController(text: existing?.graphVersion ?? 'v25.0');
  final verifying = ValueNotifier<bool>(false);
  final verifyResult = ValueNotifier<String>('');
  final verifyIsError = ValueNotifier<bool>(false);

  Future<void> verify() async {
    final t = tokenController.text.trim();
    if (t.isEmpty) {
      verifyResult.value = 'meta_err_settings_missing'.tr;
      verifyIsError.value = true;
      return;
    }
    verifying.value = true;
    verifyResult.value = '';
    try {
      final s = MetaAppSettings(
        accessToken: t,
        graphVersion: versionController.text.trim().isEmpty
            ? 'v25.0'
            : versionController.text.trim(),
      );
      final assets = await MetaGraphClient.listBusinessAssets(s);
      verifyResult.value =
          'publish.pages_found'.trParams({'count': '${assets.length}'});
      verifyIsError.value = false;
    } catch (e) {
      verifyResult.value =
          formatMetaPublishFailure(e, Get.locale?.languageCode ?? 'ar');
      verifyIsError.value = true;
    } finally {
      verifying.value = false;
    }
  }

  await Get.dialog<void>(
    Builder(
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appTheme.cardSurface,
        title: Text(
          'publish.meta_settings'.tr,
          style: TextStyle(color: ctx.appTheme.primaryText),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InputText(
                  labelText: 'publish.access_token_label'.tr,
                  hintText: '',
                  height: 42,
                  controller: tokenController,
                  borderRadius: 5,
                ),
                const SizedBox(height: 12),
                InputText(
                  labelText: 'publish.graph_version'.tr,
                  hintText: 'v25.0',
                  height: 42,
                  controller: versionController,
                  borderRadius: 5,
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: verifyResult,
                  builder: (_, text, __) {
                    if (text.isEmpty) return const SizedBox.shrink();
                    return ValueListenableBuilder<bool>(
                      valueListenable: verifyIsError,
                      builder: (_, err, ___) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            text,
                            style: TextStyle(
                              color: err ? Colors.red : Colors.green,
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: verifying,
                  builder: (_, load, __) {
                    return MainButton(
                      title: 'publish.verify_token'.tr,
                      load: load,
                      height: 40,
                      borderSize: 8,
                      onPressed: load ? null : verify,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('common.cancel'.tr)),
          TextButton(
            onPressed: () async {
              final t = tokenController.text.trim();
              if (t.isEmpty) {
                FunHelper.showSnackbar(
                  'error'.tr,
                  'meta_err_settings_missing'.tr,
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              await MetaAppSettings.save(
                accessToken: t,
                graphVersion: versionController.text.trim().isEmpty
                    ? 'v25.0'
                    : versionController.text.trim(),
              );
              MetaGraphClient.clearResponseCache();
              FunHelper.showSnackbar(
                'common.save'.tr,
                'publish.settings_saved'.tr,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
              Get.back();
            },
            child: Text('common.save'.tr),
          ),
        ],
      ),
    ),
    barrierDismissible: false,
  );
}
