import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Whether [msg] counts as "read" for opening the chat at the last-read position.
///
/// Own messages always count as read; others require [isRead] == true.
bool chatMessageIsReadForScrollAnchor(
  Map<String, dynamic> msg,
  String currentUserId,
) {
  if (msg['senderId'] == currentUserId) return true;
  return msg['isRead'] == true;
}

/// Newest-first list (`reverse: true`): index `0` is latest. Returns the index
/// of the **chronologically newest** message that counts as read for the user.
int chatReverseListAnchorIndexLastRead({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  required String currentUserId,
}) {
  if (docs.isEmpty) return 0;
  for (var i = 0; i < docs.length; i++) {
    if (chatMessageIsReadForScrollAnchor(docs[i].data(), currentUserId)) {
      return i;
    }
  }
  return 0;
}

/// Pixels from the newest end before we consider the user "at latest".
const double kChatAtLatestScrollThreshold = 24;

/// Average row height hint for index estimation (variable-height rows).
const double kChatEstimatedRowHeight = 72;

/// Reverse [ListView]: index `0` is newest at the bottom; offset `0` is latest.
bool chatReverseListShowsLatestFromScroll(ScrollController controller) {
  if (!controller.hasClients) return false;
  return controller.offset <= kChatAtLatestScrollThreshold;
}

/// Smallest visible index (newest edge) estimated from scroll offset.
int chatReverseListEstimatedMinVisibleIndex(
  ScrollController controller,
  int itemCount,
) {
  if (itemCount <= 0 || !controller.hasClients) return 0;
  if (controller.offset <= kChatAtLatestScrollThreshold) return 0;
  final idx = (controller.offset / kChatEstimatedRowHeight).floor();
  return idx.clamp(0, itemCount - 1);
}

/// Items newer than the viewport top (off-screen toward the bottom).
int chatReverseListNewerBelowCountFromScroll(
  ScrollController controller,
  int itemCount,
) {
  if (itemCount <= 0) return 0;
  return chatReverseListEstimatedMinVisibleIndex(controller, itemCount);
}

/// Unread incoming messages in the "below" range (same ordering as list).
int chatReverseListUnreadIncomingBelowCountFromScroll({
  required ScrollController controller,
  required int itemCount,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  required String currentUserId,
}) {
  final below = chatReverseListNewerBelowCountFromScroll(controller, itemCount);
  if (below <= 0) return 0;
  var n = 0;
  for (var i = 0; i < below && i < docs.length; i++) {
    final d = docs[i].data();
    if (d['senderId'] != currentUserId && d['isRead'] != true) {
      n++;
    }
  }
  return n;
}

/// Floating scroll-to-latest control (Telegram-like) + optional count badge.
class ChatScrollToLatestFab extends StatelessWidget {
  final bool visible;
  final int badgeCount;
  final VoidCallback onPressed;

  const ChatScrollToLatestFab({
    super.key,
    required this.visible,
    required this.badgeCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2B2F38) : const Color(0xFFE8EAED);
    final iconColor = isDark ? Colors.white : const Color(0xFF3C4043);

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: iconColor,
                    size: 28,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3390EC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
