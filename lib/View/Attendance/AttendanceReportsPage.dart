import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/attendance_policy_settings.dart';
import 'package:point/Services/attendance_report_download.dart';
import 'package:point/Services/attendance_report_service.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/HorizontalScroll.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/TableCellCenter.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/table_area_loading.dart';

enum _ReportPeriod { month, year }

class AttendanceReportsPage extends StatefulWidget {
  const AttendanceReportsPage({super.key});

  @override
  State<AttendanceReportsPage> createState() => _AttendanceReportsPageState();
}

class _AttendanceReportsPageState extends State<AttendanceReportsPage> {
  _ReportPeriod _period = _ReportPeriod.month;
  DateTime _anchor = DateTime.now();
  final _filterController = TextEditingController();
  final _periodController = TextEditingController();
  String _summaryFilter = '';
  List<AttendanceReportRow> _rows = const [];
  bool _loading = true;

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
    _syncPeriodLabel();
    _loadReport();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  DateTime get _rangeStart {
    if (_period == _ReportPeriod.month) {
      return DateTime(_anchor.year, _anchor.month, 1);
    }
    return DateTime(_anchor.year, 1, 1);
  }

  DateTime get _rangeEnd {
    if (_period == _ReportPeriod.month) {
      return DateTime(_anchor.year, _anchor.month + 1, 1);
    }
    return DateTime(_anchor.year + 1, 1, 1);
  }

  String get _periodLabel {
    if (_period == _ReportPeriod.month) {
      return DateFormat.yMMMM().format(_anchor);
    }
    return _anchor.year.toString();
  }

  void _syncPeriodLabel() {
    _periodController.text = _periodLabel;
  }

  List<String> get _csvHeaders => [
        AppLocaleKeys.attendanceEmployee.tr,
        AppLocaleKeys.attendanceShowedUp.tr,
        AppLocaleKeys.attendanceAbsent.tr,
        AppLocaleKeys.attendancePending.tr,
      ];

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final records = await FirestoreServices.fetchAttendanceForRange(
        startInclusive: _rangeStart,
        endExclusive: _rangeEnd,
      );
      final outcomes = await FirestoreServices.fetchAttendanceOutcomesForRange(
        startInclusive: _rangeStart,
        endExclusive: _rangeEnd,
      );
      final policy = await AttendancePolicySettings.load();
      final employees = Get.find<HomeController>().employees;
      final names = {
        for (final e in employees)
          if (e.id != null) e.id!: e.name ?? '',
      };
      final workHours = {
        for (final e in employees)
          if (e.id != null)
            e.id!: (
              workHoursFrom: e.workHoursFrom,
              workHoursTo: e.workHoursTo,
            ),
      };
      final rows = AttendanceReportService.aggregate(
        records: records,
        outcomes: outcomes,
        employeeNames: names,
        employeeWorkHours: workHours,
        policy: policy,
      );
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.attendanceReportsLoadFailed.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AttendanceReportRow> get _filteredRows {
    var rows = _rows;
    final q = _filterController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows
          .where((r) => r.employeeName.toLowerCase().contains(q))
          .toList();
    }
    switch (_summaryFilter) {
      case 'showed_up':
        rows = rows.where((r) => r.showedUpDays > 0).toList();
      case 'absent':
        rows = rows.where((r) => r.absentDays > 0).toList();
      case 'pending':
        rows = rows.where((r) => r.pendingDays > 0).toList();
    }
    return rows;
  }

  Future<void> _exportCsv() async {
    final csv = AttendanceReportService.toCsv(_filteredRows, _csvHeaders);
    final filename =
        'attendance_${_period == _ReportPeriod.month ? 'month' : 'year'}_${_periodLabel.replaceAll(' ', '_')}.csv';
    await downloadAttendanceReportFile(contents: csv, fileName: filename);
    FunHelper.showSnackbar(
      'common.confirm'.tr,
      AppLocaleKeys.attendanceReportsExportCsv.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  Future<void> _exportPdf() async {
    final text = AttendanceReportService.toPlainTextReport(
      title: '${AppLocaleKeys.attendanceReportsTitle.tr} — $_periodLabel',
      rows: _filteredRows,
      headers: _csvHeaders,
    );
    final filename =
        'attendance_${_period == _ReportPeriod.month ? 'month' : 'year'}_${_periodLabel.replaceAll(' ', '_')}.txt';
    await downloadAttendanceReportFile(contents: text, fileName: filename);
    FunHelper.showSnackbar(
      'common.confirm'.tr,
      AppLocaleKeys.attendanceReportsExportPdf.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  Future<void> _pickPeriod() async {
    if (_period == _ReportPeriod.month) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _anchor,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDatePickerMode: DatePickerMode.year,
      );
      if (picked != null) {
        setState(() {
          _anchor = DateTime(picked.year, picked.month, 1);
          _syncPeriodLabel();
        });
        await _loadReport();
      }
      return;
    }
    final year = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final current = DateTime.now().year;
        return AlertDialog(
          title: Text(AppLocaleKeys.attendanceReportsSelectYear.tr),
          content: SizedBox(
            width: 300,
            height: 300,
            child: ListView.builder(
              itemCount: current - 2019,
              itemBuilder: (_, i) {
                final y = current - i;
                return ListTile(
                  title: Text('$y'),
                  onTap: () => Navigator.pop(ctx, y),
                );
              },
            ),
          ),
        );
      },
    );
    if (year != null) {
      setState(() {
        _anchor = DateTime(year, 1, 1);
        _syncPeriodLabel();
      });
      await _loadReport();
    }
  }

  Widget _buildPeriodTypeFilter(BuildContext context) {
    final textStyle = _filterTextStyle(context);
    return SizedBox(
      height: _filterHeight,
      child: DecoratedBox(
        decoration: _filterDecoration,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_ReportPeriod>(
            isExpanded: true,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            value: _period,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade600,
            ),
            style: textStyle,
            items: [
              DropdownMenuItem(
                value: _ReportPeriod.month,
                child: Text(
                  AppLocaleKeys.attendanceReportsPeriodMonth.tr,
                  style: textStyle,
                ),
              ),
              DropdownMenuItem(
                value: _ReportPeriod.year,
                child: Text(
                  AppLocaleKeys.attendanceReportsPeriodYear.tr,
                  style: textStyle,
                ),
              ),
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() {
                _period = value;
                _syncPeriodLabel();
              });
              await _loadReport();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodValueFilter() {
    return InputText(
      readOnly: true,
      onTap: _pickPeriod,
      controller: _periodController,
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

  Widget _buildSummaryFilter(BuildContext context) {
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
              AppLocaleKeys.attendanceReportsFilterSummary.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
            value: _summaryFilter.isEmpty ? null : _summaryFilter,
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
                child: Text(AppLocaleKeys.attendanceAbsent.tr, style: textStyle),
              ),
              DropdownMenuItem(
                value: 'pending',
                child: Text(AppLocaleKeys.attendancePending.tr, style: textStyle),
              ),
            ],
            onChanged: (value) {
              setState(() => _summaryFilter = value ?? '');
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
          _buildPeriodTypeFilter(context),
          const SizedBox(height: 12),
          _buildPeriodValueFilter(),
          const SizedBox(height: 12),
          _buildEmployeeFilter(),
          const SizedBox(height: 12),
          _buildSummaryFilter(context),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 3, child: _buildPeriodTypeFilter(context)),
        const SizedBox(width: 10),
        Expanded(flex: 4, child: _buildPeriodValueFilter()),
        const SizedBox(width: 10),
        Expanded(flex: 5, child: _buildEmployeeFilter()),
        const SizedBox(width: 10),
        Expanded(flex: 4, child: _buildSummaryFilter(context)),
      ],
    );
  }

  Widget _buildCountChip({
    required int value,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      alignment: Alignment.center,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildDataTable(List<AttendanceReportRow> rows) {
    return HorizontalScrollbarTable(
      child: SizedBox(
        width: (Get.width - 270).clamp(900.0, double.infinity),
        child: DataTable(
          dataRowMinHeight: 60,
          dataRowMaxHeight: 60,
          dataRowColor: WidgetStateProperty.all(Colors.white),
          dividerThickness: 0.5,
          columns: [
            DataColumn(
              columnWidth: const FixedColumnWidth(220),
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
                AppLocaleKeys.attendanceShowedUp.tr,
                style: _columnHeaderStyle,
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(140),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendanceAbsent.tr,
                style: _columnHeaderStyle,
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(140),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendancePending.tr,
                style: _columnHeaderStyle,
              ),
            ),
          ],
          rows: rows
              .map(
                (row) => DataRow(
                  cells: [
                    DataCell(
                      TableCellCenter(
                        child: Text(
                          row.employeeName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      TableCellCenter(
                        child: _buildCountChip(
                          value: row.showedUpDays,
                          fg: const Color(0xFF0F9D58),
                          bg: const Color(0xFFEAF8F1),
                        ),
                      ),
                    ),
                    DataCell(
                      TableCellCenter(
                        child: _buildCountChip(
                          value: row.absentDays,
                          fg: Colors.red.shade700,
                          bg: Colors.red.shade50,
                        ),
                      ),
                    ),
                    DataCell(
                      TableCellCenter(
                        child: _buildCountChip(
                          value: row.pendingDays,
                          fg: Colors.orange.shade800,
                          bg: Colors.orange.shade50,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final rows = _filteredRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 50),
        Row(
          children: [
            Text(
              AppLocaleKeys.attendanceReportsTitle.tr,
              style: TextStyle(
                color: AppColors.fontColorGrey,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            MainButton(
              width: 140,
              height: 40,
              borderSize: 8,
              fontColor: AppColors.primary,
              backgroundColor: Colors.white,
              borderColor: AppColors.primary,
              title: AppLocaleKeys.attendanceReportsExportCsv.tr,
              enabled: !_loading && rows.isNotEmpty,
              onPressed: _exportCsv,
            ),
            const SizedBox(width: 8),
            MainButton(
              width: 140,
              height: 40,
              borderSize: 8,
              fontColor: Colors.white,
              backgroundColor: AppColors.primary,
              title: AppLocaleKeys.attendanceReportsExportPdf.tr,
              enabled: !_loading && rows.isNotEmpty,
              onPressed: _exportPdf,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => Get.offNamed('/attendance'),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(AppLocaleKeys.attendanceTitle.tr),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildFilters(context),
        const SizedBox(height: 10),
        if (_loading)
          const TableAreaLoading()
        else if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                AppLocaleKeys.attendanceNoRecords.tr,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          _buildDataTable(rows),
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
      selectedTab: 13,
      body: Responsive(
        mobile: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: _buildContent(context),
        ),
        desktop: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            width: Responsive.isDesktop(context) ? Get.width - 270 : Get.width,
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }
}
