import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/AttendanceDayOutcomeModel.dart';
import 'package:point/Models/AttendanceRecordModel.dart';
import 'package:point/Services/attendance_day_state.dart';
import 'package:point/Services/attendance_policy_settings.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Chats/chat_cached_attachment_image.dart';
import 'package:point/View/Chats/chat_message_display.dart';
import 'package:point/View/Shared/HorizontalScroll.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/TableCellCenter.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/table_area_loading.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime _selectedDate = DateTime.now();
  final _filterController = TextEditingController();
  final _dateController = TextEditingController();
  String _actionFilter = '';
  String _approvalFilter = '';
  String _dailyResultFilter = '';
  String? _reviewingRecordId;
  AttendancePolicySettings _policy = AttendancePolicySettings.defaults;
  List<AttendanceDayOutcomeModel> _dayOutcomes = const [];
  bool _loadingDayContext = true;

  static const TextStyle _columnHeaderStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 13,
    color: AppColors.fontColorGrey,
  );

  static const double _filterHeight = 42;
  static const double _filterRadius = 5;

  TextStyle _filterTextStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryfontColor,
        ) ??
        const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryfontColor,
        );
  }

  BoxDecoration get _filterDecoration => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(_filterRadius),
      );

  @override
  void initState() {
    super.initState();
    _syncDateLabel();
    unawaited(_loadDayContext());
  }

  Future<void> _loadDayContext() async {
    setState(() => _loadingDayContext = true);
    try {
      final results = await Future.wait([
        AttendancePolicySettings.load(),
        FirestoreServices.fetchAttendanceOutcomesForDate(_selectedDate),
      ]);
      if (!mounted) return;
      setState(() {
        _policy = results[0] as AttendancePolicySettings;
        _dayOutcomes = results[1] as List<AttendanceDayOutcomeModel>;
      });
    } catch (_) {
      // Keep previous values.
    } finally {
      if (mounted) setState(() => _loadingDayContext = false);
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _syncDateLabel() {
    _dateController.text = DateFormat.yMMMd().format(_selectedDate);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _syncDateLabel();
      });
      unawaited(_loadDayContext());
    }
  }

  String _actionLabel(String action) {
    if (action == AttendanceRecordModel.actionPresent) {
      return AppLocaleKeys.attendancePresent.tr;
    }
    if (action == AttendanceRecordModel.actionLeft) {
      return AppLocaleKeys.attendanceLeft.tr;
    }
    return action;
  }

  List<AttendanceRecordModel> _filterRecords(
    List<AttendanceRecordModel> records,
    Map<String, AttendanceDayState> dailyStates,
  ) {
    var result = records;
    final query = _filterController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result
          .where((r) => r.employeeName.toLowerCase().contains(query))
          .toList();
    }
    if (_actionFilter.isNotEmpty) {
      result = result.where((r) => r.action == _actionFilter).toList();
    }
    if (_approvalFilter.isNotEmpty) {
      result =
          result.where((r) => r.approvalStatus == _approvalFilter).toList();
    }
    if (_dailyResultFilter.isNotEmpty) {
      result = result.where((r) {
        final outcome = dailyStates[r.employeeId]?.outcome;
        return _matchesDailyResultFilter(outcome);
      }).toList();
    }
    return result;
  }

  String _outcomeFilterKey(AttendanceDailyOutcome outcome) {
    switch (outcome) {
      case AttendanceDailyOutcome.showedUp:
        return 'showed_up';
      case AttendanceDailyOutcome.absent:
        return 'absent';
      case AttendanceDailyOutcome.noCheckIn:
        return 'no_check_in';
      case AttendanceDailyOutcome.noCheckout:
        return 'no_checkout';
      case AttendanceDailyOutcome.pending:
        return 'pending';
      case AttendanceDailyOutcome.none:
        return 'none';
    }
  }

  bool _matchesDailyResultFilter(AttendanceDailyOutcome? outcome) {
    if (_dailyResultFilter.isEmpty) return true;
    final key = outcome == null ? 'none' : _outcomeFilterKey(outcome);
    if (_dailyResultFilter == 'absent') {
      return key == 'absent' || key == 'no_check_in' || key == 'no_checkout';
    }
    return key == _dailyResultFilter;
  }

  String _dailyResultTableLabel(AttendanceDailyOutcome outcome) {
    switch (outcome) {
      case AttendanceDailyOutcome.showedUp:
        return AppLocaleKeys.attendanceShowedUp.tr;
      case AttendanceDailyOutcome.absent:
        return AppLocaleKeys.attendanceDayAbsent.tr;
      case AttendanceDailyOutcome.noCheckIn:
        return AppLocaleKeys.attendanceDailyResultNoCheckInShort.tr;
      case AttendanceDailyOutcome.noCheckout:
        return AppLocaleKeys.attendanceDailyResultNoCheckoutShort.tr;
      case AttendanceDailyOutcome.pending:
        return AppLocaleKeys.attendancePending.tr;
      case AttendanceDailyOutcome.none:
        return '-';
    }
  }

  String _dailyResultLabel(AttendanceDailyOutcome outcome) {
    switch (outcome) {
      case AttendanceDailyOutcome.showedUp:
        return AppLocaleKeys.attendanceShowedUp.tr;
      case AttendanceDailyOutcome.absent:
        return AppLocaleKeys.attendanceDayAbsent.tr;
      case AttendanceDailyOutcome.noCheckIn:
        return AppLocaleKeys.attendanceAutoAbsentNoCheckIn.tr;
      case AttendanceDailyOutcome.noCheckout:
        return AppLocaleKeys.attendanceAutoAbsentNoCheckout.tr;
      case AttendanceDailyOutcome.pending:
        return AppLocaleKeys.attendancePending.tr;
      case AttendanceDailyOutcome.none:
        return '-';
    }
  }

  Map<String, AttendanceDayState> _dailyStatesForRecords(
    List<AttendanceRecordModel> allRecords,
  ) {
    final byEmployee = <String, List<AttendanceRecordModel>>{};
    for (final r in allRecords) {
      byEmployee.putIfAbsent(r.employeeId, () => []).add(r);
    }

    final outcomesByEmployee = {
      for (final o in _dayOutcomes) o.employeeId: o,
    };
    final employees = Get.find<HomeController>().employees;
    final workHoursById = {
      for (final e in employees)
        if (e.id != null) e.id!: e,
    };

    final endOfSelectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23,
      59,
    );

    final result = <String, AttendanceDayState>{};
    for (final entry in byEmployee.entries) {
      final emp = workHoursById[entry.key];
      result[entry.key] = AttendanceDayState.compute(
        records: entry.value,
        systemOutcome: outcomesByEmployee[entry.key],
        workHoursFrom: emp?.workHoursFrom,
        workHoursTo: emp?.workHoursTo,
        policy: _policy,
        now: endOfSelectedDay,
      );
    }
    return result;
  }

  Widget _buildDailyResultChip(AttendanceDailyOutcome outcome) {
    Color fg;
    Color bg;
    if (outcome == AttendanceDailyOutcome.showedUp) {
      fg = const Color(0xFF0F9D58);
      bg = const Color(0xFFEAF8F1);
    } else if (outcome == AttendanceDailyOutcome.pending ||
        outcome == AttendanceDailyOutcome.none) {
      fg = Colors.orange.shade800;
      bg = Colors.orange.shade50;
    } else {
      fg = Colors.red.shade700;
      bg = Colors.red.shade50;
    }

    return Tooltip(
      message: _dailyResultLabel(outcome),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            _dailyResultTableLabel(outcome),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  String _approvalLabel(String status) {
    switch (status) {
      case AttendanceRecordModel.statusApproved:
        return AppLocaleKeys.attendanceApproved.tr;
      case AttendanceRecordModel.statusAbsent:
        return AppLocaleKeys.attendanceAbsent.tr;
      case AttendanceRecordModel.statusAutoRejectedLate:
        return AppLocaleKeys.attendanceAutoRejectedLate.tr;
      case AttendanceRecordModel.statusPending:
      default:
        return AppLocaleKeys.attendancePending.tr;
    }
  }

  Future<void> _reviewRecord(
    AttendanceRecordModel record, {
    required bool approved,
  }) async {
    if (record.id == null || _reviewingRecordId != null) return;
    final admin = Get.find<HomeController>().effectiveEmployee;
    if (admin?.id == null) return;

    setState(() => _reviewingRecordId = record.id);
    try {
      await FirestoreServices.reviewAttendanceRecord(
        recordId: record.id!,
        approved: approved,
        reviewerEmployeeId: admin!.id!,
        reviewerName: admin.name ?? '',
      );
      FunHelper.showSnackbar(
        'common.confirm'.tr,
        approved
            ? AppLocaleKeys.attendanceApproveSuccess.tr
            : AppLocaleKeys.attendanceAbsentSuccess.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (_) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.attendanceReviewFailed.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _reviewingRecordId = null);
    }
  }

  Widget _buildDateFilter() {
    return InputText(
      readOnly: true,
      onTap: _pickDate,
      controller: _dateController,
      hintText: AppLocaleKeys.attendanceSelectDate.tr,
      height: _filterHeight,
      fillColor: Colors.white,
      borderRadius: _filterRadius,
      borderColor: Colors.grey.shade300,
      suffixIcon: Icon(
        Icons.calendar_today_outlined,
        size: 18,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildEmployeeFilter() {
    return InputText(
      prefixIcon: Icon(CupertinoIcons.search, color: Colors.grey),
      hintText: AppLocaleKeys.attendanceFilterEmployee.tr,
      controller: _filterController,
      height: _filterHeight,
      fillColor: Colors.white,
      borderRadius: _filterRadius,
      borderColor: Colors.grey.shade300,
      onchange: (_) {
        setState(() {});
        return null;
      },
    );
  }

  Widget _buildActionFilter(BuildContext context) {
    final textStyle = _filterTextStyle(context);
    return SizedBox(
      height: _filterHeight,
      child: DecoratedBox(
        decoration: _filterDecoration,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            hint: Text(
              AppLocaleKeys.attendanceFilterAction.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
            value: _actionFilter.isEmpty ? null : _actionFilter,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade600,
            ),
            style: textStyle,
            items: [
              DropdownMenuItem(value: '', child: Text('all'.tr, style: textStyle)),
              DropdownMenuItem(
                value: AttendanceRecordModel.actionPresent,
                child: Text(AppLocaleKeys.attendancePresent.tr, style: textStyle),
              ),
              DropdownMenuItem(
                value: AttendanceRecordModel.actionLeft,
                child: Text(AppLocaleKeys.attendanceLeft.tr, style: textStyle),
              ),
            ],
            onChanged: (value) {
              setState(() => _actionFilter = value ?? '');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalFilter(BuildContext context) {
    final textStyle = _filterTextStyle(context);
    return SizedBox(
      height: _filterHeight,
      child: DecoratedBox(
        decoration: _filterDecoration,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            hint: Text(
              AppLocaleKeys.attendanceFilterApproval.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
            value: _approvalFilter.isEmpty ? null : _approvalFilter,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade600,
            ),
            style: textStyle,
            items: [
              DropdownMenuItem(value: '', child: Text('all'.tr, style: textStyle)),
              DropdownMenuItem(
                value: AttendanceRecordModel.statusPending,
                child: Text(AppLocaleKeys.attendancePending.tr, style: textStyle),
              ),
              DropdownMenuItem(
                value: AttendanceRecordModel.statusApproved,
                child: Text(AppLocaleKeys.attendanceApproved.tr, style: textStyle),
              ),
              DropdownMenuItem(
                value: AttendanceRecordModel.statusAbsent,
                child: Text(AppLocaleKeys.attendanceAbsent.tr, style: textStyle),
              ),
              DropdownMenuItem(
                value: AttendanceRecordModel.statusAutoRejectedLate,
                child: Text(
                  AppLocaleKeys.attendanceAutoRejectedLate.tr,
                  style: textStyle,
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _approvalFilter = value ?? '');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDailyResultFilter(BuildContext context) {
    final textStyle = _filterTextStyle(context);
    return SizedBox(
      height: _filterHeight,
      child: DecoratedBox(
        decoration: _filterDecoration,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            hint: Text(
              AppLocaleKeys.attendanceFilterDailyResult.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
            value: _dailyResultFilter.isEmpty ? null : _dailyResultFilter,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade600,
            ),
            style: textStyle,
            items: [
              DropdownMenuItem(value: '', child: Text('all'.tr, style: textStyle)),
              DropdownMenuItem(
                value: 'showed_up',
                child: Text(AppLocaleKeys.attendanceShowedUp.tr, style: textStyle),
              ),
              DropdownMenuItem(
                value: 'absent',
                child: Text(AppLocaleKeys.attendanceDayAbsent.tr, style: textStyle),
              ),
              DropdownMenuItem(
                value: 'no_check_in',
                child: Text(
                  AppLocaleKeys.attendanceDailyResultNoCheckInShort.tr,
                  style: textStyle,
                ),
              ),
              DropdownMenuItem(
                value: 'no_checkout',
                child: Text(
                  AppLocaleKeys.attendanceDailyResultNoCheckoutShort.tr,
                  style: textStyle,
                ),
              ),
              DropdownMenuItem(
                value: 'pending',
                child: Text(AppLocaleKeys.attendancePending.tr, style: textStyle),
              ),
              DropdownMenuItem(
                value: 'none',
                child: Text('-', style: textStyle),
              ),
            ],
            onChanged: (value) {
              setState(() => _dailyResultFilter = value ?? '');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateFilter(),
          const SizedBox(height: 12),
          _buildEmployeeFilter(),
          const SizedBox(height: 12),
          _buildActionFilter(context),
          const SizedBox(height: 12),
          _buildApprovalFilter(context),
          const SizedBox(height: 12),
          _buildDailyResultFilter(context),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 4, child: _buildDateFilter()),
            const SizedBox(width: 10),
            Expanded(flex: 5, child: _buildEmployeeFilter()),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: _buildActionFilter(context)),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: _buildApprovalFilter(context)),
            const SizedBox(width: 10),
            Expanded(flex: 4, child: _buildDailyResultFilter(context)),
          ],
        ),
      ],
    );
  }

  Widget _buildApprovalChip(AttendanceRecordModel record) {
    Color fg;
    Color bg;
    if (record.isApproved) {
      fg = const Color(0xFF0F9D58);
      bg = const Color(0xFFEAF8F1);
    } else if (record.isAutoRejectedLate) {
      fg = Colors.red.shade900;
      bg = Colors.red.shade100;
    } else if (record.isAbsent) {
      fg = Colors.red.shade700;
      bg = Colors.red.shade50;
    } else {
      fg = Colors.orange.shade800;
      bg = Colors.orange.shade50;
    }
    return Container(
      alignment: Alignment.center,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _approvalLabel(record.approvalStatus),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildReviewActions(AttendanceRecordModel record) {
    if (!record.isPending || record.id == null) {
      return const Text('-');
    }
    final loading = _reviewingRecordId == record.id;
    if (loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: AppLocaleKeys.attendanceApprove.tr,
          icon: Icon(Icons.check_circle_outline, color: AppColors.success),
          onPressed: () => unawaited(_reviewRecord(record, approved: true)),
        ),
        IconButton(
          tooltip: AppLocaleKeys.attendanceMarkAbsent.tr,
          icon: Icon(Icons.cancel_outlined, color: Colors.red.shade700),
          onPressed: () => unawaited(_reviewRecord(record, approved: false)),
        ),
      ],
    );
  }

  Widget _buildActionChip(AttendanceRecordModel record) {
    final isPresent = record.isPresent;
    final fg = isPresent ? const Color(0xFF0F9D58) : Colors.purple;
    final bg = isPresent ? const Color(0xFFEAF8F1) : Colors.purple.shade50;

    return Container(
      alignment: Alignment.center,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _actionLabel(record.action),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildDataTable(
    List<AttendanceRecordModel> records,
    Map<String, AttendanceDayState> dailyStates,
  ) {
    return HorizontalScrollbarTable(
      child: SizedBox(
        width: (Get.width - 270).clamp(1300.0, double.infinity),
        child: DataTable(
          dataRowMinHeight: 60,
          dataRowMaxHeight: 60,
          dataRowColor: WidgetStateProperty.all(Colors.white),
          dividerThickness: 0.5,
          columns: [
            DataColumn(
              columnWidth: const FixedColumnWidth(200),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendanceEmployee.tr,
                style: _columnHeaderStyle,
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(140),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendanceAction.tr,
                style: _columnHeaderStyle,
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(120),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendanceTime.tr,
                style: _columnHeaderStyle,
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(140),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendanceDistance.tr,
                style: _columnHeaderStyle,
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(130),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendanceApprovalStatus.tr,
                style: _columnHeaderStyle,
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(120),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendanceReviewActions.tr,
                style: _columnHeaderStyle,
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(150),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendanceDailyResult.tr,
                style: _columnHeaderStyle,
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(80),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendancePhoto.tr,
                style: _columnHeaderStyle,
              ),
            ),
          ],
          rows: records.map((record) {
            final time = record.recordedAt != null
                ? DateFormat.jm().format(record.recordedAt!.toLocal())
                : '-';
            final dayState = dailyStates[record.employeeId];
            return DataRow(
              cells: [
                DataCell(
                  TableCellCenter(
                    child: Text(
                      record.employeeName,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                DataCell(
                  TableCellCenter(child: _buildActionChip(record)),
                ),
                DataCell(
                  TableCellCenter(
                    child: Text(time, style: const TextStyle(fontSize: 13)),
                  ),
                ),
                DataCell(
                  TableCellCenter(
                    child: Text(
                      AppLocaleKeys.attendanceMeters.trParams({
                        'value': record.distanceMeters.round().toString(),
                      }),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                DataCell(
                  TableCellCenter(child: _buildApprovalChip(record)),
                ),
                DataCell(
                  TableCellCenter(child: _buildReviewActions(record)),
                ),
                DataCell(
                  TableCellCenter(
                    child: dayState == null
                        ? const Text('-')
                        : _buildDailyResultChip(dayState.outcome),
                  ),
                ),
                DataCell(
                  TableCellCenter(
                    child: _AttendancePhotoThumbnail(photoUrl: record.photoUrl),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        Text(
          AppLocaleKeys.attendanceTitle.tr,
          style: TextStyle(
            color: AppColors.fontColorGrey,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => Get.toNamed('/attendanceReports'),
          icon: const Icon(Icons.assessment_outlined, size: 18),
          label: Text(AppLocaleKeys.attendanceReportsTitle.tr),
        ),
      ],
    );
  }

  Widget _buildPageContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 50),
        _buildTitleRow(),
        const SizedBox(height: 10),
        _buildFilters(context),
        const SizedBox(height: 10),
        StreamBuilder<List<AttendanceRecordModel>>(
          stream: FirestoreServices.streamAttendanceForDate(_selectedDate),
          builder: (context, snapshot) {
            final waitingForRecords =
                snapshot.connectionState == ConnectionState.waiting;
            if (waitingForRecords || _loadingDayContext) {
              return const TableAreaLoading();
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('error'.tr)),
              );
            }

            final allRecords = snapshot.data ?? const [];
            final dailyStates = _dailyStatesForRecords(allRecords);
            final filtered = _filterRecords(allRecords, dailyStates);
            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    AppLocaleKeys.attendanceNoRecords.tr,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              );
            }

            return _buildDataTable(filtered, dailyStates);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (emp?.role != 'admin') {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    return ResponsiveScaffold(
      selectedTab: 12,
      body: Responsive(
        mobile: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: _buildPageContent(context),
        ),
        desktop: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Container(
                padding: const EdgeInsets.all(10),
                width: Responsive.isDesktop(context)
                    ? Get.width - 270
                    : Get.width,
                child: _buildPageContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendancePhotoThumbnail extends StatelessWidget {
  const _AttendancePhotoThumbnail({required this.photoUrl});

  final String? photoUrl;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    if (url == null || url.isEmpty) {
      return const Text('-');
    }

    return Tooltip(
      message: AppLocaleKeys.attendanceViewPhoto.tr,
      child: Material(
        color: AppColors.greyBackground,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: InkWell(
          onTap: () => unawaited(openChatMediaFromUrl(url)),
          child: ChatCachedAttachmentImage(
            url: url,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            loadPolicy: ChatAttachmentLoadPolicy.eager,
            loadingBuilder: (context, child, progress) => SizedBox(
              width: _size,
              height: _size,
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorBuilder: (_, __) => SizedBox(
              width: _size,
              height: _size,
              child: Icon(
                Icons.broken_image_outlined,
                size: 22,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
