import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsGeneralSettingsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsGeneralSettings.dart';
import 'package:point/Utils/AppFonts.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/Utils/whatsapp_phone.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/phone_number_text.dart';
import 'package:point/View/Shared/whatsapp_phone_field.dart';

/// Editable agency contact lines used on invoice / voucher print headers.
class OsPrintContactSettingsPanel extends StatefulWidget {
  const OsPrintContactSettingsPanel({super.key});

  @override
  State<OsPrintContactSettingsPanel> createState() =>
      _OsPrintContactSettingsPanelState();
}

class _OsPrintContactSettingsPanelState
    extends State<OsPrintContactSettingsPanel> {
  final _addressArCtrl = TextEditingController();
  final _addressEnCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  var _saving = false;
  var _dirty = false;
  Worker? _settingsWorker;

  OsGeneralSettingsController get _ctrl =>
      Get.find<OsGeneralSettingsController>();

  @override
  void initState() {
    super.initState();
    _syncFromController();
    _settingsWorker = ever(_ctrl.settings, (_) {
      if (!_dirty && mounted) setState(_syncFromController);
    });
  }

  @override
  void dispose() {
    _settingsWorker?.dispose();
    _addressArCtrl.dispose();
    _addressEnCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  void _syncFromController() {
    final s = _ctrl.settings.value;
    _addressArCtrl.text = s.printAddressAr;
    _addressEnCtrl.text = s.printAddressEn;
    _phoneCtrl.text = s.printPhone;
    _emailCtrl.text = s.printEmail;
    _websiteCtrl.text = s.printWebsite;
  }

  OsGeneralSettings get _draft => OsGeneralSettings(
        usdToIqdRate: _ctrl.usdToIqdRate,
        printAddressAr: _addressArCtrl.text,
        printAddressEn: _addressEnCtrl.text,
        printPhone: _phoneCtrl.text,
        printEmail: _emailCtrl.text,
        printWebsite: _websiteCtrl.text,
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final ok = await _ctrl.savePrintContact(
        addressAr: _addressArCtrl.text,
        addressEn: _addressEnCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        website: _websiteCtrl.text,
      );
      if (!mounted) return;
      if (!ok) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsPrintContactSection.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _dirty = false);
      _syncFromController();
      OsSnackbar.success(
        AppLocaleKeys.osSettingsPrintContactSection.tr,
        AppLocaleKeys.osSettingsPrintContactSaved.tr,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onChanged() => setState(() => _dirty = true);

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocaleKeys.osSettingsPrintContactDescription.tr,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 860;
            final fields = _fields(theme);
            final previews = _previews(theme);
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  fields,
                  const SizedBox(height: 16),
                  previews,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: fields),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: previews),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
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
            label: Text(AppLocaleKeys.osSettingsPrintContactSave.tr),
          ),
        ),
      ],
    );
  }

  Widget _fields(AppThemeExtension theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _labeledField(
          theme,
          AppLocaleKeys.osSettingsPrintContactAddressAr.tr,
          _addressArCtrl,
          hint: OsGeneralSettings.defaultPrintAddressAr,
        ),
        const SizedBox(height: 12),
        _labeledField(
          theme,
          AppLocaleKeys.osSettingsPrintContactAddressEn.tr,
          _addressEnCtrl,
          hint: OsGeneralSettings.defaultPrintAddressEn,
        ),
        const SizedBox(height: 12),
        WhatsappPhoneField(
          initialNormalized: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsPrintContactPhone.tr,
          ),
          onChanged: (v) {
            _phoneCtrl.text = v ?? '';
            _onChanged();
          },
        ),
        const SizedBox(height: 12),
        _labeledField(
          theme,
          AppLocaleKeys.osSettingsPrintContactEmail.tr,
          _emailCtrl,
          hint: OsGeneralSettings.defaultPrintEmail,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _labeledField(
          theme,
          AppLocaleKeys.osSettingsPrintContactWebsite.tr,
          _websiteCtrl,
          hint: OsGeneralSettings.defaultPrintWebsite,
          keyboard: TextInputType.url,
        ),
      ],
    );
  }

  Widget _labeledField(
    AppThemeExtension theme,
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        osTypedTextField(
          controller: controller,
          keyboardType: keyboard,
          onChanged: (_) => _onChanged(),
          hintText: hint,
          decoration:
              osDialogFieldDecoration(context).copyWith(hintText: hint),
        ),
      ],
    );
  }

  Widget _previews(AppThemeExtension theme) {
    return _previewCard(
      theme,
      title: AppLocaleKeys.osSettingsPrintContactPreview.tr,
      child: OsPrintContactPreview(settings: _draft),
    );
  }

  Widget _previewCard(
    AppThemeExtension theme, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// On-screen stand-in for the print HTML contact block.
class OsPrintContactPreview extends StatelessWidget {
  const OsPrintContactPreview({
    super.key,
    required this.settings,
  });

  final OsGeneralSettings settings;

  static const _navy = Color(0xFF2B2A6B);

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    final addressAr = settings.printAddressAr.trim();
    final addressEn = settings.printAddressEn.trim();
    if (addressAr.isNotEmpty || addressEn.isNotEmpty) {
      rows.add(
        _row(
          Icons.location_on,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (addressAr.isNotEmpty)
                Text(
                  addressAr,
                  textAlign: TextAlign.left,
                  textDirection: TextDirection.ltr,
                  style: Appfonts.text(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    height: 1.2,
                  ),
                ),
              if (addressEn.isNotEmpty)
                Text(
                  addressEn,
                  style: Appfonts.text(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    void addLine(IconData icon, String value, {bool phone = false}) {
      final text = value.trim();
      if (text.isEmpty) return;
      final style = Appfonts.text(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: _navy,
      );
      rows.add(
        _row(
          icon,
          phone
              ? PhoneNumberText(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                )
              : Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
        ),
      );
    }

    addLine(
      Icons.phone,
      formatWhatsappPhoneDisplay(settings.printPhone),
      phone: true,
    );
    addLine(Icons.email, settings.printEmail);
    addLine(Icons.public, settings.printWebsite);

    if (rows.isEmpty) return const SizedBox(height: 48);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          rows[i],
        ],
      ],
    );
  }

  Widget _row(IconData icon, Widget text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: _navy),
        const SizedBox(width: 8),
        Expanded(child: text),
      ],
    );
  }
}
