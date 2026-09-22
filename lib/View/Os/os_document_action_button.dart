import 'package:flutter/material.dart';
import 'package:point/Utils/app_theme_extension.dart';
/// Shared loading icon for OS document action buttons.
Widget osDocumentActionIcon({
  required bool loading,
  required IconData icon,
  required double size,
  Color? color,
}) {
  if (loading) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
      ),
    );
  }
  return Icon(icon, size: size, color: color);
}

Color _spinnerColorFromStyle(BuildContext context, ButtonStyle? style) {
  final resolved = style?.foregroundColor?.resolve({});
  if (resolved != null) return resolved;
  return Theme.of(context).colorScheme.onPrimary;
}

Widget osDocumentActionLabel(String label, {bool expand = false}) {
  if (!expand) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.center,
    child: Text(
      label,
      maxLines: 1,
      textAlign: TextAlign.center,
      softWrap: false,
    ),
  );
}

/// Compact filled toolbar button with async loading feedback.
class OsDocumentActionFilledButton extends StatefulWidget {
  const OsDocumentActionFilledButton({
    super.key,
    required this.style,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconSize = 18,
    this.tooltip,
    this.expand = false,
  });

  final ButtonStyle style;
  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;
  final double iconSize;
  final String? tooltip;
  final bool expand;

  @override
  State<OsDocumentActionFilledButton> createState() =>
      _OsDocumentActionFilledButtonState();
}

class _OsDocumentActionFilledButtonState
    extends State<OsDocumentActionFilledButton> {
  var _loading = false;

  Future<void> _run() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spinnerColor = _spinnerColorFromStyle(context, widget.style);
    final button = FilledButton.icon(
      onPressed: _loading ? null : _run,
      style: widget.style,
      icon: osDocumentActionIcon(
        loading: _loading,
        icon: widget.icon,
        size: widget.iconSize,
        color: spinnerColor,
      ),
      label: osDocumentActionLabel(widget.label, expand: widget.expand),
    );
    final sized = widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
    final tooltip = widget.tooltip;
    if (tooltip == null || tooltip.isEmpty) return sized;
    return Tooltip(message: tooltip, child: sized);
  }
}

/// Compact outlined toolbar button with async loading feedback.
class OsDocumentActionOutlinedButton extends StatefulWidget {
  const OsDocumentActionOutlinedButton({
    super.key,
    required this.style,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconSize = 18,
    this.tooltip,
    this.expand = false,
  });

  final ButtonStyle style;
  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;
  final double iconSize;
  final String? tooltip;
  final bool expand;

  @override
  State<OsDocumentActionOutlinedButton> createState() =>
      _OsDocumentActionOutlinedButtonState();
}

class _OsDocumentActionOutlinedButtonState
    extends State<OsDocumentActionOutlinedButton> {
  var _loading = false;

  Future<void> _run() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spinnerColor = _spinnerColorFromStyle(context, widget.style);
    final button = OutlinedButton.icon(
      onPressed: _loading ? null : _run,
      style: widget.style,
      icon: osDocumentActionIcon(
        loading: _loading,
        icon: widget.icon,
        size: widget.iconSize,
        color: spinnerColor,
      ),
      label: osDocumentActionLabel(widget.label, expand: widget.expand),
    );
    final sized = widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
    final tooltip = widget.tooltip;
    if (tooltip == null || tooltip.isEmpty) return sized;
    return Tooltip(message: tooltip, child: sized);
  }
}

/// Compact 36×36 icon action with async loading feedback.
class OsDocumentActionIconButton extends StatefulWidget {
  const OsDocumentActionIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconSize = 18,
    this.color,
    this.constraints = const BoxConstraints(minWidth: 36, minHeight: 36),
  });

  final IconData icon;
  final Future<void> Function() onPressed;
  final String? tooltip;
  final double iconSize;
  final Color? color;
  final BoxConstraints constraints;

  @override
  State<OsDocumentActionIconButton> createState() =>
      _OsDocumentActionIconButtonState();
}

class _OsDocumentActionIconButtonState extends State<OsDocumentActionIconButton> {
  var _loading = false;

  Future<void> _run() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spinnerColor = widget.color ?? context.appTheme.accentText;
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: widget.constraints,
      padding: EdgeInsets.zero,
      tooltip: widget.tooltip,
      onPressed: _loading ? null : _run,
      icon: osDocumentActionIcon(
        loading: _loading,
        icon: widget.icon,
        size: widget.iconSize,
        color: spinnerColor,
      ),
    );
  }
}
