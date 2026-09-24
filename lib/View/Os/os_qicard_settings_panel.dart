import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsQicardSettingsStatus.dart';
import 'package:point/Services/os_qicard_service.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Settings/os_payment_credentials_form.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsQicardSettingsPanel extends StatefulWidget {
  const OsQicardSettingsPanel({
    super.key,
    this.embedded = false,
    this.compact = false,
    this.onSettingsSaved,
  });

  final bool embedded;
  final bool compact;
  final ValueChanged<OsQicardSettingsStatus>? onSettingsSaved;

  @override
  State<OsQicardSettingsPanel> createState() => _OsQicardSettingsPanelState();
}

class _OsQicardSettingsPanelState extends State<OsQicardSettingsPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _terminalIdCtrl = TextEditingController();
  final _liveApiBaseCtrl = TextEditingController();
  final _webhookKeyCtrl = TextEditingController();

  var _loading = true;
  var _saving = false;
  var _obscurePassword = true;
  var _environment = 'test';
  var _currency = 'IQD';
  OsQicardSettingsStatus _status = OsQicardSettingsStatus.empty();

  static const _currencies = ['IQD'];

  @override
  void initState() {
    super.initState();
    final cached = OsQicardService.instance.cachedSettings;
    if (cached != null) {
      _applyStatus(cached);
      _loading = false;
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _terminalIdCtrl.dispose();
    _liveApiBaseCtrl.dispose();
    _webhookKeyCtrl.dispose();
    super.dispose();
  }

  void _applyStatus(OsQicardSettingsStatus status) {
    _status = status;
    _environment = status.environment.isEmpty ? 'test' : status.environment;
    _currency = status.currency.isEmpty ? 'IQD' : status.currency;
    _usernameCtrl.text = status.username;
    _terminalIdCtrl.text = status.terminalId;
    _liveApiBaseCtrl.text = status.liveApiBase;
    _passwordCtrl.clear();
    _webhookKeyCtrl.clear();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await OsQicardService.instance.loadSettings(force: true);
      if (!mounted) return;
      setState(() =>
          _applyStatus(status ?? OsQicardSettingsStatus.empty()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySandboxCredentials() {
    setState(() {
      _environment = 'test';
      _usernameCtrl.text = 'paymentgatewaytest';
      _passwordCtrl.text = 'WHaNFE5C3qlChqNbAzH4';
      _terminalIdCtrl.text = '237984';
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final status = await OsQicardService.instance.saveSettings(
        environment: _environment,
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text.trim().isEmpty
            ? null
            : _passwordCtrl.text.trim(),
        terminalId: _terminalIdCtrl.text.trim(),
        currency: _currency,
        liveApiBase: _liveApiBaseCtrl.text.trim().isEmpty
            ? null
            : _liveApiBaseCtrl.text.trim(),
        webhookPublicKey: _webhookKeyCtrl.text.trim().isEmpty
            ? null
            : _webhookKeyCtrl.text.trim(),
      );
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsQicardSection.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _applyStatus(status));
      widget.onSettingsSaved?.call(status);
      OsSnackbar.success(
        AppLocaleKeys.osSettingsQicardSection.tr,
        AppLocaleKeys.osSettingsQicardSaved.tr,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = context.appTheme;
    final configured =
        _status.hasPassword && _status.username.isNotEmpty && _status.terminalId.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Text(
            AppLocaleKeys.osSettingsQicardDescription.tr,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            configured
                ? AppLocaleKeys.osSettingsQicardConfigured.tr
                : AppLocaleKeys.osSettingsQicardNotConfigured.tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color:
                  configured ? const Color(0xFF059669) : theme.secondaryText,
            ),
          ),
          if (_status.passwordPreview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              AppLocaleKeys.osSettingsQicardPasswordPreview.trParams({
                'preview': _status.passwordPreview,
              }),
              style: TextStyle(fontSize: 12, color: theme.secondaryText),
            ),
          ],
          const SizedBox(height: 16),
        ] else if (_status.passwordPreview.isNotEmpty) ...[
          osPaymentCredentialsSecretPreview(
            context,
            AppLocaleKeys.osSettingsQicardPasswordPreview.trParams({
              'preview': _status.passwordPreview,
            }),
          ),
          const SizedBox(height: kOsPaymentCredentialsFieldGap),
        ],
        osPaymentCredentialsEnvironmentField(
          context: context,
          environment: _environment,
          onEnvironmentSelected: (next) async {
            setState(() => _environment = next);
            final status = await OsQicardService.instance.loadSettings(
              force: true,
              environment: next,
            );
            if (!mounted || status == null) return;
            setState(() => _applyStatus(status));
          },
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _usernameCtrl,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsQicardUsername.tr,
          ),
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsQicardPassword.tr,
            hintText: AppLocaleKeys.osSettingsQicardPasswordHint.tr,
            suffixIcon: osPaymentCredentialsObscureToggle(
              obscure: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _terminalIdCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsQicardTerminalId.tr,
          ),
        ),
        if (_environment == 'live') ...[
          const SizedBox(height: kOsPaymentCredentialsFieldGap),
          osTypedTextField(
            controller: _liveApiBaseCtrl,
            decoration: osDialogFieldDecoration(context).copyWith(
              labelText: AppLocaleKeys.osSettingsQicardLiveApiBase.tr,
              hintText: AppLocaleKeys.osSettingsQicardLiveApiBaseHint.tr,
            ),
          ),
        ],
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsQicardCurrency.tr,
          ),
          items: [
            for (final c in _currencies)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => _currency = v ?? 'IQD'),
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _webhookKeyCtrl,
          maxLines: 4,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsQicardWebhookKey.tr,
            hintText: AppLocaleKeys.osSettingsQicardWebhookKeyHint.tr,
          ),
        ),
        if (_status.hasWebhookPublicKey) ...[
          const SizedBox(height: 8),
          Text(
            AppLocaleKeys.osSettingsQicardWebhookKeyConfigured.tr,
            style: TextStyle(fontSize: 12, color: theme.secondaryText),
          ),
        ],
        if (_environment == 'test') ...[
          const SizedBox(height: kOsPaymentCredentialsFieldGap),
          osPaymentCredentialsSandboxButton(
            context: context,
            onPressed: _applySandboxCredentials,
            label: AppLocaleKeys.osSettingsQicardUseSandbox.tr,
          ),
        ],
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osPaymentCredentialsSaveRow(
          context: context,
          saving: _saving,
          onSave: _save,
          label: AppLocaleKeys.osSettingsQicardSave.tr,
        ),
      ],
    );
  }
}
