import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/attendance_policy_settings.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';

class AttendancePolicySettingsSection extends StatefulWidget {
  const AttendancePolicySettingsSection({super.key});

  @override
  State<AttendancePolicySettingsSection> createState() =>
      _AttendancePolicySettingsSectionState();
}

class _AttendancePolicySettingsSectionState
    extends State<AttendancePolicySettingsSection> {
  final _formKey = GlobalKey<FormState>();
  final _checkInGraceController = TextEditingController();
  final _checkOutGraceController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _checkInGraceController.dispose();
    _checkOutGraceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await AttendancePolicySettings.load();
      _checkInGraceController.text = '${settings.checkInGraceMinutes}';
      _checkOutGraceController.text = '${settings.checkOutGraceMinutes}';
    } catch (_) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.adminSettingsLoadFailed.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateGrace(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) {
      return AppLocaleKeys.adminSettingsAttendanceGraceInvalid.tr;
    }
    if (parsed < AttendancePolicySettings.minGraceMinutes ||
        parsed > AttendancePolicySettings.maxGraceMinutes) {
      return AppLocaleKeys.adminSettingsAttendanceGraceRange.trParams({
        'min': '${AttendancePolicySettings.minGraceMinutes}',
        'max': '${AttendancePolicySettings.maxGraceMinutes}',
      });
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await AttendancePolicySettings.save(
        checkInGraceMinutes: int.parse(_checkInGraceController.text.trim()),
        checkOutGraceMinutes: int.parse(_checkOutGraceController.text.trim()),
      );
      FunHelper.showSnackbar(
        'common.confirm'.tr,
        AppLocaleKeys.adminSettingsAttendancePolicySaveSuccess.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on FirebaseException catch (e) {
      final message = e.code == 'permission-denied'
          ? AppLocaleKeys.adminSettingsSavePermissionDenied.tr
          : AppLocaleKeys.adminSettingsSaveFailed.tr;
      FunHelper.showSnackbar(
        'error'.tr,
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.adminSettingsSaveFailed.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocaleKeys.adminSettingsSectionAttendancePolicy.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocaleKeys.adminSettingsAttendancePolicyHelp.tr,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              InputText(
                labelText: AppLocaleKeys.adminSettingsCheckInGraceMinutes.tr,
                hintText: '${AttendancePolicySettings.defaultGraceMinutes}',
                height: 42,
                fillColor: Colors.white,
                controller: _checkInGraceController,
                borderRadius: 5,
                borderColor: Colors.grey.shade300,
                textInputType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateGrace,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleKeys.adminSettingsCheckInGraceHelp.tr,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 16),
              InputText(
                labelText: AppLocaleKeys.adminSettingsCheckOutGraceMinutes.tr,
                hintText: '${AttendancePolicySettings.defaultGraceMinutes}',
                height: 42,
                fillColor: Colors.white,
                controller: _checkOutGraceController,
                borderRadius: 5,
                borderColor: Colors.grey.shade300,
                textInputType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateGrace,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleKeys.adminSettingsCheckOutGraceHelp.tr,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 24),
              MainButton(
                title: 'common.save'.tr,
                height: 48,
                borderSize: 8,
                load: _saving,
                enabled: !_saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
