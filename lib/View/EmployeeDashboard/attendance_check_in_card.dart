import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/AttendanceDayOutcomeModel.dart';
import 'package:point/Models/AttendanceRecordModel.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/attendance_day_state.dart';
import 'package:point/Services/attendance_photo_helper.dart';
import 'package:point/Services/attendance_policy_settings.dart';
import 'package:point/Services/firestore/firestore_attendance_api.dart';
import 'package:point/Services/location_helper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/View/Shared/responsive.dart';

enum _ActionPhase { beforeWindow, active, submitted, approved, failed, closed }

class _ActionVisual {
  const _ActionVisual({
    required this.phase,
    required this.windowLabel,
    required this.statusLabel,
    required this.enabled,
    required this.accent,
    required this.accentSoft,
  });

  final _ActionPhase phase;
  final String windowLabel;
  final String statusLabel;
  final bool enabled;
  final Color accent;
  final Color accentSoft;
}

class AttendanceCheckInCard extends StatefulWidget {
  const AttendanceCheckInCard({super.key});

  @override
  State<AttendanceCheckInCard> createState() => _AttendanceCheckInCardState();
}

class _AttendanceCheckInCardState extends State<AttendanceCheckInCard> {
  bool _busy = false;
  AttendancePolicySettings _policy = AttendancePolicySettings.defaults;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPolicy());
  }

  Future<void> _loadPolicy() async {
    try {
      final policy = await AttendancePolicySettings.load();
      if (mounted) setState(() => _policy = policy);
    } catch (_) {
      // Keep defaults.
    }
  }

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

  String _formatMinutes(int totalMinutes) {
    final hour = (totalMinutes ~/ 60) % 24;
    final minute = totalMinutes % 60;
    final dt = DateTime(2000, 1, 1, hour, minute);
    return DateFormat.jm().format(dt);
  }

  String _outcomeBannerText(AttendanceDayState dayState) {
    switch (dayState.outcome) {
      case AttendanceDailyOutcome.none:
        return AppLocaleKeys.attendanceNotCheckedIn.tr;
      case AttendanceDailyOutcome.pending:
        if (dayState.presentRecord?.isAutoRejectedLate == true ||
            dayState.leftRecord?.isAutoRejectedLate == true) {
          return AppLocaleKeys.attendanceDayAbsent.tr;
        }
        if (dayState.presentRecord?.isPending ?? false) {
          return AppLocaleKeys.attendancePendingApproval.tr;
        }
        if (dayState.leftRecord?.isPending ?? false) {
          return AppLocaleKeys.attendancePendingApproval.tr;
        }
        if (dayState.presentRecord?.isApproved ?? false) {
          return AppLocaleKeys.attendanceWaitingLeft.tr;
        }
        return AppLocaleKeys.attendancePendingApproval.tr;
      case AttendanceDailyOutcome.showedUp:
        return AppLocaleKeys.attendanceDayComplete.tr;
      case AttendanceDailyOutcome.absent:
        return AppLocaleKeys.attendanceDayAbsent.tr;
      case AttendanceDailyOutcome.noCheckIn:
        return AppLocaleKeys.attendanceAutoAbsentNoCheckIn.tr;
      case AttendanceDailyOutcome.noCheckout:
        return AppLocaleKeys.attendanceAutoAbsentNoCheckout.tr;
    }
  }

  String _detailTimeText(AttendanceDayState dayState) {
    AttendanceRecordModel? source;
    if (dayState.outcome == AttendanceDailyOutcome.showedUp) {
      source = dayState.leftRecord ?? dayState.presentRecord;
    } else if (dayState.presentRecord?.isApproved ?? false) {
      source = dayState.presentRecord;
    }
    if (source?.recordedAt == null) return '';
    final time = DateFormat.jm().format(source!.recordedAt!.toLocal());
    if (dayState.outcome == AttendanceDailyOutcome.showedUp) {
      return AppLocaleKeys.attendanceLeftAt.trParams({'time': time});
    }
    if (dayState.presentRecord?.isApproved ?? false) {
      return AppLocaleKeys.attendanceCheckedInAt.trParams({'time': time});
    }
    return '';
  }

  Future<void> _onAction(String action) async {
    if (_busy) return;

    final controller = Get.find<HomeController>();
    final emp = controller.currentEmployee.value;
    if (emp == null || emp.id == null) return;

    final isRemote = emp.isRemoteAttendance;
    final location = emp.attendanceLocation;
    if (!isRemote && (location == null || !location.isConfigured)) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.attendanceOfficeNotConfigured.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    AttendancePhotoCapture? photoCapture;
    if (!isRemote) {
      photoCapture = await AttendancePhotoHelper.capture(
        action: action,
        employeeId: emp.id!,
      );
      if (photoCapture == null) return;
    }

    setState(() => _busy = true);
    try {
      double latitude = 0;
      double longitude = 0;
      double distance = 0;
      double officeLatitude = 0;
      double officeLongitude = 0;
      double officeRadiusMeters = 0;

      if (!isRemote) {
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
        distance = LocationHelper.distanceMeters(
          fromLat: pos.latitude,
          fromLng: pos.longitude,
          toLat: location!.latitude,
          toLng: location.longitude,
        );

        if (distance > location.radiusMeters) {
          FunHelper.showSnackbar(
            'error'.tr,
            AppLocaleKeys.attendanceOutsideLocation.trParams({
              'distance': distance.round().toString(),
              'radius': location.radiusMeters.round().toString(),
            }),
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        latitude = pos.latitude;
        longitude = pos.longitude;
        officeLatitude = location.latitude;
        officeLongitude = location.longitude;
        officeRadiusMeters = location.radiusMeters;
      }

      String photoUrl = '';
      if (photoCapture != null) {
        final uploaded = await controller.uploadFiles(
          filePathOrBytes: photoCapture.bytes,
          fileName: photoCapture.fileName,
          useBlockingUploadDialog: true,
          addToUploadedFilesPathsList: false,
        );
        if (uploaded == null || uploaded.trim().isEmpty) {
          FunHelper.showSnackbar(
            'error'.tr,
            AppLocaleKeys.attendancePhotoUploadFailed.tr,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
        photoUrl = uploaded;
      }

      await FirestoreServices.recordAttendance(
        employeeId: emp.id!,
        employeeName: emp.name ?? '',
        action: action,
        latitude: latitude,
        longitude: longitude,
        distanceMeters: distance,
        officeLatitude: officeLatitude,
        officeLongitude: officeLongitude,
        officeRadiusMeters: officeRadiusMeters,
        photoUrl: photoUrl,
      );

      FunHelper.showSnackbar(
        'common.confirm'.tr,
        AppLocaleKeys.attendanceRecordPending.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on AttendanceRecordRejectedException catch (e) {
      FunHelper.showSnackbar(
        'error'.tr,
        e.messageKey.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
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

  void _handlePresent(AttendanceDayState dayState) {
    if (!dayState.canPressPresent) {
      if (dayState.presentRecord != null) {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.attendanceAlreadyPressedPresent.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.attendanceOutsidePresentWindow.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
      return;
    }
    unawaited(_onAction(AttendanceRecordModel.actionPresent));
  }

  void _handleLeft(AttendanceDayState dayState) {
    if (!dayState.canPressLeft) {
      if (dayState.leftRecord != null) {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.attendanceAlreadyPressedLeft.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else if (!AttendanceDayState.hasPresentSubmitted(dayState.presentRecord)) {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.attendanceMustPresentFirst.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.attendanceOutsideLeftWindow.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
      return;
    }
    unawaited(_onAction(AttendanceRecordModel.actionLeft));
  }

  _ActionVisual _presentVisual({
    required AttendanceDayState dayState,
    required String? workHoursFrom,
    required String? workHoursTo,
    required bool flexibleHours,
  }) {
    const accent = Color(0xFF2E7D32);
    const accentSoft = Color(0xFFEAF8F1);
    final record = dayState.presentRecord;
    final allDayLabel = AppLocaleKeys.attendanceActionAvailableAllDay.tr;
    final windowLabel = flexibleHours
        ? allDayLabel
        : _windowRangeLabel(
            workHoursFrom,
            _policy.checkInGraceMinutes,
          );

    if (record != null) {
      if (record.isApproved) {
        return _ActionVisual(
          phase: _ActionPhase.approved,
          windowLabel: windowLabel,
          statusLabel: _recordTimeLabel(record),
          enabled: false,
          accent: accent,
          accentSoft: accentSoft,
        );
      }
      if (record.isPending) {
        return _ActionVisual(
          phase: _ActionPhase.submitted,
          windowLabel: windowLabel,
          statusLabel: AppLocaleKeys.attendanceActionSubmitted.tr,
          enabled: false,
          accent: accent,
          accentSoft: accentSoft,
        );
      }
      return _ActionVisual(
        phase: _ActionPhase.failed,
        windowLabel: windowLabel,
        statusLabel: record.isAutoRejectedLate
            ? AppLocaleKeys.attendanceAutoRejectedLate.tr
            : AppLocaleKeys.attendanceAbsent.tr,
        enabled: false,
        accent: Colors.red.shade700,
        accentSoft: Colors.red.shade50,
      );
    }

    if (dayState.canPressPresent) {
      return _ActionVisual(
        phase: _ActionPhase.active,
        windowLabel: windowLabel,
        statusLabel: flexibleHours
            ? AppLocaleKeys.attendanceActionAvailableAllDay.tr
            : AppLocaleKeys.attendanceActionAvailable.tr,
        enabled: !_busy,
        accent: accent,
        accentSoft: accentSoft,
      );
    }

    if (flexibleHours) {
      return _ActionVisual(
        phase: _ActionPhase.closed,
        windowLabel: windowLabel,
        statusLabel: AppLocaleKeys.attendanceActionWindowClosed.tr,
        enabled: false,
        accent: AppColors.fontColorGrey,
        accentSoft: AppColors.greyBackground,
      );
    }

    final now = DateTime.now();
    if (!AttendanceDayState.hasWorkHoursConfigured(workHoursFrom, workHoursTo)) {
      return _ActionVisual(
        phase: _ActionPhase.closed,
        windowLabel: AppLocaleKeys.attendanceWorkHoursNotConfigured.tr,
        statusLabel: AppLocaleKeys.attendanceActionWindowClosed.tr,
        enabled: false,
        accent: AppColors.fontColorGrey,
        accentSoft: AppColors.greyBackground,
      );
    }
    if (AttendanceDayState.isBeforePresentWindow(
      workHoursFrom: workHoursFrom,
      now: now,
    )) {
      final fromMinutes = AttendanceDayState.parseHHmm(workHoursFrom)!;
      return _ActionVisual(
        phase: _ActionPhase.beforeWindow,
        windowLabel: windowLabel,
        statusLabel: AppLocaleKeys.attendancePresentBeforeWindow.trParams({
          'time': _formatMinutes(fromMinutes),
        }),
        enabled: false,
        accent: AppColors.fontColorGrey,
        accentSoft: AppColors.greyBackground,
      );
    }
    return _ActionVisual(
      phase: _ActionPhase.closed,
      windowLabel: windowLabel,
      statusLabel: AppLocaleKeys.attendanceActionWindowClosed.tr,
      enabled: false,
      accent: AppColors.fontColorGrey,
      accentSoft: AppColors.greyBackground,
    );
  }

  _ActionVisual _leftVisual({
    required AttendanceDayState dayState,
    required String? workHoursFrom,
    required String? workHoursTo,
    required bool flexibleHours,
  }) {
    const accent = AppColors.primary;
    const accentSoft = Color(0xFFF3F0FA);
    final record = dayState.leftRecord;
    final allDayLabel = AppLocaleKeys.attendanceActionAvailableAllDay.tr;
    final windowLabel = flexibleHours
        ? allDayLabel
        : _windowRangeLabel(
            workHoursTo,
            _policy.checkOutGraceMinutes,
          );

    if (record != null) {
      if (record.isApproved) {
        return _ActionVisual(
          phase: _ActionPhase.approved,
          windowLabel: windowLabel,
          statusLabel: _recordTimeLabel(record),
          enabled: false,
          accent: accent,
          accentSoft: accentSoft,
        );
      }
      if (record.isPending) {
        return _ActionVisual(
          phase: _ActionPhase.submitted,
          windowLabel: windowLabel,
          statusLabel: AppLocaleKeys.attendanceActionSubmitted.tr,
          enabled: false,
          accent: accent,
          accentSoft: accentSoft,
        );
      }
      return _ActionVisual(
        phase: _ActionPhase.failed,
        windowLabel: windowLabel,
        statusLabel: record.isAutoRejectedLate
            ? AppLocaleKeys.attendanceAutoRejectedLate.tr
            : AppLocaleKeys.attendanceAbsent.tr,
        enabled: false,
        accent: Colors.red.shade700,
        accentSoft: Colors.red.shade50,
      );
    }

    if (!AttendanceDayState.hasPresentSubmitted(dayState.presentRecord)) {
      return _ActionVisual(
        phase: _ActionPhase.beforeWindow,
        windowLabel: windowLabel,
        statusLabel: AppLocaleKeys.attendanceMustPresentFirst.tr,
        enabled: false,
        accent: AppColors.fontColorGrey,
        accentSoft: AppColors.greyBackground,
      );
    }

    if (dayState.canPressLeft) {
      return _ActionVisual(
        phase: _ActionPhase.active,
        windowLabel: windowLabel,
        statusLabel: flexibleHours
            ? AppLocaleKeys.attendanceActionAvailableAllDay.tr
            : AppLocaleKeys.attendanceActionAvailable.tr,
        enabled: !_busy,
        accent: accent,
        accentSoft: accentSoft,
      );
    }

    if (flexibleHours) {
      return _ActionVisual(
        phase: _ActionPhase.closed,
        windowLabel: windowLabel,
        statusLabel: AppLocaleKeys.attendanceActionWindowClosed.tr,
        enabled: false,
        accent: AppColors.fontColorGrey,
        accentSoft: AppColors.greyBackground,
      );
    }

    final now = DateTime.now();
    if (!AttendanceDayState.hasWorkHoursConfigured(workHoursFrom, workHoursTo)) {
      return _ActionVisual(
        phase: _ActionPhase.closed,
        windowLabel: AppLocaleKeys.attendanceWorkHoursNotConfigured.tr,
        statusLabel: AppLocaleKeys.attendanceActionWindowClosed.tr,
        enabled: false,
        accent: AppColors.fontColorGrey,
        accentSoft: AppColors.greyBackground,
      );
    }
    if (AttendanceDayState.isBeforeLeftWindow(
      workHoursTo: workHoursTo,
      now: now,
    )) {
      final toMinutes = AttendanceDayState.parseHHmm(workHoursTo)!;
      return _ActionVisual(
        phase: _ActionPhase.beforeWindow,
        windowLabel: windowLabel,
        statusLabel: AppLocaleKeys.attendanceLeftBeforeWindow.trParams({
          'time': _formatMinutes(toMinutes),
        }),
        enabled: false,
        accent: AppColors.fontColorGrey,
        accentSoft: AppColors.greyBackground,
      );
    }
    return _ActionVisual(
      phase: _ActionPhase.closed,
      windowLabel: windowLabel,
      statusLabel: AppLocaleKeys.attendanceActionWindowClosed.tr,
      enabled: false,
      accent: AppColors.fontColorGrey,
      accentSoft: AppColors.greyBackground,
    );
  }

  String _windowRangeLabel(String? start, int graceMinutes) {
    final from = AttendanceDayState.parseHHmm(start);
    if (from == null) return start?.trim() ?? '';
    return '${_formatMinutes(from)} – ${_formatMinutes(from + graceMinutes)}';
  }

  String _recordTimeLabel(AttendanceRecordModel record) {
    if (record.recordedAt == null) return AppLocaleKeys.attendanceApproved.tr;
    return DateFormat.jm().format(record.recordedAt!.toLocal());
  }

  ({Color bg, Color border, Color fg, IconData icon}) _outcomeStyle(
    AttendanceDailyOutcome outcome,
  ) {
    switch (outcome) {
      case AttendanceDailyOutcome.pending:
        return (
          bg: Colors.orange.withValues(alpha: 0.1),
          border: Colors.orange.withValues(alpha: 0.35),
          fg: Colors.orange.shade800,
          icon: Icons.hourglass_top_rounded,
        );
      case AttendanceDailyOutcome.showedUp:
        return (
          bg: AppColors.success.withValues(alpha: 0.1),
          border: AppColors.success.withValues(alpha: 0.35),
          fg: AppColors.success,
          icon: Icons.check_circle_rounded,
        );
      case AttendanceDailyOutcome.absent:
      case AttendanceDailyOutcome.noCheckIn:
      case AttendanceDailyOutcome.noCheckout:
        return (
          bg: Colors.red.withValues(alpha: 0.08),
          border: Colors.red.withValues(alpha: 0.3),
          fg: Colors.red.shade700,
          icon: Icons.cancel_rounded,
        );
      case AttendanceDailyOutcome.none:
        return (
          bg: AppColors.greyBackground,
          border: Colors.grey.shade300,
          fg: AppColors.fontColorGrey,
          icon: Icons.schedule_rounded,
        );
    }
  }

  Widget _buildHeader() {
    final today = DateFormat.yMMMd().format(DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.authLoginButtonGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.fingerprint_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocaleKeys.attendanceTitle.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryfontColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppLocaleKeys.attendanceCardToday.trParams({'date': today}),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOutcomeHero(AttendanceDayState dayState) {
    final style = _outcomeStyle(dayState.outcome);
    final detail = _detailTimeText(dayState);
    final title = _outcomeBannerText(dayState);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, color: style.fg, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: style.fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: TextStyle(
                      color: AppColors.primaryfontColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep({
    required String label,
    required _ActionVisual visual,
    required bool isLast,
  }) {
    final dotColor = switch (visual.phase) {
      _ActionPhase.approved => visual.accent,
      _ActionPhase.submitted => Colors.orange.shade700,
      _ActionPhase.active => visual.accent,
      _ActionPhase.failed => Colors.red.shade700,
      _ => Colors.grey.shade400,
    };
    final icon = switch (visual.phase) {
      _ActionPhase.approved => Icons.check_rounded,
      _ActionPhase.submitted => Icons.more_horiz_rounded,
      _ActionPhase.failed => Icons.close_rounded,
      _ActionPhase.active => Icons.radio_button_checked_rounded,
      _ => Icons.radio_button_off_rounded,
    };

    return Expanded(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 1.5),
                ),
                child: Icon(icon, size: 16, color: dotColor),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryfontColor,
                ),
              ),
            ],
          ),
          if (!isLast)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: visual.phase == _ActionPhase.approved
                        ? dotColor.withValues(alpha: 0.5)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressTracker(
    AttendanceDayState dayState,
    _ActionVisual presentVisual,
    _ActionVisual leftVisual,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _buildProgressStep(
            label: AppLocaleKeys.attendancePresent.tr,
            visual: presentVisual,
            isLast: false,
          ),
          _buildProgressStep(
            label: AppLocaleKeys.attendanceLeft.tr,
            visual: leftVisual,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required _ActionVisual visual,
    required VoidCallback? onTap,
    required bool loading,
  }) {
    final isActive = visual.phase == _ActionPhase.active;

    return Material(
      color: visual.accentSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: visual.enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? visual.accent.withValues(alpha: 0.55)
                  : Colors.grey.shade300,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: visual.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: visual.accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryfontColor,
                      ),
                    ),
                  ),
                  if (loading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: visual.accent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (visual.windowLabel.isNotEmpty)
                Text(
                  visual.windowLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  visual.statusLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: visual.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBody({
    required List<AttendanceRecordModel> records,
    required AttendanceDayOutcomeModel? systemOutcome,
    required String? workHoursFrom,
    required String? workHoursTo,
    required bool flexibleHours,
  }) {
    final dayState = AttendanceDayState.compute(
      records: records,
      systemOutcome: systemOutcome,
      workHoursFrom: workHoursFrom,
      workHoursTo: workHoursTo,
      policy: _policy,
      flexibleHours: flexibleHours,
    );

    final presentVisual = _presentVisual(
      dayState: dayState,
      workHoursFrom: workHoursFrom,
      workHoursTo: workHoursTo,
      flexibleHours: flexibleHours,
    );
    final leftVisual = _leftVisual(
      dayState: dayState,
      workHoursFrom: workHoursFrom,
      workHoursTo: workHoursTo,
      flexibleHours: flexibleHours,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildOutcomeHero(dayState),
          const SizedBox(height: 20),
          _buildProgressTracker(dayState, presentVisual, leftVisual),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildActionTile(
                  title: AppLocaleKeys.attendancePresent.tr,
                  icon: Icons.login_rounded,
                  visual: presentVisual,
                  loading: _busy && dayState.canPressPresent,
                  onTap: () => _handlePresent(dayState),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionTile(
                  title: AppLocaleKeys.attendanceLeft.tr,
                  icon: Icons.logout_rounded,
                  visual: leftVisual,
                  loading: _busy && dayState.canPressLeft,
                  onTap: () => _handleLeft(dayState),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            AppLocaleKeys.attendanceHelp.tr,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    return Obx(() {
      final emp = controller.currentEmployee.value;
      if (emp == null || emp.role.trim().toLowerCase() != 'employee') {
        return const SizedBox.shrink();
      }
      final employeeId = emp.id;
      if (employeeId == null || employeeId.isEmpty) {
        return const SizedBox.shrink();
      }

      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.isMobile(context) ? double.infinity : 640,
          ),
          child: StreamBuilder<List<AttendanceRecordModel>>(
            stream: FirestoreServices.streamTodayAttendanceForEmployee(employeeId),
            builder: (context, recordsSnapshot) {
              final records = recordsSnapshot.data ?? const [];
              return StreamBuilder<AttendanceDayOutcomeModel?>(
                stream: FirestoreServices.streamTodayAttendanceOutcomeForEmployee(
                  employeeId,
                ),
                builder: (context, outcomeSnapshot) {
                  return _buildCardBody(
                    records: records,
                    systemOutcome: outcomeSnapshot.data,
                    workHoursFrom: emp.workHoursFrom,
                    workHoursTo: emp.workHoursTo,
                    flexibleHours: emp.hasFlexibleAttendanceHours,
                  );
                },
              );
            },
          ),
        ),
      );
    });
  }
}
