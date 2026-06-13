import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeAttendanceLocation.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/location_helper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

/// Helpers for employee attendance location + work hours form fields.
class EmployeeAttendanceFormData {
  EmployeeAttendanceFormData._();

  static String formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static TimeOfDay? parseTime(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static EmployeeAttendanceLocation? locationFromControllers({
    required TextEditingController labelController,
    required TextEditingController latController,
    required TextEditingController lngController,
    required TextEditingController radiusController,
  }) {
    final lat = double.tryParse(latController.text.trim());
    final lng = double.tryParse(lngController.text.trim());
    final radius = double.tryParse(radiusController.text.trim());
    if (lat == null || lng == null || radius == null) return null;
    if (lat == 0 && lng == 0) return null;
    return EmployeeAttendanceLocation(
      latitude: lat,
      longitude: lng,
      radiusMeters: radius,
      label: labelController.text.trim().isEmpty
          ? null
          : labelController.text.trim(),
    );
  }

  static void populateFromEmployee({
    required EmployeeModel? employee,
    required TextEditingController labelController,
    required TextEditingController latController,
    required TextEditingController lngController,
    required TextEditingController radiusController,
  }) {
    final loc = employee?.attendanceLocation;
    labelController.text = loc?.label ?? '';
    latController.text = loc?.latitude.toString() ?? '';
    lngController.text = loc?.longitude.toString() ?? '';
    radiusController.text =
        loc?.radiusMeters.toString() ??
        EmployeeAttendanceLocation.defaultRadiusMeters.toString();
  }

  static String? validateWorkHours(TimeOfDay? from, TimeOfDay? to) {
    if (from == null && to == null) return null;
    if (from == null || to == null) {
      return AppLocaleKeys.attendanceWorkHoursBothRequired.tr;
    }
    final fromMinutes = from.hour * 60 + from.minute;
    final toMinutes = to.hour * 60 + to.minute;
    if (fromMinutes >= toMinutes) {
      return AppLocaleKeys.attendanceWorkHoursInvalidRange.tr;
    }
    return null;
  }
}

/// Branch location + work hours fields for employee add/edit forms.
class EmployeeAttendanceConfigFields extends StatefulWidget {
  const EmployeeAttendanceConfigFields({
    super.key,
    required this.labelController,
    required this.latController,
    required this.lngController,
    required this.radiusController,
    required this.workFrom,
    required this.workTo,
    required this.onWorkFromChanged,
    required this.onWorkToChanged,
    required this.attendanceRemote,
    required this.onAttendanceRemoteChanged,
  });

  final TextEditingController labelController;
  final TextEditingController latController;
  final TextEditingController lngController;
  final TextEditingController radiusController;
  final TimeOfDay? workFrom;
  final TimeOfDay? workTo;
  final ValueChanged<TimeOfDay?> onWorkFromChanged;
  final ValueChanged<TimeOfDay?> onWorkToChanged;
  final bool attendanceRemote;
  final ValueChanged<bool> onAttendanceRemoteChanged;

  @override
  State<EmployeeAttendanceConfigFields> createState() =>
      _EmployeeAttendanceConfigFieldsState();
}

class _EmployeeAttendanceConfigFieldsState
    extends State<EmployeeAttendanceConfigFields> {
  bool _fetchingLocation = false;

  double? _parseDouble(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
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
      widget.latController.text = pos.latitude.toStringAsFixed(6);
      widget.lngController.text = pos.longitude.toStringAsFixed(6);
      setState(() {});
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _pickTime({
    required TimeOfDay? initial,
    required ValueChanged<TimeOfDay?> onChanged,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) onChanged(picked);
  }

  Widget _timeField({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    final display = value == null
        ? AppLocaleKeys.attendanceSelectTime.tr
        : EmployeeAttendanceFormData.formatTimeOfDay(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.grey.shade300, width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    display,
                    style: TextStyle(
                      fontSize: 13,
                      color: value == null
                          ? AppColors.primaryfontColor
                          : AppColors.primaryfontColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.access_time, size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationFields = Opacity(
      opacity: widget.attendanceRemote ? 0.45 : 1,
      child: IgnorePointer(
        ignoring: widget.attendanceRemote,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocaleKeys.attendanceEmployeeLocationTitle.tr,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.primaryfontColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocaleKeys.attendanceEmployeeLocationHelp.tr,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
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
                    controller: widget.labelController,
                    height: 42,
                    fillColor: AppColors.greyBackground,
                    borderRadius: 5,
                    borderColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Responsive(
                    mobile: Column(
                      children: [
                        InputText(
                          labelText: AppLocaleKeys.adminSettingsOfficeLatitude.tr,
                          hintText: '0.0',
                          controller: widget.latController,
                          height: 42,
                          fillColor: AppColors.greyBackground,
                          borderRadius: 5,
                          borderColor: Colors.grey.shade300,
                          textInputType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*\.?\d*'),
                            ),
                          ],
                          validator: widget.attendanceRemote
                              ? null
                              : _validateCoordinate,
                        ),
                        const SizedBox(height: 12),
                        InputText(
                          labelText: AppLocaleKeys.adminSettingsOfficeLongitude.tr,
                          hintText: '0.0',
                          controller: widget.lngController,
                          height: 42,
                          fillColor: AppColors.greyBackground,
                          borderRadius: 5,
                          borderColor: Colors.grey.shade300,
                          textInputType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*\.?\d*'),
                            ),
                          ],
                          validator: widget.attendanceRemote
                              ? null
                              : _validateCoordinate,
                        ),
                      ],
                    ),
                    desktop: Row(
                      children: [
                        Expanded(
                          child: InputText(
                            labelText: AppLocaleKeys.adminSettingsOfficeLatitude.tr,
                            hintText: '0.0',
                            controller: widget.latController,
                            height: 42,
                            fillColor: AppColors.greyBackground,
                            borderRadius: 5,
                            borderColor: Colors.grey.shade300,
                            textInputType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^-?\d*\.?\d*'),
                              ),
                            ],
                            validator: widget.attendanceRemote
                                ? null
                                : _validateCoordinate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InputText(
                            labelText: AppLocaleKeys.adminSettingsOfficeLongitude.tr,
                            hintText: '0.0',
                            controller: widget.lngController,
                            height: 42,
                            fillColor: AppColors.greyBackground,
                            borderRadius: 5,
                            borderColor: Colors.grey.shade300,
                            textInputType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^-?\d*\.?\d*'),
                              ),
                            ],
                            validator: widget.attendanceRemote
                                ? null
                                : _validateCoordinate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputText(
                    labelText: AppLocaleKeys.adminSettingsOfficeRadius.tr,
                    hintText: EmployeeAttendanceLocation.defaultRadiusMeters
                        .toString(),
                    controller: widget.radiusController,
                    height: 42,
                    fillColor: AppColors.greyBackground,
                    borderRadius: 5,
                    borderColor: Colors.grey.shade300,
                    textInputType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: widget.attendanceRemote ? null : _validateRadius,
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
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            AppLocaleKeys.attendanceRemoteEmployee.tr,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primaryfontColor,
            ),
          ),
          subtitle: Text(
            AppLocaleKeys.attendanceRemoteEmployeeHelp.tr,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          value: widget.attendanceRemote,
          activeThumbColor: AppColors.primary,
          onChanged: widget.onAttendanceRemoteChanged,
        ),
        const SizedBox(height: 12),
        locationFields,
        const SizedBox(height: 20),
        Text(
          AppLocaleKeys.attendanceWorkHoursTitle.tr,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.primaryfontColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppLocaleKeys.attendanceWorkHoursHelp.tr,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Responsive(
          mobile: Column(
            children: [
              _timeField(
                label: AppLocaleKeys.attendanceWorkHoursFrom.tr,
                value: widget.workFrom,
                onTap: () => _pickTime(
                  initial: widget.workFrom,
                  onChanged: widget.onWorkFromChanged,
                ),
              ),
              const SizedBox(height: 12),
              _timeField(
                label: AppLocaleKeys.attendanceWorkHoursTo.tr,
                value: widget.workTo,
                onTap: () => _pickTime(
                  initial: widget.workTo,
                  onChanged: widget.onWorkToChanged,
                ),
              ),
            ],
          ),
          desktop: Row(
            children: [
              Expanded(
                child: _timeField(
                  label: AppLocaleKeys.attendanceWorkHoursFrom.tr,
                  value: widget.workFrom,
                  onTap: () => _pickTime(
                    initial: widget.workFrom,
                    onChanged: widget.onWorkFromChanged,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeField(
                  label: AppLocaleKeys.attendanceWorkHoursTo.tr,
                  value: widget.workTo,
                  onTap: () => _pickTime(
                    initial: widget.workTo,
                    onChanged: widget.onWorkToChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
