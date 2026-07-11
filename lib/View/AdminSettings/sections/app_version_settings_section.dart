import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/app_version.dart';
import 'package:point/Services/app_version_gate_settings.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Minimum mobile build numbers and store URLs for force-update.
class AppVersionSettingsSection extends StatefulWidget {
  const AppVersionSettingsSection({super.key});

  @override
  State<AppVersionSettingsSection> createState() =>
      _AppVersionSettingsSectionState();
}

class _AppVersionSettingsSectionState extends State<AppVersionSettingsSection> {
  final _formKey = GlobalKey<FormState>();
  final _androidMinController = TextEditingController();
  final _iosMinController = TextEditingController();
  final _androidStoreController = TextEditingController();
  final _iosStoreController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _currentVersionLine;
  int? _currentBuild;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _androidMinController.dispose();
    _iosMinController.dispose();
    _androidStoreController.dispose();
    _iosStoreController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final versionInfo = await loadAppVersionInfo();
      final build = int.tryParse(versionInfo.buildNumber.trim());
      final settings = await AppVersionGateSettings.load();

      _currentVersionLine = AppLocaleKeys.adminSettingsCurrentRelease.trParams({
        'version': versionInfo.version,
        'build': versionInfo.buildNumber,
      });
      _currentBuild = build;

      _androidMinController.text =
          settings?.androidMinBuild.toString() ?? (build?.toString() ?? '0');
      _iosMinController.text =
          settings?.iosMinBuild.toString() ?? (build?.toString() ?? '0');
      _androidStoreController.text = settings?.androidStoreUrl ?? '';
      _iosStoreController.text = settings?.iosStoreUrl ?? '';
    } catch (_) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.adminSettingsLoadFailed.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _parseMinBuild(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final androidMin = _parseMinBuild(_androidMinController.text)!;
    final iosMin = _parseMinBuild(_iosMinController.text)!;
    final androidUrl = _androidStoreController.text.trim();
    final iosUrl = _iosStoreController.text.trim();

    setState(() => _saving = true);
    try {
      await AppVersionGateSettings.save(
        androidMinBuild: androidMin,
        iosMinBuild: iosMin,
        androidStoreUrl: androidUrl,
        iosStoreUrl: iosUrl,
      );
      FunHelper.showSnackbar(
        'common.save'.tr,
        AppLocaleKeys.adminSettingsAppVersionSaveSuccess.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on FirebaseException catch (e, s) {
      appLog(
        'App version settings save failed: ${e.code} ${e.message}',
        error: e,
        stackTrace: s,
      );
      final message = e.code == 'permission-denied'
          ? AppLocaleKeys.adminSettingsSavePermissionDenied.tr
          : AppLocaleKeys.adminSettingsSaveFailed.tr;
      FunHelper.showSnackbar(
        'error'.tr,
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e, s) {
      appLog('App version settings save failed: $e', error: e, stackTrace: s);
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.adminSettingsSaveFailed.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateMinBuild(String? value) {
    final parsed = _parseMinBuild(value);
    if (parsed == null || parsed < 0) {
      return AppLocaleKeys.adminSettingsInvalidBuild.tr;
    }
    return null;
  }

  Widget _buildWarningBanner() {
    final current = _currentBuild;
    if (current == null) return const SizedBox.shrink();

    final androidMin = _parseMinBuild(_androidMinController.text);
    final iosMin = _parseMinBuild(_iosMinController.text);
    final blocksUsers =
        (androidMin != null && androidMin > current) ||
        (iosMin != null && iosMin > current);
    if (!blocksUsers) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        AppLocaleKeys.adminSettingsMinAboveCurrentWarning.trParams({
          'build': '$current',
        }),
        style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocaleKeys.adminSettingsSectionAppVersion.tr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_currentVersionLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  _currentVersionLine!,
                  style: TextStyle(
                    color: context.appTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                AppLocaleKeys.adminSettingsMobileGateHelp.tr,
                style: TextStyle(
                  color: context.appTheme.secondaryText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              _buildWarningBanner(),
              InputText(
                labelText: AppLocaleKeys.adminSettingsAndroidMinBuild.tr,
                hintText: '0',
                height: 42,
                controller: _androidMinController,
                borderRadius: 5,
                textInputType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateMinBuild,
                onchange: (_) {
                  setState(() {});
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InputText(
                labelText: AppLocaleKeys.adminSettingsIosMinBuild.tr,
                hintText: '0',
                height: 42,
                controller: _iosMinController,
                borderRadius: 5,
                textInputType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateMinBuild,
                onchange: (_) {
                  setState(() {});
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InputText(
                labelText: AppLocaleKeys.adminSettingsAndroidStoreUrl.tr,
                hintText: 'https://play.google.com/...',
                height: 42,
                controller: _androidStoreController,
                borderRadius: 5,
                textInputType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              InputText(
                labelText: AppLocaleKeys.adminSettingsIosStoreUrl.tr,
                hintText: 'https://apps.apple.com/...',
                height: 42,
                controller: _iosStoreController,
                borderRadius: 5,
                textInputType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              MainButton(
                title: 'common.save'.tr,
                load: _saving,
                height: 44,
                borderSize: 8,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
