import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsContractSettings.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsLegalContractsSettingsTab extends StatefulWidget {
  const OsLegalContractsSettingsTab({super.key, this.embedded = false});

  /// When true, renders as a non-scrolling column for [OsSettingsPage].
  final bool embedded;

  @override
  State<OsLegalContractsSettingsTab> createState() =>
      _OsLegalContractsSettingsTabState();
}

class _OsLegalContractsSettingsTabState
    extends State<OsLegalContractsSettingsTab> {
  late OsContractSettings _local;
  late final TextEditingController _legalNameCtrl;
  late final TextEditingController _signatoryCtrl;
  late final TextEditingController _signatoryTitleCtrl;
  late final TextEditingController _hqCtrl;
  late final TextEditingController _prefixCtrl;
  late final TextEditingController _jurisdictionCtrl;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final ctrl = Get.find<OsLegalContractsController>();
    _local = ctrl.settings.value;
    _legalNameCtrl = TextEditingController(text: _local.agencyLegalName);
    _signatoryCtrl =
        TextEditingController(text: _local.agencyAuthorizedSignatory);
    _signatoryTitleCtrl =
        TextEditingController(text: _local.agencySignatoryTitle);
    _hqCtrl = TextEditingController(text: _local.agencyHeadquarters);
    _prefixCtrl = TextEditingController(text: _local.contractNumberPrefix);
    _jurisdictionCtrl = TextEditingController(text: _local.defaultJurisdiction);
  }

  @override
  void dispose() {
    _legalNameCtrl.dispose();
    _signatoryCtrl.dispose();
    _signatoryTitleCtrl.dispose();
    _hqCtrl.dispose();
    _prefixCtrl.dispose();
    _jurisdictionCtrl.dispose();
    super.dispose();
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.appTheme.secondaryText,
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(label),
          TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: onChanged,
            decoration: osDialogFieldDecoration(context),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final ctrl = Get.find<OsLegalContractsController>();
    setState(() => _saving = true);
    try {
      final ok = await ctrl.saveSettings(_local);
      if (!mounted) return;
      if (ok) {
        OsSnackbar.success(
          AppLocaleKeys.osLegalContractTabSettings.tr,
          AppLocaleKeys.osLegalContractSettingsSaved.tr,
        );
      } else {
        OsSnackbar.error(
          AppLocaleKeys.osLegalContractTabSettings.tr,
          AppLocaleKeys.errorsOsLegalContractsSave.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    final children = <Widget>[
      if (!widget.embedded) ...[
        Text(
          AppLocaleKeys.osLegalContractSettingsAgency.tr,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: theme.primaryText,
          ),
        ),
        const SizedBox(height: 12),
      ],
      _field(
          AppLocaleKeys.osLegalContractSettingsLegalName.tr,
          _legalNameCtrl,
          (v) => _local = _local.copyWith(agencyLegalName: v),
        ),
        _field(
          AppLocaleKeys.osLegalContractSettingsSignatory.tr,
          _signatoryCtrl,
          (v) => _local = _local.copyWith(agencyAuthorizedSignatory: v),
        ),
        _field(
          AppLocaleKeys.osLegalContractSettingsSignatoryTitle.tr,
          _signatoryTitleCtrl,
          (v) => _local = _local.copyWith(agencySignatoryTitle: v),
        ),
        _field(
          AppLocaleKeys.osLegalContractSettingsHeadquarters.tr,
          _hqCtrl,
          (v) => _local = _local.copyWith(agencyHeadquarters: v),
          maxLines: 2,
        ),
        _field(
          AppLocaleKeys.osLegalContractSettingsPrefix.tr,
          _prefixCtrl,
          (v) => _local = _local.copyWith(contractNumberPrefix: v),
        ),
        _field(
          AppLocaleKeys.osLegalContractSettingsJurisdiction.tr,
          _jurisdictionCtrl,
          (v) => _local = _local.copyWith(defaultJurisdiction: v),
          maxLines: 2,
        ),
        SwitchListTile(
          title: Text(AppLocaleKeys.osLegalContractSettingsDigitalStamp.tr),
          value: _local.enableDigitalStamp,
          onChanged: (v) => setState(
            () => _local = _local.copyWith(enableDigitalStamp: v),
          ),
        ),
        const SizedBox(height: 8),
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
          label: Text(AppLocaleKeys.osLegalContractSettingsSave.tr),
        ),
    ];

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: children,
    );
  }
}
