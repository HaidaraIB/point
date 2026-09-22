import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_quick_send_button.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_document_action_button.dart';

class OsWhatsappSendFilledButton extends StatefulWidget {
  const OsWhatsappSendFilledButton({
    super.key,
    required this.purpose,
    required this.onSend,
    this.style,
    this.icon = Icons.send_outlined,
    this.iconSize = 18,
    this.label,
    this.expand = false,
  });

  final String purpose;
  final Future<void> Function() onSend;
  final ButtonStyle? style;
  final IconData icon;
  final double iconSize;
  final String? label;
  final bool expand;

  @override
  State<OsWhatsappSendFilledButton> createState() =>
      _OsWhatsappSendFilledButtonState();
}

class _OsWhatsappSendFilledButtonState extends State<OsWhatsappSendFilledButton> {
  var _loading = false;

  Future<void> _send() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onSend();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? OsButtonStyles.whatsappCompact();
    return osWhatsappQuickSendScope(
      purpose: widget.purpose,
      builder: (enabled, tooltip) {
        final canPress = enabled && !_loading;
        final label = widget.label ?? AppLocaleKeys.osInvoicesWhatsapp.tr;
        final button = FilledButton.icon(
          onPressed: canPress ? _send : null,
          style: style,
          icon: osDocumentActionIcon(
            loading: _loading,
            icon: widget.icon,
            size: widget.iconSize,
            color: Colors.white,
          ),
          label: osDocumentActionLabel(label, expand: widget.expand),
        );
        final sized = widget.expand
            ? SizedBox(width: double.infinity, child: button)
            : button;
        return Tooltip(
          message: tooltip,
          child: sized,
        );
      },
    );
  }
}

class OsWhatsappSendOutlinedButton extends StatefulWidget {
  const OsWhatsappSendOutlinedButton({
    super.key,
    required this.purpose,
    required this.onSend,
    this.style,
    this.icon = Icons.send_outlined,
    this.iconSize = 18,
    this.label,
  });

  final String purpose;
  final Future<void> Function() onSend;
  final ButtonStyle? style;
  final IconData icon;
  final double iconSize;
  final String? label;

  @override
  State<OsWhatsappSendOutlinedButton> createState() =>
      _OsWhatsappSendOutlinedButtonState();
}

class _OsWhatsappSendOutlinedButtonState
    extends State<OsWhatsappSendOutlinedButton> {
  var _loading = false;

  Future<void> _send() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onSend();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ?? OsButtonStyles.outlinedCompact(context.appTheme);
    return osWhatsappQuickSendScope(
      purpose: widget.purpose,
      builder: (enabled, tooltip) {
        final canPress = enabled && !_loading;
        return Tooltip(
          message: tooltip,
          child: OutlinedButton.icon(
            onPressed: canPress ? _send : null,
            style: style,
            icon: osDocumentActionIcon(
              loading: _loading,
              icon: widget.icon,
              size: widget.iconSize,
            ),
            label: Text(
              widget.label ?? AppLocaleKeys.osInvoicesWhatsapp.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
