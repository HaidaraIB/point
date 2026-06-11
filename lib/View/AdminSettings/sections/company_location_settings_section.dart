import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/attendance_settings.dart';
import 'package:point/Services/location_helper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

class CompanyLocationSettingsSection extends StatefulWidget {
  const CompanyLocationSettingsSection({super.key});

  @override
  State<CompanyLocationSettingsSection> createState() =>
      _CompanyLocationSettingsSectionState();
}

class _CompanyLocationSettingsSectionState
    extends State<CompanyLocationSettingsSection> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _fetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await AttendanceSettings.load();
      _labelController.text = settings?.label ?? '';
      _latController.text = settings?.latitude.toString() ?? '';
      _lngController.text = settings?.longitude.toString() ?? '';
      _radiusController.text =
          settings?.radiusMeters.toString() ??
          AttendanceSettings.defaultRadiusMeters.toString();
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

  double? _parseDouble(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  bool get _hasValidCoordinates {
    final lat = _parseDouble(_latController.text);
    final lng = _parseDouble(_lngController.text);
    final radius = _parseDouble(_radiusController.text);
    return lat != null &&
        lng != null &&
        radius != null &&
        radius > 0 &&
        (lat != 0 || lng != 0);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final result = await LocationHelper.getCurrentPosition();
      if (!result.isSuccess) {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.adminSettingsLocationFetchFailed.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      final pos = result.position!;
      _latController.text = pos.latitude.toStringAsFixed(6);
      _lngController.text = pos.longitude.toStringAsFixed(6);
      setState(() {});
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final lat = _parseDouble(_latController.text)!;
    final lng = _parseDouble(_lngController.text)!;
    final radius = _parseDouble(_radiusController.text)!;

    setState(() => _saving = true);
    try {
      await AttendanceSettings.save(
        latitude: lat,
        longitude: lng,
        radiusMeters: radius,
        label: _labelController.text.trim(),
      );
      FunHelper.showSnackbar(
        'common.save'.tr,
        AppLocaleKeys.adminSettingsCompanyLocationSaveSuccess.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      setState(() {});
    } on FirebaseException catch (e, s) {
      appLog(
        'Company location settings save failed: ${e.code} ${e.message}',
        error: e,
        stackTrace: s,
      );
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
    } catch (e, s) {
      appLog('Company location settings save failed: $e', error: e, stackTrace: s);
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

  String? _validateCoordinate(String? value) {
    final parsed = _parseDouble(value);
    if (parsed == null || parsed < -180 || parsed > 180) {
      return AppLocaleKeys.adminSettingsInvalidCoordinate.tr;
    }
    return null;
  }

  String? _validateRadius(String? value) {
    final parsed = _parseDouble(value);
    if (parsed == null || parsed <= 0 || parsed > 5000) {
      return AppLocaleKeys.adminSettingsInvalidRadius.tr;
    }
    return null;
  }

  Widget _buildStatusBanner() {
    if (!_hasValidCoordinates) return const SizedBox.shrink();

    final label = _labelController.text.trim();
    final lat = _parseDouble(_latController.text)!;
    final lng = _parseDouble(_lngController.text)!;
    final radius = _parseDouble(_radiusController.text)!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.primaryfontColor,
                    ),
                  ),
                if (label.isNotEmpty) const SizedBox(height: 4),
                Text(
                  '${AppLocaleKeys.adminSettingsOfficeLatitude.tr}: ${lat.toStringAsFixed(6)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                Text(
                  '${AppLocaleKeys.adminSettingsOfficeLongitude.tr}: ${lng.toStringAsFixed(6)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                Text(
                  '${AppLocaleKeys.adminSettingsOfficeRadius.tr}: ${radius.round()}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateFields() {
    final latField = InputText(
      labelText: AppLocaleKeys.adminSettingsOfficeLatitude.tr,
      hintText: '0.0',
      controller: _latController,
      height: 42,
      fillColor: Colors.white,
      borderRadius: 5,
      borderColor: Colors.grey.shade300,
      textInputType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
      ],
      validator: _validateCoordinate,
      onchange: (_) {
        setState(() {});
        return null;
      },
    );

    final lngField = InputText(
      labelText: AppLocaleKeys.adminSettingsOfficeLongitude.tr,
      hintText: '0.0',
      controller: _lngController,
      height: 42,
      fillColor: Colors.white,
      borderRadius: 5,
      borderColor: Colors.grey.shade300,
      textInputType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
      ],
      validator: _validateCoordinate,
      onchange: (_) {
        setState(() {});
        return null;
      },
    );

    return Responsive(
      mobile: Column(
        children: [
          latField,
          const SizedBox(height: 12),
          lngField,
        ],
      ),
      desktop: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: latField),
          const SizedBox(width: 12),
          Expanded(child: lngField),
        ],
      ),
    );
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
                AppLocaleKeys.adminSettingsSectionCompanyLocation.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryfontColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleKeys.adminSettingsCompanyLocationHelp.tr,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              _buildStatusBanner(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InputText(
                      labelText: AppLocaleKeys.adminSettingsOfficeLabel.tr,
                      hintText: AppLocaleKeys.adminSettingsOfficeLabel.tr,
                      controller: _labelController,
                      height: 42,
                      fillColor: AppColors.greyBackground,
                      borderRadius: 5,
                      borderColor: Colors.grey.shade300,
                      onchange: (_) {
                        setState(() {});
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildCoordinateFields(),
                    const SizedBox(height: 12),
                    InputText(
                      labelText: AppLocaleKeys.adminSettingsOfficeRadius.tr,
                      hintText: AttendanceSettings.defaultRadiusMeters.toString(),
                      controller: _radiusController,
                      height: 42,
                      fillColor: AppColors.greyBackground,
                      borderRadius: 5,
                      borderColor: Colors.grey.shade300,
                      textInputType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateRadius,
                      onchange: (_) {
                        setState(() {});
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    MainButton(
                      title: AppLocaleKeys.adminSettingsUseCurrentLocation.tr,
                      load: _fetchingLocation,
                      height: 44,
                      borderSize: 8,
                      borderColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      fontColor: AppColors.primary,
                      onPressed: _fetchingLocation ? null : _useCurrentLocation,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              MainButton(
                title: 'common.save'.tr,
                load: _saving,
                height: 44,
                borderSize: 8,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
