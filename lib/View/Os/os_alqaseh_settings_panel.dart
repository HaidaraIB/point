import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsAlqasehSettingsStatus.dart';
import 'package:point/Services/os_alqaseh_service.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Settings/os_payment_credentials_form.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsAlqasehSettingsPanel extends StatefulWidget {
  const OsAlqasehSettingsPanel({
    super.key,
    this.embedded = false,
    this.compact = false,
    this.onSettingsSaved,
  });

  final bool embedded;
  final bool compact;
  final ValueChanged<OsAlqasehSettingsStatus>? onSettingsSaved;

  @override
  State<OsAlqasehSettingsPanel> createState() => _OsAlqasehSettingsPanelState();
}

class _OsAlqasehSettingsPanelState extends State<OsAlqasehSettingsPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _clientIdCtrl = TextEditingController();
  final _clientSecretCtrl = TextEditingController();
  final _tokenExpiryCtrl = TextEditingController(text: '72');

  var _loading = true;
  var _saving = false;
  var _obscureSecret = true;
  var _environment = 'test';
  var _currency = 'IQD';
  OsAlqasehSettingsStatus _status = OsAlqasehSettingsStatus.empty();

  static const _currencies = ['IQD', 'USD'];

  @override
  void initState() {
    super.initState();
    final cached = OsAlqasehService.instance.cachedSettings;
    if (cached != null) {
      _applyStatus(cached);
      _loading = false;
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    _tokenExpiryCtrl.dispose();
    super.dispose();
  }

  void _applyStatus(OsAlqasehSettingsStatus status) {
    _status = status;
    _environment = status.environment.isEmpty ? 'test' : status.environment;
    _currency = status.currency.isEmpty ? 'IQD' : status.currency;
    _clientIdCtrl.text = status.clientId;
    _tokenExpiryCtrl.text = status.tokenExpiryHours.toString();
    _clientSecretCtrl.clear();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status =
          await OsAlqasehService.instance.loadSettings(force: true);
      if (!mounted) return;
      setState(() {
        _applyStatus(status ?? OsAlqasehSettingsStatus.empty());
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySandboxCredentials() {
    setState(() {
      _environment = 'test';
      _clientIdCtrl.text = 'public_test';
      _clientSecretCtrl.text = 'Lr10yWWmm1dXLoI7VgXCrQVnlq13c1G0';
    });
  }

  Future<void> _save() async {
    final clientId = _clientIdCtrl.text.trim();
    final tokenExpiry = int.tryParse(_tokenExpiryCtrl.text.trim()) ?? 72;

    setState(() => _saving = true);
    try {
      final status = await OsAlqasehService.instance.saveSettings(
        environment: _environment,
        clientId: clientId,
        clientSecret: _clientSecretCtrl.text.trim().isEmpty
            ? null
            : _clientSecretCtrl.text.trim(),
        currency: _currency,
        tokenExpiryHours: tokenExpiry,
      );
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsAlqasehSection.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _applyStatus(status));
      widget.onSettingsSaved?.call(status);
      OsSnackbar.success(
        AppLocaleKeys.osSettingsAlqasehSection.tr,
        AppLocaleKeys.osSettingsAlqasehSaved.tr,
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
    final configured = _status.hasClientSecret && _status.clientId.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Text(
            AppLocaleKeys.osSettingsAlqasehDescription.tr,
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
                      ? AppLocaleKeys.osSettingsAlqasehConfigured.tr
                      : AppLocaleKeys.osSettingsAlqasehNotConfigured.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryText,
                  ),
                ),
              ),
            ],
          ),
          if (_status.hasClientSecret &&
              _status.clientSecretPreview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              AppLocaleKeys.osSettingsAlqasehSecretPreview.trParams({
                'preview': _status.clientSecretPreview,
              }),
              style: TextStyle(fontSize: 12, color: theme.mutedText),
            ),
          ],
          const SizedBox(height: 16),
        ] else if (_status.hasClientSecret &&
            _status.clientSecretPreview.isNotEmpty) ...[
          osPaymentCredentialsSecretPreview(
            context,
            AppLocaleKeys.osSettingsAlqasehSecretPreview.trParams({
              'preview': _status.clientSecretPreview,
            }),
          ),
          const SizedBox(height: kOsPaymentCredentialsFieldGap),
        ],
        osPaymentCredentialsEnvironmentField(
          context: context,
          environment: _environment,
          onEnvironmentSelected: (next) async {
            setState(() => _environment = next);
            final status = await OsAlqasehService.instance.loadSettings(
              force: true,
              environment: next,
            );
            if (!mounted || status == null) return;
            setState(() => _applyStatus(status));
          },
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _clientIdCtrl,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsAlqasehClientId.tr,
            hintText: AppLocaleKeys.osSettingsAlqasehClientIdHint.tr,
          ),
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _clientSecretCtrl,
          obscureText: _obscureSecret,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsAlqasehClientSecret.tr,
            hintText: AppLocaleKeys.osSettingsAlqasehClientSecretHint.tr,
            suffixIcon: osPaymentCredentialsObscureToggle(
              obscure: _obscureSecret,
              onToggle: () => setState(() => _obscureSecret = !_obscureSecret),
            ),
          ),
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 640;
            final currencyField = DropdownButtonFormField<String>(
              key: ValueKey('alqaseh-$_currency'),
              initialValue: _currencies.contains(_currency)
                  ? _currency
                  : _currencies.first,
              decoration: osDialogFieldDecoration(context).copyWith(
                labelText: AppLocaleKeys.osSettingsAlqasehCurrency.tr,
              ),
              items: [
                for (final c in _currencies)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _currency = v ?? _currency),
            );
            final expiryField = osTypedTextField(
              controller: _tokenExpiryCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: osDialogFieldDecoration(context).copyWith(
                labelText: AppLocaleKeys.osSettingsAlqasehTokenExpiry.tr,
              ),
            );
            if (narrow) {
              return Column(
                children: [
                  currencyField,
                  const SizedBox(height: kOsPaymentCredentialsFieldGap),
                  expiryField,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: currencyField),
                const SizedBox(width: 12),
                Expanded(child: expiryField),
              ],
            );
          },
        ),
        if (_environment == 'test') ...[
          const SizedBox(height: kOsPaymentCredentialsFieldGap),
          osPaymentCredentialsSandboxButton(
            context: context,
            onPressed: _applySandboxCredentials,
            label: AppLocaleKeys.osSettingsAlqasehUseSandbox.tr,
          ),
        ],
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osPaymentCredentialsSaveRow(
          context: context,
          saving: _saving,
          onSave: _save,
          label: AppLocaleKeys.osSettingsAlqasehSave.tr,
        ),
      ],
    );
  }
}
