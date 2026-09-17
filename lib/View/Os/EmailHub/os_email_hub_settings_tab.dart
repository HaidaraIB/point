import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsEmailHubController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsEmailSettings.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_form_widgets.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsEmailHubSettingsTab extends StatefulWidget {
  const OsEmailHubSettingsTab({
    super.key,
    required this.hub,
    required this.isVisible,
  });

  final OsEmailHubController hub;
  final bool isVisible;

  @override
  State<OsEmailHubSettingsTab> createState() => _OsEmailHubSettingsTabState();
}

class _OsEmailHubSettingsTabState extends State<OsEmailHubSettingsTab> {
  late final TextEditingController _senderName;
  late final TextEditingController _senderEmail;
  late final TextEditingController _replyTo;
  late final TextEditingController _signature;
  late final TextEditingController _bccEmail;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  var _enableBcc = true;

  @override
  void initState() {
    super.initState();
    _senderName = TextEditingController();
    _senderEmail = TextEditingController();
    _replyTo = TextEditingController();
    _signature = TextEditingController();
    _bccEmail = TextEditingController();
    _address = TextEditingController();
    _phone = TextEditingController();
    _website = TextEditingController();
    _applySettings(widget.hub.settings.value);
  }

  @override
  void didUpdateWidget(covariant OsEmailHubSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _applySettings(widget.hub.settings.value);
      setState(() => _enableBcc = widget.hub.settings.value.enableAutoBcc);
    }
  }

  @override
  void dispose() {
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

  void _applySettings(OsEmailSettings s) {
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

  OsEmailSettings _buildSettings() {
    return widget.hub.settings.value.copyWith(
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

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocaleKeys.osEmailHubSettingsSenderSection.tr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocaleKeys.osEmailHubSettingsSenderSectionHint.tr,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.mutedText,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              osEmailHubTextField(
                context,
                label: AppLocaleKeys.osEmailHubSettingsSenderName.tr,
                controller: _senderName,
              ),
              const SizedBox(height: 12),
              osEmailHubTextField(
                context,
                label: AppLocaleKeys.osEmailHubSettingsSenderEmail.tr,
                controller: _senderEmail,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              osEmailHubTextField(
                context,
                label: AppLocaleKeys.osEmailHubSettingsReplyTo.tr,
                controller: _replyTo,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              osEmailHubSwitchRow(
                context,
                label: AppLocaleKeys.osEmailHubSettingsEnableBcc.tr,
                value: _enableBcc,
                onChanged: (v) => setState(() => _enableBcc = v),
              ),
              if (_enableBcc) ...[
                const SizedBox(height: 12),
                osEmailHubTextField(
                  context,
                  label: AppLocaleKeys.osEmailHubSettingsBccEmail.tr,
                  controller: _bccEmail,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
              const SizedBox(height: 12),
              osEmailHubTextField(
                context,
                label: AppLocaleKeys.osEmailHubSettingsSignature.tr,
                controller: _signature,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              osEmailHubTextField(
                context,
                label: AppLocaleKeys.osEmailHubSettingsAddress.tr,
                controller: _address,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              osEmailHubTextField(
                context,
                label: AppLocaleKeys.osEmailHubSettingsPhone.tr,
                controller: _phone,
              ),
              const SizedBox(height: 12),
              osEmailHubTextField(
                context,
                label: AppLocaleKeys.osEmailHubSettingsWebsite.tr,
                controller: _website,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Obx(() {
                  return FilledButton.icon(
                    onPressed:
                        widget.hub.isSavingSettings.value ? null : _save,
                    style: OsButtonStyles.primaryCompact(),
                    icon: widget.hub.isSavingSettings.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(AppLocaleKeys.osCommonSave.tr),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final ok = await widget.hub.saveSettings(_buildSettings());
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osEmailHubSettingsSaved.tr,
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osEmailHubTitle.tr,
        AppLocaleKeys.osCommonSaveFailed.tr,
      );
    }
  }
}
