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
import 'package:point/View/Shared/app_filter_dropdown.dart';
import 'package:point/View/Shared/app_multi_filter.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Shared/table_area_loading.dart';
import 'package:point/Utils/app_theme_extension.dart';

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
  List<String> _summaryFilters = [];
  List<AttendanceReportRow> _rows = const [];
  bool _loading = true;

  TextStyle _columnHeaderStyle(BuildContext context) => TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 13,
    color: context.appTheme.secondaryText,
  );

  static const double _filterHeight = 42;
  static const double _filterRadius = 5;

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
    if (_summaryFilters.isNotEmpty) {
      rows = rows.where((r) {
        for (final f in _summaryFilters) {
          if (f == 'showed_up' && r.showedUpDays > 0) return true;
          if (f == 'absent' && r.absentDays > 0) return true;
          if (f == 'pending' && r.pendingDays > 0) return true;
        }
        return false;
      }).toList();
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
    return AppMultiFilterTrigger(
      hint: AppLocaleKeys.attendanceReportsPeriodMonth.tr,
      items: const ['month', 'year'],
      selected: [_period == _ReportPeriod.month ? 'month' : 'year'],
      itemLabel: (v) => v == 'month'
          ? AppLocaleKeys.attendanceReportsPeriodMonth.tr
          : AppLocaleKeys.attendanceReportsPeriodYear.tr,
      onChanged: (v) async {
        if (v.isEmpty) return;
        final next = v.last == 'year' ? _ReportPeriod.year : _ReportPeriod.month;
        setState(() {
          _period = next;
          _syncPeriodLabel();
        });
        await _loadReport();
      },
    );
  }

  Widget _buildPeriodValueFilter() {
    return InputText(
      readOnly: true,
      onTap: _pickPeriod,
      controller: _periodController,
      hintText: AppLocaleKeys.attendanceSelectDate.tr,
      height: _filterHeight,
      borderRadius: _filterRadius,
      suffixIcon: Icon(
        Icons.calendar_today_outlined,
        size: 18,
        color: context.appTheme.accentText,
      ),
    );
  }

  Widget _buildEmployeeFilter(BuildContext context) {
    return InputText(
      prefixIcon: Icon(
        CupertinoIcons.search,
        color: context.appTheme.mutedText,
      ),
      hintText: AppLocaleKeys.attendanceFilterEmployee.tr,
      controller: _filterController,
      height: _filterHeight,
      borderRadius: _filterRadius,
      onchange: (_) {
        setState(() {});
        return null;
      },
    );
  }

  Widget _buildSummaryFilter(BuildContext context) {
    return AppMultiFilterTrigger(
      hint: AppLocaleKeys.attendanceReportsFilterSummary.tr,
      items: const ['showed_up', 'absent', 'pending'],
      selected: _summaryFilters,
      itemLabel: (v) {
        switch (v) {
          case 'showed_up':
            return AppLocaleKeys.attendanceShowedUp.tr;
          case 'absent':
            return AppLocaleKeys.attendanceAbsent.tr;
          case 'pending':
            return AppLocaleKeys.attendancePending.tr;
          default:
            return v;
        }
      },
      onChanged: (v) => setState(() => _summaryFilters = v),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final activeTags = <Widget>[];
    appendAppActiveFilterTags(
      out: activeTags,
      dimension: AppLocaleKeys.attendanceReportsFilterSummary.tr,
      selected: _summaryFilters,
      itemLabel: (v) {
        switch (v) {
          case 'showed_up':
            return AppLocaleKeys.attendanceShowedUp.tr;
          case 'absent':
            return AppLocaleKeys.attendanceAbsent.tr;
          case 'pending':
            return AppLocaleKeys.attendancePending.tr;
          default:
            return v;
        }
      },
      onRemove: (v) =>
          setState(() => _summaryFilters = List.of(_summaryFilters)..remove(v)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isMobile ? double.infinity : 160,
              child: _buildPeriodTypeFilter(context),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 180,
              child: _buildPeriodValueFilter(),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 220,
              child: _buildEmployeeFilter(context),
            ),
            _buildSummaryFilter(context),
            FilterResetButton(
              onPressed: () {
                setState(() {
                  _filterController.clear();
                  _summaryFilters = [];
                });
              },
            ),
          ],
        ),
        if (activeTags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: activeTags),
        ],
      ],
    );
  }

  Widget _buildCountChip(
    BuildContext context, {
    required int value,
    required Color fg,
    required Color lightBg,
  }) {
    return Container(
      alignment: Alignment.center,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.statusChipBackground(fg, lightBg),
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

  BoxDecoration _mobileCardDecoration(BuildContext context) => BoxDecoration(
        color: context.appTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appTheme.border),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );

  Widget _buildExportButtons(List<AttendanceReportRow> rows, {bool expanded = false}) {
    final csvButton = MainButton(
      width: expanded ? double.infinity : 140,
      height: 40,
      borderSize: 8,
      margin: expanded ? EdgeInsets.zero : null,
      fontColor: context.appTheme.accentText,
      backgroundColor: context.appTheme.inputFill,
      borderColor: AppColors.primary,
      title: AppLocaleKeys.attendanceReportsExportCsv.tr,
      enabled: !_loading && rows.isNotEmpty,
      onPressed: _exportCsv,
    );
    final pdfButton = MainButton(
      width: expanded ? double.infinity : 140,
      height: 40,
      borderSize: 8,
      margin: expanded ? EdgeInsets.zero : null,
      fontColor: Colors.white,
      backgroundColor: AppColors.primary,
      title: AppLocaleKeys.attendanceReportsExportPdf.tr,
      enabled: !_loading && rows.isNotEmpty,
      onPressed: _exportPdf,
    );

    if (expanded) {
      return Row(
        children: [
          Expanded(child: csvButton),
          const SizedBox(width: 8),
          Expanded(child: pdfButton),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        csvButton,
        const SizedBox(width: 8),
        pdfButton,
      ],
    );
  }

  Widget _buildHeader(BuildContext context, List<AttendanceReportRow> rows) {
    final titleStyle = TextStyle(
      color: context.appTheme.secondaryText,
      fontSize: 17,
      fontWeight: FontWeight.bold,
    );

    if (Responsive.isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppLocaleKeys.attendanceReportsTitle.tr, style: titleStyle),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => Get.offNamed('/attendance'),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(AppLocaleKeys.attendanceTitle.tr),
            ),
          ),
          const SizedBox(height: 4),
          _buildExportButtons(rows, expanded: true),
        ],
      );
    }

    return Row(
      children: [
        Text(AppLocaleKeys.attendanceReportsTitle.tr, style: titleStyle),
        const Spacer(),
        _buildExportButtons(rows),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => Get.offNamed('/attendance'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(AppLocaleKeys.attendanceTitle.tr),
        ),
      ],
    );
  }

  Widget _buildMobileReportList(List<AttendanceReportRow> rows) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Container(
            decoration: _mobileCardDecoration(context),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  rows[i].employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            AppLocaleKeys.attendanceShowedUp.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appTheme.mutedText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildCountChip(
                            context,
                            value: rows[i].showedUpDays,
                            fg: const Color(0xFF0F9D58),
                            lightBg: const Color(0xFFEAF8F1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            AppLocaleKeys.attendanceAbsent.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appTheme.mutedText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildCountChip(
                            context,
                            value: rows[i].absentDays,
                            fg: Colors.red.shade700,
                            lightBg: Colors.red.shade50,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            AppLocaleKeys.attendancePending.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appTheme.mutedText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildCountChip(
                            context,
                            value: rows[i].pendingDays,
                            fg: Colors.orange.shade800,
                            lightBg: Colors.orange.shade50,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDataTable(List<AttendanceReportRow> rows) {
    return HorizontalScrollbarTable(
      child: SizedBox(
        width: (Get.width - 270).clamp(900.0, double.infinity),
        child: DataTable(
          dataRowMinHeight: 60,
          dataRowMaxHeight: 60,
          dataRowColor: context.tableDataRowColor,
          headingRowColor: context.tableHeadingRowColor,
          dividerThickness: 0.5,
          columns: [
            DataColumn(
              columnWidth: const FixedColumnWidth(220),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendanceEmployee.tr,
                style: _columnHeaderStyle(context),
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(140),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendanceShowedUp.tr,
                style: _columnHeaderStyle(context),
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(140),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendanceAbsent.tr,
                style: _columnHeaderStyle(context),
              ),
            ),
            DataColumn(
              columnWidth: const FixedColumnWidth(140),
              headingRowAlignment: MainAxisAlignment.center,
              label: Text(
                AppLocaleKeys.attendancePending.tr,
                style: _columnHeaderStyle(context),
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      TableCellCenter(
                        child: _buildCountChip(
                          context,
                          value: row.showedUpDays,
                          fg: const Color(0xFF0F9D58),
                          lightBg: const Color(0xFFEAF8F1),
                        ),
                      ),
                    ),
                    DataCell(
                      TableCellCenter(
                        child: _buildCountChip(
                          context,
                          value: row.absentDays,
                          fg: Colors.red.shade700,
                          lightBg: Colors.red.shade50,
                        ),
                      ),
                    ),
                    DataCell(
                      TableCellCenter(
                        child: _buildCountChip(
                          context,
                          value: row.pendingDays,
                          fg: Colors.orange.shade800,
                          lightBg: Colors.orange.shade50,
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
    final isMobile = Responsive.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: isMobile ? 24 : 50),
        _buildHeader(context, rows),
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
                style: TextStyle(color: context.appTheme.mutedText),
              ),
            ),
          )
        else if (isMobile)
          _buildMobileReportList(rows)
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
