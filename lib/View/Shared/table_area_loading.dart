import 'package:flutter/material.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Centered loading indicator for table/list content areas.
class TableAreaLoading extends StatelessWidget {
  const TableAreaLoading({super.key, this.minHeight = 320});

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: minHeight,
      width: double.infinity,
      child: Center(
        child: CircularProgressIndicator(color: context.appTheme.accentText),
      ),
    );
  }
}
