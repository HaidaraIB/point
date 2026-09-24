import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsZaincashSettingsStatus.dart';
import 'package:point/Services/os_zaincash_service.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Settings/os_payment_credentials_form.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsZaincashSettingsPanel extends StatefulWidget {
  const OsZaincashSettingsPanel({
    super.key,
    this.embedded = false,
    this.compact = false,
    this.onSettingsSaved,
  });

  final bool embedded;
  final bool compact;
  final ValueChanged<OsZaincashSettingsStatus>? onSettingsSaved;

  @override
  State<OsZaincashSettingsPanel> createState() =>
      _OsZaincashSettingsPanelState();
}

class _OsZaincashSettingsPanelState extends State<OsZaincashSettingsPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _clientIdCtrl = TextEditingController();
  final _clientSecretCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _serviceTypeCtrl = TextEditingController();
  final _liveApiBaseCtrl = TextEditingController();

  var _loading = true;
  var _saving = false;
  var _obscureSecret = true;
  var _obscureApiKey = true;
  var _environment = 'test';
  OsZaincashSettingsStatus _status = OsZaincashSettingsStatus.empty();

  static const _liveApiDefault = 'https://pg-api.zaincash.iq';

  /// Public UAT merchant credentials from ZainCash Payment Gateway v2 docs.
  static const _uatClientId = '758055f4a8044779a35f6ceb69f858b3';
  static const _uatClientSecret = 'bibLCGTxVAig5To3OLLKPJQMlRR7Pefp';

  @override
  void initState() {
    super.initState();
    final cached = OsZaincashService.instance.cachedSettings;
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
    _apiKeyCtrl.dispose();
    _serviceTypeCtrl.dispose();
    _liveApiBaseCtrl.dispose();
    super.dispose();
  }

  void _applyStatus(OsZaincashSettingsStatus status) {
    _status = status;
    _environment = status.environment.isEmpty ? 'test' : status.environment;
    _clientIdCtrl.text = status.clientId;
    _serviceTypeCtrl.text =
        status.serviceType.isEmpty ? 'Invoice' : status.serviceType;
    _liveApiBaseCtrl.text = status.liveApiBase.isEmpty
        ? _liveApiDefault
        : status.liveApiBase;
    _clientSecretCtrl.clear();
    _apiKeyCtrl.clear();
  }

  void _applySandboxCredentials() {
    setState(() {
      _environment = 'test';
      _clientIdCtrl.text = _uatClientId;
      _clientSecretCtrl.text = _uatClientSecret;
      _serviceTypeCtrl.text = 'Invoice';
      _apiKeyCtrl.clear();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await OsZaincashService.instance.loadSettings(force: true);
      if (!mounted) return;
      setState(() =>
          _applyStatus(status ?? OsZaincashSettingsStatus.empty()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final status = await OsZaincashService.instance.saveSettings(
        environment: _environment,
        clientId: _clientIdCtrl.text.trim(),
        clientSecret: _clientSecretCtrl.text.trim().isEmpty
            ? null
            : _clientSecretCtrl.text.trim(),
        apiKey: _apiKeyCtrl.text.trim().isEmpty
            ? null
            : _apiKeyCtrl.text.trim(),
        serviceType: _serviceTypeCtrl.text.trim(),
        liveApiBase: _environment == 'live'
            ? (_liveApiBaseCtrl.text.trim().isEmpty
                ? _liveApiDefault
                : _liveApiBaseCtrl.text.trim())
            : null,
      );
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsZaincashSection.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _applyStatus(status));
      widget.onSettingsSaved?.call(status);
      OsSnackbar.success(
        AppLocaleKeys.osSettingsZaincashSection.tr,
        AppLocaleKeys.osSettingsZaincashSaved.tr,
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
    final configured = _status.hasClientSecret &&
        _status.clientId.isNotEmpty &&
        _status.configuredInFirestore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Text(
            AppLocaleKeys.osSettingsZaincashDescription.tr,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            configured
                ? AppLocaleKeys.osSettingsZaincashConfigured.tr
                : AppLocaleKeys.osSettingsZaincashNotConfigured.tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color:
                  configured ? const Color(0xFF059669) : theme.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
        ] else if (_status.clientSecretPreview.isNotEmpty) ...[
          osPaymentCredentialsSecretPreview(
            context,
            AppLocaleKeys.osSettingsZaincashClientSecretPreview.trParams({
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
            final status = await OsZaincashService.instance.loadSettings(
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
            labelText: AppLocaleKeys.osSettingsZaincashClientId.tr,
          ),
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _clientSecretCtrl,
          obscureText: _obscureSecret,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsZaincashClientSecret.tr,
            hintText: AppLocaleKeys.osSettingsZaincashClientSecretHint.tr,
            suffixIcon: osPaymentCredentialsObscureToggle(
              obscure: _obscureSecret,
              onToggle: () =>
                  setState(() => _obscureSecret = !_obscureSecret),
            ),
          ),
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _apiKeyCtrl,
          obscureText: _obscureApiKey,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsZaincashApiKey.tr,
            hintText: AppLocaleKeys.osSettingsZaincashApiKeyHint.tr,
            suffixIcon: osPaymentCredentialsObscureToggle(
              obscure: _obscureApiKey,
              onToggle: () =>
                  setState(() => _obscureApiKey = !_obscureApiKey),
            ),
          ),
        ),
        if (_status.hasApiKey) ...[
          const SizedBox(height: 8),
          Text(
            AppLocaleKeys.osSettingsZaincashApiKeyConfigured.tr,
            style: TextStyle(fontSize: 12, color: theme.secondaryText),
          ),
        ],
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _serviceTypeCtrl,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsZaincashServiceType.tr,
          ),
        ),
        if (_environment == 'live') ...[
          const SizedBox(height: kOsPaymentCredentialsFieldGap),
          osTypedTextField(
            controller: _liveApiBaseCtrl,
            decoration: osDialogFieldDecoration(context).copyWith(
              labelText: AppLocaleKeys.osSettingsZaincashLiveApiBase.tr,
              hintText: AppLocaleKeys.osSettingsZaincashLiveApiBaseHint.tr,
            ),
          ),
        ],
        if (_environment == 'test') ...[
          const SizedBox(height: kOsPaymentCredentialsFieldGap),
          osPaymentCredentialsSandboxButton(
            context: context,
            onPressed: _applySandboxCredentials,
            label: AppLocaleKeys.osSettingsZaincashUseSandbox.tr,
          ),
        ],
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osPaymentCredentialsSaveRow(
          context: context,
          saving: _saving,
          onSave: _save,
          label: AppLocaleKeys.osSettingsZaincashSave.tr,
        ),
      ],
    );
  }
}
