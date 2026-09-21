import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsEmailHubController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsEmailSettings.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_form_widgets.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Agency sender profile for outbound email (invoices, payslips, HR letters, etc.).
class OsEmailSettingsPanel extends StatefulWidget {
  const OsEmailSettingsPanel({super.key});

  @override
  State<OsEmailSettingsPanel> createState() => _OsEmailSettingsPanelState();
}

class _OsEmailSettingsPanelState extends State<OsEmailSettingsPanel> {
  final _senderName = TextEditingController();
  final _senderEmail = TextEditingController();
  final _replyTo = TextEditingController();
  final _signature = TextEditingController();
  final _bccEmail = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  var _enableBcc = true;
  var _dirty = false;
  Worker? _settingsWorker;

  OsEmailHubController get _hub => Get.find<OsEmailHubController>();

  @override
  void initState() {
    super.initState();
    Get.find<OsEmailHubController>();
    _syncFromController();
    _settingsWorker = ever(_hub.settings, (_) {
      if (!_dirty && mounted) setState(_syncFromController);
    });
  }

  @override
  void dispose() {
    _settingsWorker?.dispose();
    _senderName.dispose();
    _senderEmail.dispose();
    _replyTo.dispose();
    _signature.dispose();
    _bccEmail.dispose();
    _address.dispose();
    _phone.dispose();
    _website.dispose();
    super.dispose();
  }

  void _syncFromController() {
    final s = _hub.settings.value;
    _senderName.text = s.senderName;
    _senderEmail.text = s.senderEmail;
    _replyTo.text = s.replyToEmail;
    _signature.text = s.signatureText;
    _bccEmail.text = s.autoBccEmail;
    _address.text = s.companyAddress;
    _phone.text = s.companyPhone;
    _website.text = s.companyWebsite;
    _enableBcc = s.enableAutoBcc;
  }

  void _onChanged() => setState(() => _dirty = true);

  OsEmailSettings _buildSettings() {
    return _hub.settings.value.copyWith(
      senderName: _senderName.text.trim(),
      senderEmail: _senderEmail.text.trim(),
      replyToEmail: _replyTo.text.trim(),
      signatureText: _signature.text.trim(),
      enableAutoBcc: _enableBcc,
      autoBccEmail: _bccEmail.text.trim(),
      companyAddress: _address.text.trim(),
      companyPhone: _phone.text.trim(),
      companyWebsite: _website.text.trim(),
    );
  }

  Future<void> _save() async {
    final ok = await _hub.saveSettings(_buildSettings());
    if (!mounted) return;
    if (ok) {
      setState(() => _dirty = false);
      _syncFromController();
      OsSnackbar.success(
        AppLocaleKeys.osSettingsEmailSection.tr,
        AppLocaleKeys.osSettingsEmailSaved.tr,
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osSettingsEmailSection.tr,
        AppLocaleKeys.osCommonSaveFailed.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocaleKeys.osSettingsEmailDescription.tr,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocaleKeys.osEmailHubSettingsSenderSectionHint.tr,
          style: TextStyle(
            fontSize: 11,
            color: theme.mutedText,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        osEmailHubTextField(
          context,
          label: AppLocaleKeys.osEmailHubSettingsSenderName.tr,
          controller: _senderName,
          onChanged: (_) => _onChanged(),
        ),
        const SizedBox(height: 12),
        osEmailHubTextField(
          context,
          label: AppLocaleKeys.osEmailHubSettingsSenderEmail.tr,
          controller: _senderEmail,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => _onChanged(),
        ),
        const SizedBox(height: 12),
        osEmailHubTextField(
          context,
          label: AppLocaleKeys.osEmailHubSettingsReplyTo.tr,
          controller: _replyTo,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => _onChanged(),
        ),
        const SizedBox(height: 12),
        osEmailHubSwitchRow(
          context,
          label: AppLocaleKeys.osEmailHubSettingsEnableBcc.tr,
          value: _enableBcc,
          onChanged: (v) {
            setState(() {
              _enableBcc = v;
              _dirty = true;
            });
          },
        ),
        if (_enableBcc) ...[
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osEmailHubSettingsBccEmail.tr,
            controller: _bccEmail,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => _onChanged(),
          ),
        ],
        const SizedBox(height: 12),
        osEmailHubTextField(
          context,
          label: AppLocaleKeys.osEmailHubSettingsSignature.tr,
          controller: _signature,
          maxLines: 4,
          onChanged: (_) => _onChanged(),
        ),
        const SizedBox(height: 12),
        osEmailHubTextField(
          context,
          label: AppLocaleKeys.osEmailHubSettingsAddress.tr,
          controller: _address,
          maxLines: 2,
          onChanged: (_) => _onChanged(),
        ),
        const SizedBox(height: 12),
        osEmailHubTextField(
          context,
          label: AppLocaleKeys.osEmailHubSettingsPhone.tr,
          controller: _phone,
          keyboardType: TextInputType.phone,
          onChanged: (_) => _onChanged(),
        ),
        const SizedBox(height: 12),
        osEmailHubTextField(
          context,
          label: AppLocaleKeys.osEmailHubSettingsWebsite.tr,
          controller: _website,
          onChanged: (_) => _onChanged(),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Obx(() {
            return FilledButton.icon(
              onPressed: _hub.isSavingSettings.value ? null : _save,
              style: OsButtonStyles.primaryCompact(),
              icon: _hub.isSavingSettings.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(AppLocaleKeys.osSettingsEmailSave.tr),
            );
          }),
        ),
      ],
    );
  }
}
