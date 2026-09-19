import 'package:flutter/material.dart';

/// Ensures [ListTile], [SwitchListTile], [CheckboxListTile], and similar
/// widgets have a [Material] ancestor when placed inside decorated containers.
class MaterialListTileScope extends StatelessWidget {
  const MaterialListTileScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(type: MaterialType.transparency, child: child);
  }
}
