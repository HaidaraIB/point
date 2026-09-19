import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsPaytabsSettingsStatus.dart';
import 'package:point/Services/os_paytabs_service.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsPaytabsSettingsPanel extends StatefulWidget {
  const OsPaytabsSettingsPanel({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<OsPaytabsSettingsPanel> createState() => _OsPaytabsSettingsPanelState();
}

class _OsPaytabsSettingsPanelState extends State<OsPaytabsSettingsPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _profileIdCtrl = TextEditingController();
  final _serverKeyCtrl = TextEditingController();
  final _clientKeyCtrl = TextEditingController();

  var _loading = true;
  var _saving = false;
  var _obscureServerKey = true;
  var _obscureClientKey = true;
  var _isEnabled = false;
  var _region = 'IRQ';
  var _currency = 'IQD';
  String? _defaultBankAccountId;
  OsPaytabsSettingsStatus _status = OsPaytabsSettingsStatus.empty();

  static const _regions = ['IRQ', 'ARE', 'SAU', 'EGY', 'JOR'];

  static const _regionCurrencies = <String, List<String>>{
    'IRQ': ['IQD', 'USD'],
    'ARE': ['AED', 'USD'],
    'SAU': ['SAR', 'USD'],
    'EGY': ['EGP', 'USD'],
    'JOR': ['JOD', 'USD'],
  };

  List<String> _currencyOptions() {
    final base = _regionCurrencies[_region] ?? _regionCurrencies['IRQ']!;
    if (base.contains(_currency)) return base;
    return [...base, _currency];
  }

  @override
  void initState() {
    super.initState();
    Get.find<OsFinanceController>();
    final cached = OsPaytabsService.instance.cachedSettings;
    if (cached != null) {
      _applyStatus(cached);
      _loading = false;
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _profileIdCtrl.dispose();
    _serverKeyCtrl.dispose();
    _clientKeyCtrl.dispose();
    super.dispose();
  }

  void _applyStatus(OsPaytabsSettingsStatus status) {
    _status = status;
    _profileIdCtrl.text = status.profileId;
    _region = status.region.isEmpty ? 'IRQ' : status.region;
    _currency = status.currency.isEmpty
        ? (_regionCurrencies[_region]?.first ?? 'IQD')
        : status.currency;
    _isEnabled = status.isEnabled;
    _defaultBankAccountId = status.defaultBankAccountId.isEmpty
        ? null
        : status.defaultBankAccountId;
    _serverKeyCtrl.clear();
    _clientKeyCtrl.clear();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await OsPaytabsService.instance.loadSettings(force: true);
      if (!mounted) return;
      setState(() => _applyStatus(status ?? OsPaytabsSettingsStatus.empty()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final profileId = _profileIdCtrl.text.trim();
    final currency = _currency;
    final bankId = _defaultBankAccountId?.trim() ?? '';

    if (_isEnabled) {
      if (profileId.isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsPaytabsSection.tr,
          AppLocaleKeys.osSettingsPaytabsProfileRequired.tr,
        );
        return;
      }
      if (!_status.hasServerKey && _serverKeyCtrl.text.trim().isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsPaytabsSection.tr,
          AppLocaleKeys.osSettingsPaytabsServerKeyRequired.tr,
        );
        return;
      }
      if (bankId.isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsPaytabsSection.tr,
          AppLocaleKeys.osSettingsPaytabsBankRequired.tr,
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final status = await OsPaytabsService.instance.saveSettings(
        profileId: profileId,
        serverKey: _serverKeyCtrl.text.trim().isEmpty
            ? null
            : _serverKeyCtrl.text.trim(),
        clientKey: _clientKeyCtrl.text.trim().isEmpty
            ? null
            : _clientKeyCtrl.text.trim(),
        region: _region,
        currency: currency.isEmpty ? 'IQD' : currency,
        isEnabled: _isEnabled,
        defaultBankAccountId: bankId,
      );
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsPaytabsSection.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _applyStatus(status));
      OsSnackbar.success(
        AppLocaleKeys.osSettingsPaytabsSection.tr,
        AppLocaleKeys.osSettingsPaytabsSaved.tr,
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
    final finance = Get.find<OsFinanceController>();
    final bankAccounts = finance.bankAccounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocaleKeys.osSettingsPaytabsDescription.tr,
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
              _status.isEnabled && _status.hasServerKey
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              size: 18,
              color: _status.isEnabled && _status.hasServerKey
                  ? const Color(0xFF059669)
                  : const Color(0xFFE11D48),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _status.isEnabled && _status.hasServerKey
                    ? AppLocaleKeys.osSettingsPaytabsConfigured.tr
                    : AppLocaleKeys.osSettingsPaytabsNotConfigured.tr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.primaryText,
                ),
              ),
            ),
          ],
        ),
        if (_status.hasServerKey && _status.serverKeyPreview.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            AppLocaleKeys.osSettingsPaytabsServerKeyPreview.trParams({
              'preview': _status.serverKeyPreview,
            }),
            style: TextStyle(fontSize: 12, color: theme.mutedText),
          ),
        ],
        const SizedBox(height: 16),
        _fieldLabel(context, AppLocaleKeys.osSettingsPaytabsProfileId.tr),
        const SizedBox(height: 8),
        osTypedTextField(
          controller: _profileIdCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: osDialogFieldDecoration(context).copyWith(
            hintText: AppLocaleKeys.osSettingsPaytabsProfileIdHint.tr,
          ),
        ),
        const SizedBox(height: 16),
        _fieldLabel(context, AppLocaleKeys.osSettingsPaytabsServerKey.tr),
        const SizedBox(height: 8),
        osTypedTextField(
          controller: _serverKeyCtrl,
          obscureText: _obscureServerKey,
          decoration: osDialogFieldDecoration(context).copyWith(
            hintText: AppLocaleKeys.osSettingsPaytabsServerKeyHint.tr,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureServerKey = !_obscureServerKey),
              icon: Icon(
                _obscureServerKey
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _fieldLabel(context, AppLocaleKeys.osSettingsPaytabsClientKey.tr),
        const SizedBox(height: 8),
        osTypedTextField(
          controller: _clientKeyCtrl,
          obscureText: _obscureClientKey,
          decoration: osDialogFieldDecoration(context).copyWith(
            hintText: AppLocaleKeys.osSettingsPaytabsClientKeyHint.tr,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureClientKey = !_obscureClientKey),
              icon: Icon(
                _obscureClientKey
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 640;
            final regionField = DropdownButtonFormField<String>(
              key: ValueKey(_region),
              initialValue: _region,
              decoration: osDialogFieldDecoration(context).copyWith(
                labelText: AppLocaleKeys.osSettingsPaytabsRegion.tr,
              ),
              items: [
                for (final r in _regions)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) {
                final nextRegion = v ?? 'IRQ';
                final options = _regionCurrencies[nextRegion] ??
                    _regionCurrencies['IRQ']!;
                setState(() {
                  _region = nextRegion;
                  if (!options.contains(_currency)) {
                    _currency = options.first;
                  }
                });
              },
            );
            final currencyField = DropdownButtonFormField<String>(
              key: ValueKey('$_region-$_currency'),
              initialValue: _currencyOptions().contains(_currency)
                  ? _currency
                  : _currencyOptions().first,
              decoration: osDialogFieldDecoration(context).copyWith(
                labelText: AppLocaleKeys.osSettingsPaytabsCurrency.tr,
              ),
              items: [
                for (final c in _currencyOptions())
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _currency = v ?? _currency),
            );
            if (narrow) {
              return Column(
                children: [
                  regionField,
                  const SizedBox(height: 12),
                  currencyField,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: regionField),
                const SizedBox(width: 12),
                Expanded(child: currencyField),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(_defaultBankAccountId),
          initialValue: _defaultBankAccountId,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsPaytabsDefaultAccount.tr,
          ),
          items: [
            for (final a in bankAccounts)
              DropdownMenuItem(
                value: a.id,
                child: Text(a.name),
              ),
          ],
          onChanged: (v) => setState(() => _defaultBankAccountId = v),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            AppLocaleKeys.osSettingsPaytabsEnabled.tr,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.primaryText,
            ),
          ),
          value: _isEnabled,
          onChanged: (v) => setState(() => _isEnabled = v),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: OsButtonStyles.primaryCompact(),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(AppLocaleKeys.osSettingsPaytabsSave.tr),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: context.appTheme.secondaryText,
      ),
    );
  }
}
