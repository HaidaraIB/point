import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsAiSettingsStatus.dart';
import 'package:point/Services/os_ai_service.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

class OsSettingsPage extends StatefulWidget {
  const OsSettingsPage({super.key});

  @override
  State<OsSettingsPage> createState() => _OsSettingsPageState();
}

class _OsSettingsPageState extends State<OsSettingsPage> {
  final _apiKeyCtrl = TextEditingController();
  var _loading = true;
  var _saving = false;
  var _obscureKey = true;
  OsAiSettingsStatus _status = OsAiSettingsStatus.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await OsAiService.instance.loadSettings();
      if (!mounted) return;
      setState(() {
        _status = status;
        _apiKeyCtrl.clear();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osSettingsTitle.tr,
        AppLocaleKeys.osSettingsAiKeyRequired.tr,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final status = await OsAiService.instance.saveGeminiApiKey(key);
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsTitle.tr,
          AppLocaleKeys.osSettingsAiKeyInvalid.tr,
        );
        return;
      }
      setState(() {
        _status = status;
        _apiKeyCtrl.clear();
      });
      OsSnackbar.success(
        AppLocaleKeys.osSettingsTitle.tr,
        AppLocaleKeys.osSettingsAiSaved.tr,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearStoredKey() async {
    setState(() => _saving = true);
    try {
      final status = await OsAiService.instance.saveGeminiApiKey('');
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsTitle.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() {
        _status = status;
        _apiKeyCtrl.clear();
      });
      OsSnackbar.success(
        AppLocaleKeys.osSettingsTitle.tr,
        AppLocaleKeys.osSettingsAiCleared.tr,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessOsSection(emp)) {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    final theme = context.appTheme;

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osSettingsTitle.tr,
            subtitle: AppLocaleKeys.osSettingsSubtitle.tr,
            currentRoute: '/os/settings',
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _SettingsCard(
                        title: AppLocaleKeys.osSettingsAiSection.tr,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppLocaleKeys.osSettingsAiDescription.tr,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: theme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  _status.hasGeminiKey
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  size: 18,
                                  color: _status.hasGeminiKey
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFE11D48),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _status.hasGeminiKey
                                        ? AppLocaleKeys.osSettingsAiConfigured.tr
                                        : AppLocaleKeys.osSettingsAiNotConfigured.tr,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: theme.primaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_status.hasGeminiKey &&
                                _status.keyPreview.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                AppLocaleKeys.osSettingsAiKeyPreview.trParams({
                                  'preview': _status.keyPreview,
                                }),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: theme.mutedText,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              AppLocaleKeys.osSettingsAiKeyLabel.tr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _apiKeyCtrl,
                              obscureText: _obscureKey,
                              decoration: osDialogFieldDecoration(context).copyWith(
                                hintText:
                                    AppLocaleKeys.osSettingsAiKeyHint.tr,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureKey = !_obscureKey,
                                  ),
                                  icon: Icon(
                                    _obscureKey
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: _saving ? null : _save,
                                  style: OsButtonStyles.primaryCompact(),
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined, size: 18),
                                  label: Text(AppLocaleKeys.osSettingsAiSave.tr),
                                ),
                                if (_status.configuredInFirestore)
                                  OutlinedButton.icon(
                                    onPressed: _saving ? null : _clearStoredKey,
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    label: Text(
                                      AppLocaleKeys.osSettingsAiClear.tr,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: theme.accentText),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
