import 'package:flutter/material.dart';

/// Actions returned from [showTelegramStyleAttachmentMenu].
enum ChatAttachmentMenuAction { photo, file, pasteImage, voice }

/// Dark vertical popup anchored to [anchorContext] (e.g. the + button), similar
/// in spirit to Telegram’s attachment menu — not feature parity, only layout/feel.
Future<ChatAttachmentMenuAction?> showTelegramStyleAttachmentMenu({
  required BuildContext context,
  required BuildContext anchorContext,
  required String photoLabel,
  required String fileLabel,
  required String pasteImageLabel,
  required String voiceLabel,
}) {
  final buttonObject = anchorContext.findRenderObject();
  if (buttonObject is! RenderBox) {
    return Future<ChatAttachmentMenuAction?>.value(null);
  }
  final OverlayState overlayState = Overlay.of(anchorContext);
  final overlayObject = overlayState.context.findRenderObject();
  if (overlayObject is! RenderBox) {
    return Future<ChatAttachmentMenuAction?>.value(null);
  }
  final RenderBox button = buttonObject;
  final RenderBox overlayBox = overlayObject;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlayBox),
      button.localToGlobal(
        Offset(button.size.width, button.size.height),
        ancestor: overlayBox,
      ),
    ),
    Offset.zero & overlayBox.size,
  );

  const Color menuBg = Color(0xFF2C2F3E);
  const Color iconColor = Color(0xFFF0F0F5);

  return showMenu<ChatAttachmentMenuAction>(
    context: context,
    position: position,
    color: menuBg,
    elevation: 16,
    shadowColor: Colors.black54,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    items: <PopupMenuEntry<ChatAttachmentMenuAction>>[
      PopupMenuItem<ChatAttachmentMenuAction>(
        value: ChatAttachmentMenuAction.photo,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: _TelegramMenuRow(
          icon: Icons.perm_media_outlined,
          label: photoLabel,
          iconColor: iconColor,
        ),
      ),
      PopupMenuItem<ChatAttachmentMenuAction>(
        value: ChatAttachmentMenuAction.file,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: _TelegramMenuRow(
          icon: Icons.insert_drive_file_outlined,
          label: fileLabel,
          iconColor: iconColor,
        ),
      ),
      PopupMenuItem<ChatAttachmentMenuAction>(
        value: ChatAttachmentMenuAction.pasteImage,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: _TelegramMenuRow(
          icon: Icons.content_paste,
          label: pasteImageLabel,
          iconColor: iconColor,
        ),
      ),
      PopupMenuItem<ChatAttachmentMenuAction>(
        value: ChatAttachmentMenuAction.voice,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: _TelegramMenuRow(
          icon: Icons.mic_none_outlined,
          label: voiceLabel,
          iconColor: iconColor,
        ),
      ),
    ],
  );
}

class _TelegramMenuRow extends StatelessWidget {
  const _TelegramMenuRow({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
