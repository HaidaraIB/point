import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/chat_message_actions.dart';
import 'package:point/View/Chats/chat_message_display.dart';
import 'package:point/View/Chats/chat_reply_draft_banner.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';

/// Dark compact popup menu (Telegram-like).
const Color _kChatMenuBg = Color(0xFF2C2F3E);
const double _kChatMenuWidth = 200;
const double _kEditHistoryPanelW = 280;
const double _kEditHistoryPanelH = 360;
/// Must match [ActionPane.extentRatio] for swipe-to-reply without tapping the action.
const double _kReplySwipeExtentRatio = 0.22;

/// Message row: swipe to reply, long-press for copy / edit / delete / history.
class ChatMessageTile extends StatefulWidget {
  final String chatId;
  final String messageId;
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isGroup;
  final String senderName;
  final bool showGroupSenderName;
  final Timestamp? timestamp;
  final String Function(Timestamp?) formatTime;
  final bool isAdmin;
  final String currentUserId;
  /// Display name of the signed-in user (for edit history and saving [editedByName]).
  final String? currentUserDisplayName;
  final void Function(ChatReplyDraft draft) onReply;
  final BoxDecoration bubbleDecoration;
  final double maxWidthFactor;
  final Alignment alignment;
  final CrossAxisAlignment columnCrossAxis;
  /// When true and [isMe], shows delivered/read icons (mobile/popup chat).
  final bool showReadReceipts;
  final bool messageIsRead;
  /// Scroll the chat list so the referenced message is visible (Telegram-style).
  final void Function(String replyToMessageId)? onReplyPreviewTap;

  const ChatMessageTile({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.message,
    required this.isMe,
    required this.isGroup,
    required this.senderName,
    required this.showGroupSenderName,
    required this.timestamp,
    required this.formatTime,
    required this.isAdmin,
    required this.currentUserId,
    this.currentUserDisplayName,
    required this.onReply,
    required this.bubbleDecoration,
    this.maxWidthFactor = 0.72,
    required this.alignment,
    required this.columnCrossAxis,
    this.showReadReceipts = false,
    this.messageIsRead = false,
    this.onReplyPreviewTap,
  });

  @override
  State<ChatMessageTile> createState() => _ChatMessageTileState();
}

class _ChatMessageTileState extends State<ChatMessageTile>
    with SingleTickerProviderStateMixin {
  final GlobalKey _bubbleKey = GlobalKey(debugLabel: 'chatMessageBubble');

  late final SlidableController _slidableController;
  VoidCallback? _swipeReplyAnimListener;

  @override
  void initState() {
    super.initState();
    _slidableController = SlidableController(this);
    _slidableController.endGesture.addListener(_onSlidableEndGesture);
  }

  @override
  void dispose() {
    if (_swipeReplyAnimListener != null) {
      _slidableController.animation.removeListener(_swipeReplyAnimListener!);
      _swipeReplyAnimListener = null;
    }
    _slidableController.endGesture.removeListener(_onSlidableEndGesture);
    _slidableController.dispose();
    super.dispose();
  }

  /// When the user releases past the open threshold, the pane animates open;
  /// then we reply and close — no tap on the action button (Telegram-style).
  void _onSlidableEndGesture() {
    if (_slidableController.endGesture.value == null) return;

    if (_swipeReplyAnimListener != null) {
      _slidableController.animation.removeListener(_swipeReplyAnimListener!);
      _swipeReplyAnimListener = null;
    }

    void listener() {
      if (!mounted) return;
      final r = _slidableController.ratio.abs();
      if (r >= _kReplySwipeExtentRatio * 0.92) {
        _slidableController.animation.removeListener(listener);
        _swipeReplyAnimListener = null;
        _emitReply();
        unawaited(_slidableController.close());
        return;
      }
      if (r < 0.001) {
        _slidableController.animation.removeListener(listener);
        _swipeReplyAnimListener = null;
      }
    }

    _swipeReplyAnimListener = listener;
    _slidableController.animation.addListener(listener);
    listener();

    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (_swipeReplyAnimListener == listener) {
        _slidableController.animation.removeListener(listener);
        _swipeReplyAnimListener = null;
      }
    });
  }

  bool get _deleted => widget.message['deleted'] == true;

  bool get _canEditText {
    if (_deleted) return false;
    final t = (widget.message['messageType'] as String?)?.trim();
    final isText = t == null || t.isEmpty || t == 'text';
    if (!isText) return false;
    final sender = (widget.message['senderId'] ?? '').toString();
    if (sender == widget.currentUserId) return true;
    return widget.isAdmin;
  }

  /// Clipboard: only the typed body or caption — never URLs, filenames, or placeholders.
  String _copyablePlainText() {
    if (_deleted) return '';
    final type = (widget.message['messageType'] as String?)?.trim() ?? 'text';
    final raw = (widget.message['text'] ?? '').toString().trim();
    final attachmentUrl = (widget.message['attachmentUrl'] as String?)?.trim() ?? '';

    if (type == 'text' || type.isEmpty) {
      return raw;
    }

    if (type == 'image') {
      if (raw.isEmpty || raw == '📷') return '';
      return raw;
    }
    if (type == 'video') {
      if (raw.isEmpty || raw == '🎬') return '';
      return raw;
    }
    if (type == 'file') {
      final fn = (widget.message['fileName'] as String?)?.trim() ?? '';
      if (raw.isEmpty || raw == '📎' || raw == fn) return '';
      return raw;
    }
    if (type == 'voice') {
      if (raw.isEmpty) return '';
      if (raw == attachmentUrl) return '';
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return '';
      }
      return raw;
    }

    if (raw.isEmpty) return '';
    if (raw == attachmentUrl) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return '';
    return raw;
  }

  void _emitReply() {
    final preview = chatReplyPreviewFromMessage(widget.message);
    final name =
        widget.isGroup
            ? (widget.message['senderName'] as String?)?.trim()
            : null;
    widget.onReply(
      ChatReplyDraft(
        messageId: widget.messageId,
        preview: preview,
        replySenderName: (name != null && name.isNotEmpty) ? name : null,
        replyImageUrl: replyImageUrlFromMessage(widget.message),
        replyVideoUrl: replyVideoUrlFromMessage(widget.message),
      ),
    );
  }

  /// Message bubble bounds in the nearest [Overlay] coordinate system.
  Rect? _bubbleRectInOverlay() {
    final ctx = _bubbleKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final oOrigin = overlay.localToGlobal(Offset.zero);
    final g1 = box.localToGlobal(Offset.zero);
    final g2 = box.localToGlobal(box.size.bottomRight(Offset.zero));
    return Rect.fromLTRB(
      g1.dx - oOrigin.dx,
      g1.dy - oOrigin.dy,
      g2.dx - oOrigin.dx,
      g2.dy - oOrigin.dy,
    );
  }

  /// Positions the edit-history panel next to the bubble (same side as [showMenu]).
  Rect _editHistoryPanelRect(Rect bubbleInOverlay) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final Size s = overlay.size;
    const gap = 6.0;
    final openToLeft = widget.alignment == Alignment.centerRight;
    final panelW = _kEditHistoryPanelW;
    final panelH = _kEditHistoryPanelH;

    double left;
    if (openToLeft) {
      left = (bubbleInOverlay.left - gap - panelW).clamp(
        8.0,
        s.width - panelW - 8,
      );
    } else {
      left = (bubbleInOverlay.right + gap).clamp(8.0, s.width - panelW - 8);
    }

    final pad = MediaQuery.paddingOf(context);
    double top = bubbleInOverlay.center.dy - panelH / 2;
    top = top.clamp(
      pad.top + 8,
      s.height - panelH - pad.bottom - 8,
    );
    return Rect.fromLTWH(left, top, panelW, panelH);
  }

  /// [bubbleRect] in overlay coordinates.
  RelativeRect _menuPositionBesideBubble(Rect bubbleInOverlay) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final Size s = overlay.size;
    const gap = 6.0;
    const menuW = _kChatMenuWidth;
    // Own messages align to center-right → open menu to the left of the bubble.
    final bool openToLeft = widget.alignment == Alignment.centerRight;
    double left;
    if (openToLeft) {
      left = (bubbleInOverlay.left - gap - menuW).clamp(
        8.0,
        s.width - menuW - 8,
      );
    } else {
      left = (bubbleInOverlay.right + gap).clamp(8.0, s.width - menuW - 8);
    }
    // Vertically center menu on bubble; clamp to safe area
    final pad = MediaQuery.paddingOf(context);
    final estMenuH = 42.0 * _menuItemCount() + 8;
    double top =
        bubbleInOverlay.center.dy - estMenuH / 2;
    top = top.clamp(
      pad.top + 8,
      s.height - estMenuH - pad.bottom - 8,
    );
    final anchor = Rect.fromLTWH(left, top, menuW, 1);
    return RelativeRect.fromRect(anchor, Offset.zero & s);
  }

  /// Resolved editor display name for one edit doc (stored name, then heuristics).
  String _editorLabelForEdit(Map<String, dynamic> d) {
    final stored = (d['editedByName'] as String?)?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    final uid = (d['editedBy'] ?? '').toString().trim();
    if (uid.isEmpty) return '';
    if (uid == widget.currentUserId) {
      final n = widget.currentUserDisplayName?.trim();
      if (n != null && n.isNotEmpty) return n;
      return AppLocaleKeys.me.tr;
    }
    final senderId = (widget.message['senderId'] ?? '').toString();
    if (uid == senderId) return widget.senderName;
    return AppLocaleKeys.chatSenderFallback.tr;
  }

  int _menuItemCount() {
    var n = 1; // reply
    final copyText = _copyablePlainText();
    if (!_deleted && copyText.isNotEmpty) n++;
    if (_canEditText) n++;
    if (widget.message['edited'] == true) n++;
    if (widget.isAdmin && !_deleted) n++;
    return n;
  }

  Future<void> _showEditHistory() async {
    final bubble = _bubbleRectInOverlay();
    if (bubble == null || !mounted) return;
    final panel = _editHistoryPanelRect(bubble);
    final fs = FirebaseFirestore.instance;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) {
        final theme = Theme.of(dialogContext);
        return SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: panel.left,
                top: panel.top,
                width: panel.width,
                height: panel.height,
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surface,
                  surfaceTintColor: theme.colorScheme.surfaceTint,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history,
                              size: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AppLocaleKeys.chatEditHistoryTitle.tr,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: theme.dividerColor,
                      ),
                      Expanded(
                        child: StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream:
                              fs
                                  .collection('chats')
                                  .doc(widget.chatId)
                                  .collection('messages')
                                  .doc(widget.messageId)
                                  .collection('edits')
                                  .orderBy('editedAt', descending: true)
                                  .limit(24)
                                  .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              );
                            }
                            final docs = snap.data!.docs;
                            if (docs.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    AppLocaleKeys.chatEditedLabel.tr,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.only(bottom: 8),
                              itemCount: docs.length,
                              separatorBuilder:
                                  (_, __) => Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: theme.dividerColor.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                              itemBuilder: (context, i) {
                                final d = docs[i].data();
                                final prev =
                                    (d['previousText'] ?? '').toString();
                                final ts = d['editedAt'] as Timestamp?;
                                final when =
                                    ts != null
                                        ? DateFormat(
                                          'MMM d, yyyy · HH:mm',
                                          Localizations.localeOf(
                                            context,
                                          ).toString(),
                                        ).format(ts.toDate())
                                        : '';
                                final editorLabel = _editorLabelForEdit(d);
                                return _ChatEditHistoryEntryRow(
                                  previousText: prev,
                                  editorLabel: editorLabel,
                                  whenLabel: when,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runEdit() async {
    final prev = (widget.message['text'] ?? '').toString();
    final controller = TextEditingController(text: prev);
    final next = await Get.dialog<String?>(
      AlertDialog(
        title: Text(AppLocaleKeys.chatEditMessageTitle.tr),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.multiline,
          maxLines: 6,
          minLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(AppLocaleKeys.commonCancel.tr),
          ),
          TextButton(
            onPressed: () {
              final t = controller.text.trim();
              if (t.isEmpty) return;
              Get.back(result: t);
            },
            child: Text('common.save'.tr),
          ),
        ],
      ),
    );
    if (next == null || next == prev) return;
    try {
      final editorName = widget.currentUserDisplayName?.trim();
      await ChatMessageActions.applyTextEdit(
        fs: FirebaseFirestore.instance,
        chatId: widget.chatId,
        messageId: widget.messageId,
        previousText: prev,
        newText: next.trim(),
        editedBy: widget.currentUserId,
        editedByName:
            (editorName != null && editorName.isNotEmpty)
                ? editorName
                : (widget.isMe
                    ? widget.senderName
                    : AppLocaleKeys.chatSenderFallback.tr),
      );
    } catch (e) {
      _showChatFeedback(
        AppLocaleKeys.errorTitle.tr,
        AppLocaleKeys.errorGeneric.tr,
        isError: true,
      );
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(AppLocaleKeys.chatConfirmDeleteAdminTitle.tr),
        content: Text(AppLocaleKeys.chatConfirmDeleteAdminBody.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(AppLocaleKeys.commonCancel.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(AppLocaleKeys.chatActionDelete.tr),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ChatMessageActions.softDeleteMessage(
        fs: FirebaseFirestore.instance,
        chatId: widget.chatId,
        messageId: widget.messageId,
        deletedBy: widget.currentUserId,
      );
    } catch (e) {
      _showChatFeedback(
        AppLocaleKeys.errorTitle.tr,
        AppLocaleKeys.errorGeneric.tr,
        isError: true,
      );
    }
  }

  /// Opaque, high-contrast feedback (avoids GetX default frosted/blurred snackbar).
  void _showChatFeedback(
    String title,
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;
    final bg =
        isError ? const Color(0xFF8E1A1A) : const Color(0xFF2D2D2D);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
          content: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: bg,
      colorText: Colors.white,
      barBlur: 0,
      borderRadius: 12,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
      icon: Icon(
        isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
        color: Colors.white,
      ),
      shouldIconPulse: false,
      titleText: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      messageText: Text(
        message,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _openContextMenu() {
    final bubbleInOverlay = _bubbleRectInOverlay();
    if (bubbleInOverlay == null) return;

    final copyText = _copyablePlainText();
    final editedFlag = widget.message['edited'] == true;
    final colorScheme = Theme.of(context).colorScheme;

    void runAfterClose(VoidCallback fn) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) fn();
      });
    }

    final entries = <PopupMenuEntry<void>>[
      PopupMenuItem<void>(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: () => runAfterClose(_emitReply),
        child: _ChatMenuRow(
          icon: Icons.reply_rounded,
          label: AppLocaleKeys.chatActionReply.tr,
        ),
      ),
      if (!_deleted && copyText.isNotEmpty)
        PopupMenuItem<void>(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            runAfterClose(() {
              Clipboard.setData(ClipboardData(text: copyText));
              _showChatFeedback(
                AppLocaleKeys.successTitle.tr,
                AppLocaleKeys.chatCopyDone.tr,
              );
            });
          },
          child: _ChatMenuRow(
            icon: Icons.copy_outlined,
            label: AppLocaleKeys.chatActionCopy.tr,
          ),
        ),
      if (_canEditText)
        PopupMenuItem<void>(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () => runAfterClose(_runEdit),
          child: _ChatMenuRow(
            icon: Icons.edit_outlined,
            label: AppLocaleKeys.chatActionEdit.tr,
          ),
        ),
      if (editedFlag)
        PopupMenuItem<void>(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () => runAfterClose(_showEditHistory),
          child: _ChatMenuRow(
            icon: Icons.history,
            label: AppLocaleKeys.chatEditHistoryTitle.tr,
          ),
        ),
      if (widget.isAdmin && !_deleted)
        PopupMenuItem<void>(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () => runAfterClose(_confirmDelete),
          child: _ChatMenuRow(
            icon: Icons.delete_outline,
            label: AppLocaleKeys.chatActionDelete.tr,
            destructive: true,
            dangerColor: colorScheme.error,
          ),
        ),
    ];

    showMenu<void>(
      context: context,
      position: _menuPositionBesideBubble(bubbleInOverlay),
      color: _kChatMenuBg,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      menuPadding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: _kChatMenuWidth,
        maxWidth: _kChatMenuWidth,
      ),
      items: entries,
    );
  }

  Widget _replyQuoteBar(BuildContext context) {
    final id = (widget.message['replyToMessageId'] as String?)?.trim();
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    final preview = replyQuotePreviewLine(widget.message);
    final name = (widget.message['replySenderName'] as String?)?.trim();
    final thumb =
        (widget.message['replyImageUrl'] as String?)?.trim() ?? '';
    final videoThumb =
        (widget.message['replyVideoUrl'] as String?)?.trim() ?? '';
    final border = widget.isMe ? Colors.white24 : Colors.black26;
    final fg = widget.isMe ? Colors.white70 : Colors.black54;
    final mq = MediaQuery.sizeOf(context);
    final maxBar =
        (mq.width * widget.maxWidthFactor - 24).clamp(120.0, mq.width);

    final inner = Container(
      constraints: BoxConstraints(maxWidth: maxBar),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: border, width: 3)),
        color:
            widget.isMe
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (thumb.isNotEmpty || videoThumb.isNotEmpty) ...[
            ChatReplyMediaThumb(
              imageUrl: thumb.isNotEmpty ? thumb : null,
              videoUrl: videoThumb.isNotEmpty ? videoThumb : null,
              size: 40,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isGroup && name != null && name.isNotEmpty)
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final tap = widget.onReplyPreviewTap;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child:
          tap != null
              ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => tap(id),
                  borderRadius: BorderRadius.circular(6),
                  child: inner,
                ),
              )
              : inner,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final replyLabel = AppLocaleKeys.chatActionReply.tr;
    final slidableChild = GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onDoubleTap: _emitReply,
      onLongPress: _openContextMenu,
      child: Align(
        alignment: widget.alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: mq.width * widget.maxWidthFactor),
          child: Column(
            crossAxisAlignment: widget.columnCrossAxis,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showGroupSenderName)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    widget.senderName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              Container(
                key: _bubbleKey,
                decoration: widget.bubbleDecoration,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _replyQuoteBar(context),
                    chatMessageBubbleContent(
                      Map<String, dynamic>.from(widget.message),
                      widget.isMe,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.formatTime(widget.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                widget.isMe
                                    ? Colors.white70
                                    : Colors.black54,
                          ),
                        ),
                        if (widget.message['edited'] == true && !_deleted) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _showEditHistory,
                            child: Text(
                              AppLocaleKeys.chatEditedLabel.tr,
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color:
                                    widget.isMe
                                        ? Colors.white60
                                        : Colors.black45,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                        if (widget.showReadReceipts && widget.isMe) ...[
                          const SizedBox(width: 6),
                          Icon(
                            widget.messageIsRead
                                ? Icons.done_all
                                : Icons.done,
                            size: 14,
                            color:
                                widget.messageIsRead
                                    ? Colors.blue
                                    : Colors.grey,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // One pane only (see flutter_slidable: start vs end + text direction).
    // Right-aligned: swipe left; left-aligned: swipe right. Two panes allowed both directions.
    final rightAligned = widget.alignment == Alignment.centerRight;
    final replyPane = ActionPane(
      motion: const DrawerMotion(),
      extentRatio: _kReplySwipeExtentRatio,
      children: [
        SlidableAction(
          onPressed: (_) {},
          autoClose: false,
          backgroundColor: const Color(0xFF21B7CA),
          foregroundColor: Colors.white,
          icon: Icons.reply_rounded,
          label: replyLabel,
        ),
      ],
    );

    return Slidable(
      key: ValueKey<String>('msg_${widget.messageId}'),
      controller: _slidableController,
      closeOnScroll: true,
      startActionPane: rightAligned ? replyPane : null,
      endActionPane: rightAligned ? null : replyPane,
      child: slidableChild,
    );
  }
}

/// One previous text version in the anchored edit-history panel.
class _ChatEditHistoryEntryRow extends StatelessWidget {
  final String previousText;
  final String editorLabel;
  final String whenLabel;

  const _ChatEditHistoryEntryRow({
    required this.previousText,
    required this.editorLabel,
    required this.whenLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final body = cs.onSurface;
    final muted = cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.history, size: 20, color: muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  previousText.isEmpty ? '—' : previousText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: body,
                    height: 1.35,
                  ),
                ),
                if (editorLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    AppLocaleKeys.chatEditHistoryBy.trParams({'name': editorLabel}),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11.5,
                      color: muted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                if (whenLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    whenLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11.5,
                      color: muted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final Color? dangerColor;

  const _ChatMenuRow({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.dangerColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg =
        destructive && dangerColor != null
            ? dangerColor!
            : Colors.white.withValues(alpha: 0.95);
    return Row(
      children: [
        Icon(icon, size: 20, color: fg),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ],
    );
  }
}
