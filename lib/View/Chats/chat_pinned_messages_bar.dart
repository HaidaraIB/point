import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';

/// Telegram-style pinned messages bar: cycles through multiple pins, opens list sheet.
class ChatPinnedMessagesBar extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> pinnedDocs;
  final bool isGroup;
  final void Function(String messageId) onTapMessage;

  const ChatPinnedMessagesBar({
    super.key,
    required this.pinnedDocs,
    required this.isGroup,
    required this.onTapMessage,
  });

  @override
  State<ChatPinnedMessagesBar> createState() => _ChatPinnedMessagesBarState();
}

class _ChatPinnedMessagesBarState extends State<ChatPinnedMessagesBar> {
  int _activeIndex = 0;
  List<String> _lastPinIds = const [];

  @override
  void didUpdateWidget(ChatPinnedMessagesBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.pinnedDocs.map((d) => d.id).toList(growable: false);
    if (!listEquals(ids, _lastPinIds)) {
      _lastPinIds = ids;
      _activeIndex = 0;
    } else if (_activeIndex >= widget.pinnedDocs.length) {
      _activeIndex = widget.pinnedDocs.isEmpty
          ? 0
          : widget.pinnedDocs.length - 1;
    }
  }

  void _setIndex(int next) {
    if (widget.pinnedDocs.isEmpty) return;
    final clamped = next.clamp(0, widget.pinnedDocs.length - 1);
    if (clamped == _activeIndex) return;
    setState(() => _activeIndex = clamped);
  }

  void _openAllPinsSheet() {
    final docs = widget.pinnedDocs;
    if (docs.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  AppLocaleKeys.chatAllPinnedMessages.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final msg = doc.data();
                    final sender = (msg['senderName'] as String?)?.trim() ?? '';
                    final preview = chatReplyPreviewFromMessage(msg);
                    final subtitle = widget.isGroup && sender.isNotEmpty
                        ? '$sender: $preview'
                        : preview;
                    return ListTile(
                      leading: Icon(
                        Icons.push_pin_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      title: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _activeIndex = i);
                        widget.onTapMessage(doc.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = widget.pinnedDocs;
    if (docs.isEmpty) return const SizedBox.shrink();

    final doc = docs[_activeIndex];
    final message = doc.data();
    final sender = (message['senderName'] as String?)?.trim() ?? '';
    final preview = chatReplyPreviewFromMessage(message);
    final titleColor = AppColors.primary;
    final multiple = docs.length > 1;
    final title = multiple
        ? AppLocaleKeys.chatPinnedMessageNOfM.trParams({
            'n': '${_activeIndex + 1}',
            'm': '${docs.length}',
          })
        : AppLocaleKeys.chatPinnedMessageLabel.tr;

    Widget barContent = Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onTapMessage(doc.id),
          onLongPress: multiple ? _openAllPinsSheet : null,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 28,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: titleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: multiple ? _openAllPinsSheet : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: titleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isGroup && sender.isNotEmpty
                            ? '$sender: $preview'
                            : preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (multiple && kIsWeb) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: const Icon(Icons.west, size: 20),
                    onPressed: _activeIndex > 0
                        ? () => _setIndex(_activeIndex - 1)
                        : null,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: const Icon(Icons.east, size: 20),
                    onPressed: _activeIndex < docs.length - 1
                        ? () => _setIndex(_activeIndex + 1)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (multiple && !kIsWeb) {
      barContent = GestureDetector(
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -200) {
            _setIndex(_activeIndex + 1);
          } else if (v > 200) {
            _setIndex(_activeIndex - 1);
          }
        },
        child: barContent,
      );
    }

    return barContent;
  }
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> findPinnedMessageDocs(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final pinned = docs.where((d) => d.data()['isPinned'] == true).toList();
  pinned.sort((a, b) {
    final aData = a.data();
    final bData = b.data();
    final aPinned = aData['pinnedAt'];
    final bPinned = bData['pinnedAt'];
    if (aPinned is Timestamp && bPinned is Timestamp) {
      return bPinned.compareTo(aPinned);
    }
    if (aPinned is Timestamp) return -1;
    if (bPinned is Timestamp) return 1;
    final aTs = aData['timestamp'];
    final bTs = bData['timestamp'];
    if (aTs is Timestamp && bTs is Timestamp) {
      return bTs.compareTo(aTs);
    }
    return 0;
  });
  return pinned;
}
