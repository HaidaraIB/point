import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsActiveCardProviderStatus.dart';
import 'package:point/Services/os_card_payment_service.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsCardProviderSelector extends StatefulWidget {
  const OsCardProviderSelector({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<OsCardProviderSelector> createState() => _OsCardProviderSelectorState();
}

class _OsCardProviderSelectorState extends State<OsCardProviderSelector>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  var _loading = true;
  var _saving = false;
  var _provider = 'none';
  String? _defaultBankAccountId;
  OsActiveCardProviderStatus _status = OsActiveCardProviderStatus.empty();

  @override
  void initState() {
    super.initState();
    Get.find<OsFinanceController>();
    final cached = OsCardPaymentService.instance.cachedActive;
    if (cached != null) {
      _applyStatus(cached);
      _loading = false;
      return;
    }
    _load();
  }

  void _applyStatus(OsActiveCardProviderStatus status) {
    _status = status;
    _provider = status.provider.isEmpty ? 'none' : status.provider;
    _defaultBankAccountId = status.defaultBankAccountId.isEmpty
        ? null
        : status.defaultBankAccountId;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status =
          await OsCardPaymentService.instance.loadActiveProvider(force: true);
      if (!mounted) return;
      setState(() => _applyStatus(status ?? OsActiveCardProviderStatus.empty()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final bankId = _defaultBankAccountId?.trim() ?? '';
    if (_provider != 'none' && bankId.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osSettingsCardProviderSection.tr,
        AppLocaleKeys.osSettingsCardProviderBankRequired.tr,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final status = await OsCardPaymentService.instance.setActiveProvider(
        provider: _provider,
        defaultBankAccountId: bankId,
      );
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsCardProviderSection.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _applyStatus(status));
      OsSnackbar.success(
        AppLocaleKeys.osSettingsCardProviderSection.tr,
        AppLocaleKeys.osSettingsCardProviderSaved.tr,
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
          AppLocaleKeys.osSettingsCardProviderDescription.tr,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppLocaleKeys.osSettingsCardProviderLabel.tr,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'none',
              label: Text(AppLocaleKeys.osSettingsCardProviderNone.tr),
            ),
            ButtonSegment(
              value: 'paytabs',
              label: Text(AppLocaleKeys.osSettingsCardProviderPaytabs.tr),
            ),
            ButtonSegment(
              value: 'alqaseh',
              label: Text(AppLocaleKeys.osSettingsCardProviderAlqaseh.tr),
            ),
          ],
          selected: {_provider},
          onSelectionChanged: (values) {
            setState(() => _provider = values.first);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(_defaultBankAccountId),
          initialValue: _defaultBankAccountId,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsCardProviderDefaultAccount.tr,
          ),
          items: [
            for (final a in bankAccounts)
              DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: _provider == 'none'
              ? null
              : (v) => setState(() => _defaultBankAccountId = v),
        ),
        if (_status.isEnabled) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: const Color(0xFF059669),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleKeys.osSettingsCardProviderActive.trParams({
                    'provider': _status.provider == 'paytabs'
                        ? AppLocaleKeys.osSettingsCardProviderPaytabs.tr
                        : AppLocaleKeys.osSettingsCardProviderAlqaseh.tr,
                  }),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
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
            label: Text(AppLocaleKeys.osSettingsCardProviderSave.tr),
          ),
        ),
      ],
    );
  }
}
