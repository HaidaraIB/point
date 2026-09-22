import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsWhatsappSettingsStatus.dart';
import 'package:point/Services/os_whatsapp_service.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/Utils/phone_ltr.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/phone_number_text.dart';

class OsWhatsappSettingsPanel extends StatefulWidget {
  const OsWhatsappSettingsPanel({super.key});

  @override
  State<OsWhatsappSettingsPanel> createState() => _OsWhatsappSettingsPanelState();
}

class _OsWhatsappSettingsPanelState extends State<OsWhatsappSettingsPanel> {
  final _tokenCtrl = TextEditingController();
  final _phoneIdCtrl = TextEditingController();
  final _wabaIdCtrl = TextEditingController();

  var _loading = true;
  var _saving = false;
  var _testing = false;
  var _obscureToken = true;
  var _isEnabled = false;
  OsWhatsappSettingsStatus _status = OsWhatsappSettingsStatus.empty();

  @override
  void initState() {
    super.initState();
    final cached = OsWhatsappService.instance.cachedSettings;
    if (cached != null) {
      _applyStatus(cached);
      _loading = false;
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _phoneIdCtrl.dispose();
    _wabaIdCtrl.dispose();
    super.dispose();
  }

  void _applyStatus(OsWhatsappSettingsStatus status) {
    _status = status;
    _phoneIdCtrl.text = status.phoneNumberId;
    _wabaIdCtrl.text = status.businessAccountId;
    _isEnabled = status.isEnabled;
    _tokenCtrl.clear();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status =
          await OsWhatsappService.instance.loadSettings(force: true);
      if (!mounted) return;
      setState(() => _applyStatus(status ?? OsWhatsappSettingsStatus.empty()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final phoneId = _phoneIdCtrl.text.trim();
    final wabaId = _wabaIdCtrl.text.trim();

    if (_isEnabled) {
      if (!_status.hasAccessToken && _tokenCtrl.text.trim().isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsWhatsappSection.tr,
          AppLocaleKeys.osSettingsWhatsappTokenRequired.tr,
        );
        return;
      }
      if (phoneId.isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsWhatsappSection.tr,
          AppLocaleKeys.osSettingsWhatsappPhoneIdRequired.tr,
        );
        return;
      }
      if (wabaId.isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsWhatsappSection.tr,
          AppLocaleKeys.osSettingsWhatsappWabaIdRequired.tr,
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final status = await OsWhatsappService.instance.saveSettings(
        accessToken: _tokenCtrl.text.trim().isEmpty
            ? null
            : _tokenCtrl.text.trim(),
        phoneNumberId: phoneId,
        businessAccountId: wabaId,
        isEnabled: _isEnabled,
      );
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsWhatsappSection.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _applyStatus(status));
      OsSnackbar.success(
        AppLocaleKeys.osSettingsWhatsappSection.tr,
        AppLocaleKeys.osSettingsWhatsappSaved.tr,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final saved = await OsWhatsappService.instance.saveSettings(
        accessToken: _tokenCtrl.text.trim().isEmpty
            ? null
            : _tokenCtrl.text.trim(),
        phoneNumberId: _phoneIdCtrl.text.trim(),
        businessAccountId: _wabaIdCtrl.text.trim(),
        isEnabled: _isEnabled,
      );
      if (!mounted) return;
      if (saved == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsWhatsappSection.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _applyStatus(saved));

      final outcome = await OsWhatsappService.instance.testConnection();
      if (!mounted) return;
      final result = outcome.result;
      if (result == null) {
        final detail = outcome.errorMessage?.trim();
        OsSnackbar.error(
          AppLocaleKeys.osSettingsWhatsappSection.tr,
          detail != null && detail.isNotEmpty
              ? AppLocaleKeys.osSettingsWhatsappTestFailedDetail.trParams({
                  'detail': detail,
                })
              : AppLocaleKeys.osSettingsWhatsappTestFailed.tr,
        );
        return;
      }
      final status =
          await OsWhatsappService.instance.loadSettings(force: true);
      if (status != null) setState(() => _applyStatus(status));
      OsSnackbar.success(
        AppLocaleKeys.osSettingsWhatsappSection.tr,
        AppLocaleKeys.osSettingsWhatsappTestSuccess.trParams({
          'name': result.verifiedName.isEmpty
              ? AppLocaleKeys.osSettingsWhatsappSection.tr
              : result.verifiedName,
          'phone': isolatePhoneLtr(result.displayPhoneNumber),
        }),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _labeledLtrValue(
    AppThemeExtension theme,
    String label,
    String value, {
    bool phone = false,
  }) {
    final valueStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: theme.mutedText,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: theme.mutedText),
        ),
        Expanded(
          child: phone
              ? PhoneNumberText(value, style: valueStyle)
              : Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(value, style: valueStyle),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = context.appTheme;
    final configured = _status.isReadyForSend ||
        (_status.hasAccessToken && _status.phoneNumberId.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocaleKeys.osSettingsWhatsappDescription.tr,
          style: TextStyle(fontSize: 13, height: 1.5, color: theme.secondaryText),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              configured ? Icons.check_circle_outline : Icons.error_outline,
              size: 18,
              color: configured
                  ? const Color(0xFF059669)
                  : const Color(0xFFE11D48),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                configured
                    ? AppLocaleKeys.osSettingsWhatsappConfigured.tr
                    : AppLocaleKeys.osSettingsWhatsappNotConfigured.tr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.primaryText,
                ),
              ),
            ),
          ],
        ),
        if (_status.hasAccessToken && _status.accessTokenPreview.isNotEmpty) ...[
          const SizedBox(height: 8),
          _labeledLtrValue(
            theme,
            AppLocaleKeys.osSettingsWhatsappTokenPreviewLabel.tr,
            _status.accessTokenPreview,
          ),
        ],
        if (_status.displayPhoneNumber.isNotEmpty) ...[
          const SizedBox(height: 8),
          _labeledLtrValue(
            theme,
            AppLocaleKeys.osSettingsWhatsappDisplayPhoneLabel.tr,
            _status.displayPhoneNumber,
            phone: true,
          ),
        ],
        const SizedBox(height: 16),
        osTypedTextField(
          controller: _tokenCtrl,
          obscureText: _obscureToken,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsWhatsappAccessToken.tr,
            hintText: AppLocaleKeys.osSettingsWhatsappAccessTokenHint.tr,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
              icon: Icon(
                _obscureToken
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        osTypedTextField(
          controller: _phoneIdCtrl,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsWhatsappPhoneNumberId.tr,
            hintText: AppLocaleKeys.osSettingsWhatsappPhoneNumberIdHint.tr,
          ),
        ),
        const SizedBox(height: 12),
        osTypedTextField(
          controller: _wabaIdCtrl,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsWhatsappBusinessAccountId.tr,
            hintText: AppLocaleKeys.osSettingsWhatsappBusinessAccountIdHint.tr,
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(AppLocaleKeys.osSettingsWhatsappEnabled.tr),
          value: _isEnabled,
          onChanged: (v) => setState(() => _isEnabled = v),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _testing || _saving ? null : _test,
                style: OutlinedButton.styleFrom(
                  padding: OsButtonStyles.compactPadding,
                  minimumSize: OsButtonStyles.compactMinSize,
                  textStyle: OsButtonStyles.compactTextStyle,
                  visualDensity: VisualDensity.standard,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  iconSize: 18,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _testing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link, size: 18),
                label: Text(
                  AppLocaleKeys.osSettingsWhatsappTest.tr,
                  style: OsButtonStyles.compactTextStyle,
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: OsButtonStyles.primaryCompact(),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  AppLocaleKeys.osSettingsWhatsappSave.tr,
                  style: OsButtonStyles.compactTextStyle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
