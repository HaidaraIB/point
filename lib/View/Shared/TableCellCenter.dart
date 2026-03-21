import 'package:flutter/material.dart';

/// Fills the [DataTable] cell width and centers [child] horizontally under the
/// column header (Material aligns data cells to [AlignmentDirectional.centerStart] by default).
class TableCellCenter extends StatelessWidget {
  const TableCellCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Center(child: child),
    );
  }
}
