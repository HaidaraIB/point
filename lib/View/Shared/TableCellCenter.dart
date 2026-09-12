import 'package:flutter/material.dart';

/// Fills the [DataTable] cell width and centers [child] horizontally under the
/// column header (Material aligns data cells to [AlignmentDirectional.centerStart]
/// by default). Uses the same [Row] + [MainAxisAlignment.center] pattern as
/// heading cells so the value lines up with the title.
class TableCellCenter extends StatelessWidget {
  const TableCellCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(fit: FlexFit.loose, child: child),
      ],
    );
  }
}
