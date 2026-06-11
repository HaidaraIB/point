import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/AttendanceRecordModel.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Chats/chat_cached_attachment_image.dart';
import 'package:point/View/Chats/chat_message_display.dart';
import 'package:point/View/Shared/HorizontalScroll.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/TableCellCenter.dart';
import 'package:point/View/Shared/responsive.dart';

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
    return result;
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
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 4, child: _buildDateFilter()),
        const SizedBox(width: 10),
        Expanded(flex: 6, child: _buildEmployeeFilter()),
        const SizedBox(width: 10),
        Expanded(flex: 4, child: _buildActionFilter(context)),
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

  Widget _buildDataTable(List<AttendanceRecordModel> records) {
    return HorizontalScrollbarTable(
      child: SizedBox(
        width: (Get.width - 270).clamp(1100.0, double.infinity),
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

  Widget _buildPageContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 50),
        Text(
          AppLocaleKeys.attendanceTitle.tr,
          style: TextStyle(
            color: AppColors.fontColorGrey,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _buildFilters(context),
        const SizedBox(height: 10),
        StreamBuilder<List<AttendanceRecordModel>>(
          stream: FirestoreServices.streamAttendanceForDate(_selectedDate),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('error'.tr)),
              );
            }

            final filtered = _filterRecords(snapshot.data ?? const []);
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

            return _buildDataTable(filtered);
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
