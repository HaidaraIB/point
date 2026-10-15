import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';

/// [ChatListRowTrailing] whose presence line tracks live presence: private
/// chats show online / last seen for [otherUserId]; groups show the
/// connected count among [participantIds].
class ChatListPresenceTrailing extends StatelessWidget {
  final bool isGroup;
  final String? otherUserId;
  final List<String> participantIds;
  final String selfUserId;
  final int unreadCount;

  const ChatListPresenceTrailing({
    super.key,
    required this.isGroup,
    this.otherUserId,
    this.participantIds = const [],
    required this.selfUserId,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<HomeController>()) {
      return ChatListRowTrailing(unreadCount: unreadCount);
    }
    return Obx(() {
      final presence = chatPresenceMapForObx()!;
      if (isGroup) {
        final count = chatGroupConnectedCountFromPresence(
          presence,
          participantIds,
          selfUserId,
        );
        return ChatListRowTrailing(
          titleSubline: AppLocaleKeys.chatConnectedCount.trParams({
            'count': '$count',
          }),
          unreadCount: unreadCount,
        );
      }
      final id = otherUserId?.trim() ?? '';
      final at = id.isEmpty ? null : presence[id];
      return ChatListRowTrailing(
        titleSubline: chatPrivatePresenceLabelFromLastSeen(at),
        highlightSubline: chatIsOnlineFromLastSeen(at),
        unreadCount: unreadCount,
      );
    });
  }
}

/// Trailing column for chat list rows: optional presence / status line + unread badge.
class ChatListRowTrailing extends StatelessWidget {
  final String? titleSubline;
  final bool highlightSubline;
  final int unreadCount;

  const ChatListRowTrailing({
    super.key,
    this.titleSubline,
    this.highlightSubline = false,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (titleSubline == null && unreadCount <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (titleSubline != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              titleSubline!,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.0,
                color: highlightSubline
                    ? const Color(0xFF16A34A)
                    : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (titleSubline != null && unreadCount > 0) const SizedBox(height: 2),
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              unreadCount > 99 ? '99+' : '$unreadCount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
