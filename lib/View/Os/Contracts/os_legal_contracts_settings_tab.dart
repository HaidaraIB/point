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
  late final TextEditingController _commercialRegCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _signatoryCtrl;
  late final TextEditingController _signatoryTitleCtrl;
  late final TextEditingController _hqCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _jurisdictionCtrl;
  late final TextEditingController _laborRefCtrl;
  late final TextEditingController _civilRefCtrl;
  late final TextEditingController _copyrightRefCtrl;
  late final TextEditingController _probationCtrl;
  late final TextEditingController _workHoursCtrl;
  late final TextEditingController _annualLeaveCtrl;
  late final TextEditingController _penaltyCtrl;
  late final TextEditingController _prefixCtrl;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final ctrl = Get.find<OsLegalContractsController>();
    _local = ctrl.settings.value;
    _legalNameCtrl = TextEditingController(text: _local.agencyLegalName);
    _commercialRegCtrl =
        TextEditingController(text: _local.agencyCommercialReg);
    _taxCtrl = TextEditingController(text: _local.agencyTaxNumber);
    _signatoryCtrl =
        TextEditingController(text: _local.agencyAuthorizedSignatory);
    _signatoryTitleCtrl =
        TextEditingController(text: _local.agencySignatoryTitle);
    _hqCtrl = TextEditingController(text: _local.agencyHeadquarters);
    _phoneCtrl = TextEditingController(text: _local.agencyPhone);
    _emailCtrl = TextEditingController(text: _local.agencyEmail);
    _jurisdictionCtrl = TextEditingController(text: _local.defaultJurisdiction);
    _laborRefCtrl = TextEditingController(text: _local.defaultLaborLawRef);
    _civilRefCtrl = TextEditingController(text: _local.defaultCivilLawRef);
    _copyrightRefCtrl =
        TextEditingController(text: _local.defaultCopyrightLawRef);
    _probationCtrl =
        TextEditingController(text: '${_local.defaultProbationDays}');
    _workHoursCtrl =
        TextEditingController(text: '${_local.defaultWorkHoursWeekly}');
    _annualLeaveCtrl =
        TextEditingController(text: '${_local.defaultAnnualLeaveDays}');
    _penaltyCtrl =
        TextEditingController(text: '${_local.defaultLatePenaltyRate}');
    _prefixCtrl = TextEditingController(text: _local.contractNumberPrefix);
  }

  @override
  void dispose() {
    _legalNameCtrl.dispose();
    _commercialRegCtrl.dispose();
    _taxCtrl.dispose();
    _signatoryCtrl.dispose();
    _signatoryTitleCtrl.dispose();
    _hqCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _jurisdictionCtrl.dispose();
    _laborRefCtrl.dispose();
    _civilRefCtrl.dispose();
    _copyrightRefCtrl.dispose();
    _probationCtrl.dispose();
    _workHoursCtrl.dispose();
    _annualLeaveCtrl.dispose();
    _penaltyCtrl.dispose();
    _prefixCtrl.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          color: context.appTheme.primaryText,
        ),
      ),
    );
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
    TextInputType? keyboardType,
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
            keyboardType: keyboardType,
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
    final children = <Widget>[
      _sectionTitle(AppLocaleKeys.osLegalContractSettingsAgency.tr),
      _field(
        AppLocaleKeys.osLegalContractSettingsLegalName.tr,
        _legalNameCtrl,
        (v) => _local = _local.copyWith(agencyLegalName: v),
      ),
      LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 640;
          final left = [
            _field(
              AppLocaleKeys.osLegalContractSettingsCommercialReg.tr,
              _commercialRegCtrl,
              (v) => _local = _local.copyWith(agencyCommercialReg: v),
            ),
            _field(
              AppLocaleKeys.osLegalContractSettingsSignatory.tr,
              _signatoryCtrl,
              (v) => _local = _local.copyWith(agencyAuthorizedSignatory: v),
            ),
            _field(
              AppLocaleKeys.osLegalContractSettingsHeadquarters.tr,
              _hqCtrl,
              (v) => _local = _local.copyWith(agencyHeadquarters: v),
              maxLines: 2,
            ),
          ];
          final right = [
            _field(
              AppLocaleKeys.osLegalContractSettingsTax.tr,
              _taxCtrl,
              (v) => _local = _local.copyWith(agencyTaxNumber: v),
            ),
            _field(
              AppLocaleKeys.osLegalContractSettingsSignatoryTitle.tr,
              _signatoryTitleCtrl,
              (v) => _local = _local.copyWith(agencySignatoryTitle: v),
            ),
            _field(
              AppLocaleKeys.osLegalContractSettingsPhone.tr,
              _phoneCtrl,
              (v) => _local = _local.copyWith(agencyPhone: v),
            ),
            _field(
              AppLocaleKeys.osLegalContractSettingsEmail.tr,
              _emailCtrl,
              (v) => _local = _local.copyWith(agencyEmail: v),
            ),
          ];
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: left)),
                const SizedBox(width: 12),
                Expanded(child: Column(children: right)),
              ],
            );
          }
          return Column(children: [...left, ...right]);
        },
      ),
      const SizedBox(height: 8),
      _sectionTitle(AppLocaleKeys.osLegalContractSettingsLegalRefs.tr),
      _field(
        AppLocaleKeys.osLegalContractSettingsJurisdiction.tr,
        _jurisdictionCtrl,
        (v) => _local = _local.copyWith(defaultJurisdiction: v),
        maxLines: 2,
      ),
      _field(
        AppLocaleKeys.osLegalContractSettingsLaborRef.tr,
        _laborRefCtrl,
        (v) => _local = _local.copyWith(defaultLaborLawRef: v),
        maxLines: 2,
      ),
      _field(
        AppLocaleKeys.osLegalContractSettingsCivilRef.tr,
        _civilRefCtrl,
        (v) => _local = _local.copyWith(defaultCivilLawRef: v),
        maxLines: 2,
      ),
      _field(
        AppLocaleKeys.osLegalContractSettingsCopyrightRef.tr,
        _copyrightRefCtrl,
        (v) => _local = _local.copyWith(defaultCopyrightLawRef: v),
        maxLines: 2,
      ),
      const SizedBox(height: 8),
      _sectionTitle(AppLocaleKeys.osLegalContractSettingsDefaults.tr),
      LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 720;
          final fields = [
            _field(
              AppLocaleKeys.osLegalContractSettingsProbation.tr,
              _probationCtrl,
              (v) => _local = _local.copyWith(
                defaultProbationDays: int.tryParse(v) ?? _local.defaultProbationDays,
              ),
              keyboardType: TextInputType.number,
            ),
            _field(
              AppLocaleKeys.osLegalContractSettingsWorkHours.tr,
              _workHoursCtrl,
              (v) => _local = _local.copyWith(
                defaultWorkHoursWeekly:
                    int.tryParse(v) ?? _local.defaultWorkHoursWeekly,
              ),
              keyboardType: TextInputType.number,
            ),
            _field(
              AppLocaleKeys.osLegalContractSettingsAnnualLeave.tr,
              _annualLeaveCtrl,
              (v) => _local = _local.copyWith(
                defaultAnnualLeaveDays:
                    int.tryParse(v) ?? _local.defaultAnnualLeaveDays,
              ),
              keyboardType: TextInputType.number,
            ),
            _field(
              AppLocaleKeys.osLegalContractSettingsLatePenalty.tr,
              _penaltyCtrl,
              (v) => _local = _local.copyWith(
                defaultLatePenaltyRate:
                    double.tryParse(v) ?? _local.defaultLatePenaltyRate,
              ),
              keyboardType: TextInputType.number,
            ),
            _field(
              AppLocaleKeys.osLegalContractSettingsPrefix.tr,
              _prefixCtrl,
              (v) => _local = _local.copyWith(contractNumberPrefix: v),
            ),
          ];
          if (wide) {
            return Wrap(
              spacing: 12,
              runSpacing: 0,
              children: fields
                  .map((w) => SizedBox(width: (c.maxWidth - 24) / 2, child: w))
                  .toList(),
            );
          }
          return Column(children: fields);
        },
      ),
      SwitchListTile(
        title: Text(AppLocaleKeys.osLegalContractSettingsDigitalStamp.tr),
        value: _local.enableDigitalStamp,
        onChanged: (v) => setState(
          () => _local = _local.copyWith(enableDigitalStamp: v),
        ),
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
              : const Icon(Icons.check, size: 18),
          label: Text(AppLocaleKeys.osLegalContractSaveLegalSettings.tr),
        ),
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
