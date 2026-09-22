import 'package:flutter/material.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_quick_send_button.dart';
import 'package:point/View/Os/os_document_action_button.dart';

/// Compact send-via-WhatsApp icon used in OS document action bars.
class OsWhatsappSendIconButton extends StatefulWidget {
  const OsWhatsappSendIconButton({
    super.key,
    required this.purpose,
    required this.onSend,
    this.iconSize = 20,
    this.constraints,
    this.color,
  });

  final String purpose;
  final Future<void> Function() onSend;
  final double iconSize;
  final BoxConstraints? constraints;
  final Color? color;

  @override
  State<OsWhatsappSendIconButton> createState() =>
      _OsWhatsappSendIconButtonState();
}

class _OsWhatsappSendIconButtonState extends State<OsWhatsappSendIconButton> {
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
    return osWhatsappQuickSendScope(
      purpose: widget.purpose,
      builder: (enabled, tooltip) {
        final canPress = enabled && !_loading;
        return Tooltip(
          message: tooltip,
          child: IconButton(
            onPressed: canPress ? _send : null,
            visualDensity: VisualDensity.compact,
            constraints: widget.constraints,
            icon: osDocumentActionIcon(
              loading: _loading,
              icon: Icons.send_outlined,
              size: widget.iconSize,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}
