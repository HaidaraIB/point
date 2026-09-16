import 'package:flutter/material.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Shared/HorizontalScroll.dart';
import 'package:point/View/Shared/TableCellCenter.dart';

export 'package:point/View/Shared/TableCellCenter.dart';

/// Desktop data table used by content, clients, employees, and OS screens.
///
/// Same Material [DataTable] chrome: heading/row colors from the theme,
/// centered headers, and [HorizontalScrollbarTable] so wide tables scroll
/// instead of crushing columns.
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth = 1100,
    this.columnSpacing = 24,
    this.horizontalMargin = 24,
    this.dataRowMinHeight = 60,
    this.dataRowMaxHeight = 60,
    this.onSelectAll,
    this.showCheckboxColumn = true,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double minWidth;
  final double columnSpacing;
  final double horizontalMargin;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final ValueChanged<bool?>? onSelectAll;

  /// When false, rows must not set [DataRow.onSelectChanged] — use an explicit
  /// checkbox column instead so only the box toggles selection.
  final bool showCheckboxColumn;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < minWidth
            ? minWidth
            : constraints.maxWidth;
        return HorizontalScrollbarTable(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 14),
            child: SizedBox(
              width: width,
              child: DataTable(
                columnSpacing: columnSpacing,
                horizontalMargin: horizontalMargin,
                dataRowMinHeight: dataRowMinHeight,
                dataRowMaxHeight: dataRowMaxHeight,
                dataRowColor: context.tableDataRowColor,
                headingRowColor: context.tableHeadingRowColor,
                dividerThickness: 0.5,
                showCheckboxColumn: showCheckboxColumn,
                onSelectAll: showCheckboxColumn ? onSelectAll : null,
                columns: columns,
                rows: rows,
              ),
            ),
          ),
        );
      },
    );
  }
}

DataColumn appDataColumn(
  BuildContext context,
  String label, {
  double? width,
}) {
  return DataColumn(
    columnWidth: width == null ? null : FixedColumnWidth(width),
    headingRowAlignment: MainAxisAlignment.center,
    label: Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: context.appTheme.secondaryText,
      ),
    ),
  );
}

DataCell appDataCell(Widget child) {
  return DataCell(TableCellCenter(child: child));
}

/// Start-aligned cell (e.g. avatar + name) so rows stack instead of centering.
DataCell appDataCellStart(Widget child) {
  return DataCell(
    SizedBox(
      width: double.infinity,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: child,
      ),
    ),
  );
}
