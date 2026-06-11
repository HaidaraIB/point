import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/AttendanceRecordModel.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/attendance_photo_helper.dart';
import 'package:point/Services/attendance_settings.dart';
import 'package:point/Services/firestore/firestore_attendance_api.dart';
import 'package:point/Services/location_helper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

class AttendanceCheckInCard extends StatefulWidget {
  const AttendanceCheckInCard({super.key});

  @override
  State<AttendanceCheckInCard> createState() => _AttendanceCheckInCardState();
}

class _AttendanceCheckInCardState extends State<AttendanceCheckInCard> {
  bool _busy = false;
  String? _optimisticLastAction;

  String _locationErrorMessage(LocationHelperError error) {
    switch (error) {
      case LocationHelperError.mobileOnly:
        return AppLocaleKeys.attendanceMobileOnly.tr;
      case LocationHelperError.serviceDisabled:
        return AppLocaleKeys.attendanceLocationServiceDisabled.tr;
      case LocationHelperError.permissionDenied:
      case LocationHelperError.permissionDeniedForever:
        return AppLocaleKeys.attendanceLocationPermissionDenied.tr;
      case LocationHelperError.unavailable:
        return AppLocaleKeys.attendanceLocationUnavailable.tr;
    }
  }

  String _statusText(List<AttendanceRecordModel> records, String? lastAction) {
    if (lastAction == null) {
      return AppLocaleKeys.attendanceNotCheckedIn.tr;
    }
    final time = records.isNotEmpty && records.first.recordedAt != null
        ? DateFormat.jm().format(records.first.recordedAt!.toLocal())
        : DateFormat.jm().format(DateTime.now());
    if (lastAction == AttendanceRecordModel.actionPresent) {
      return AppLocaleKeys.attendanceCheckedInAt.trParams({'time': time});
    }
    return AppLocaleKeys.attendanceLeftAt.trParams({'time': time});
  }

  Future<void> _onAction(String action) async {
    if (_busy) return;

    final controller = Get.find<HomeController>();
    final emp = controller.currentEmployee.value;
    if (emp == null || emp.id == null) return;

    final photoCapture = await AttendancePhotoHelper.capture(
      action: action,
      employeeId: emp.id!,
    );
    if (photoCapture == null) return;

    setState(() => _busy = true);
    try {
      final settings = await AttendanceSettings.load();
      if (settings == null || !settings.isConfigured) {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.attendanceOfficeNotConfigured.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final locationResult = await LocationHelper.getCurrentPosition();
      if (!locationResult.isSuccess) {
        FunHelper.showSnackbar(
          'error'.tr,
          _locationErrorMessage(locationResult.error!),
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final pos = locationResult.position!;
      final distance = LocationHelper.distanceMeters(
        fromLat: pos.latitude,
        fromLng: pos.longitude,
        toLat: settings.latitude,
        toLng: settings.longitude,
      );

      if (distance > settings.radiusMeters) {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.attendanceOutsideLocation.trParams({
            'distance': distance.round().toString(),
            'radius': settings.radiusMeters.round().toString(),
          }),
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final photoUrl = await controller.uploadFiles(
        filePathOrBytes: photoCapture.bytes,
        fileName: photoCapture.fileName,
        useBlockingUploadDialog: true,
        addToUploadedFilesPathsList: false,
      );
      if (photoUrl == null || photoUrl.trim().isEmpty) {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.attendancePhotoUploadFailed.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      await FirestoreServices.recordAttendance(
        employeeId: emp.id!,
        employeeName: emp.name ?? '',
        action: action,
        latitude: pos.latitude,
        longitude: pos.longitude,
        distanceMeters: distance,
        officeLatitude: settings.latitude,
        officeLongitude: settings.longitude,
        officeRadiusMeters: settings.radiusMeters,
        photoUrl: photoUrl,
      );

      setState(() => _optimisticLastAction = action);

      FunHelper.showSnackbar(
        'common.confirm'.tr,
        AppLocaleKeys.attendanceRecordSuccess.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on FirebaseException catch (e, s) {
      appLog('Attendance record failed: ${e.code}', error: e, stackTrace: s);
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.attendanceRecordFailed.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e, s) {
      appLog('Attendance record failed: $e', error: e, stackTrace: s);
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.attendanceRecordFailed.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handlePresent(List<AttendanceRecordModel> records, String? lastAction) {
    if (lastAction == AttendanceRecordModel.actionPresent) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.attendanceAlreadyPresent.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    unawaited(_onAction(AttendanceRecordModel.actionPresent));
  }

  void _handleLeft(List<AttendanceRecordModel> records, String? lastAction) {
    if (lastAction != AttendanceRecordModel.actionPresent) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.attendanceMustPresentFirst.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    unawaited(_onAction(AttendanceRecordModel.actionLeft));
  }

  Widget _buildStatusBanner(List<AttendanceRecordModel> records, String? lastAction) {
    final Color bg;
    final Color border;
    final Color iconColor;
    final IconData icon;

    if (lastAction == AttendanceRecordModel.actionPresent) {
      bg = AppColors.success.withValues(alpha: 0.08);
      border = AppColors.success.withValues(alpha: 0.25);
      iconColor = AppColors.success;
      icon = Icons.check_circle_outline;
    } else if (lastAction == AttendanceRecordModel.actionLeft) {
      bg = AppColors.primary.withValues(alpha: 0.06);
      border = AppColors.primary.withValues(alpha: 0.2);
      iconColor = AppColors.primary;
      icon = Icons.logout_outlined;
    } else {
      bg = AppColors.greyBackground;
      border = Colors.grey.shade300;
      iconColor = AppColors.fontColorGrey;
      icon = Icons.schedule_outlined;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusText(records, lastAction),
              style: TextStyle(
                color: AppColors.primaryfontColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final emp = controller.currentEmployee.value;
    if (emp == null || emp.role.trim().toLowerCase() != 'employee') {
      return const SizedBox.shrink();
    }
    final employeeId = emp.id;
    if (employeeId == null || employeeId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<AttendanceRecordModel>>(
      stream: FirestoreServices.streamTodayAttendanceForEmployee(employeeId),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const [];
        final streamedAction = FirestoreAttendanceApi.todayLastAction(records);
        final lastAction = streamedAction ?? _optimisticLastAction;
        final canPresent = lastAction != AttendanceRecordModel.actionPresent;
        final canLeft = lastAction == AttendanceRecordModel.actionPresent;

        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isMobile(context) ? double.infinity : 560,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocaleKeys.attendanceTitle.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryfontColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocaleKeys.attendanceHelp.tr,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusBanner(records, lastAction),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: MainButton(
                          title: AppLocaleKeys.attendancePresent.tr,
                          height: 48,
                          borderSize: 8,
                          enabled: canPresent && !_busy,
                          load: _busy && canPresent,
                          backgroundColor: AppColors.success,
                          fontColor: Colors.white,
                          onPressed: () => _handlePresent(records, lastAction),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MainButton(
                          title: AppLocaleKeys.attendanceLeft.tr,
                          height: 48,
                          borderSize: 8,
                          enabled: canLeft && !_busy,
                          load: _busy && canLeft,
                          backgroundColor: AppColors.primary,
                          fontColor: Colors.white,
                          onPressed: () => _handleLeft(records, lastAction),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
