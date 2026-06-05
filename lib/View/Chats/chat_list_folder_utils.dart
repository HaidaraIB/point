import 'dart:async';

import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';

/// Chat list chips, add button, and loading indicators (matches composer accent).
const Color kChatUiAccent = AppColors.primary;

/// Sidebar / mobile chat list folder (Telegram-style).
enum ChatListFolder { all, privateChats, groups }

List<Map<String, dynamic>> filterChatsByFolder(
  List<Map<String, dynamic>> chats,
  ChatListFolder folder,
) {
  switch (folder) {
    case ChatListFolder.groups:
      return chats.where((c) => c['isGroup'] == true).toList();
    case ChatListFolder.privateChats:
      return chats.where((c) => c['isGroup'] != true).toList();
    case ChatListFolder.all:
      return List<Map<String, dynamic>>.from(chats);
  }
}

/// Keeps [chats] order for unpinned rows; prepends pinned rows in [pinOrder] order.
List<Map<String, dynamic>> sortChatsPinnedFirst(
  List<Map<String, dynamic>> chats,
  List<String> pinOrderNewestFirst,
) {
  if (pinOrderNewestFirst.isEmpty) return chats;
  final byId = <String, Map<String, dynamic>>{
    for (final c in chats) c['id'] as String: c,
  };
  final pinned = <Map<String, dynamic>>[];
  for (final id in pinOrderNewestFirst) {
    final c = byId[id];
    if (c != null) pinned.add(c);
  }
  final pinnedIds = pinned.map((c) => c['id'] as String).toSet();
  final rest = <Map<String, dynamic>>[];
  for (final c in chats) {
    if (!pinnedIds.contains(c['id'] as String)) rest.add(c);
  }
  return [...pinned, ...rest];
}

/// Small pin badge on the avatar when a chat is pinned in the list.
Widget chatListLeadingWithPinBadge({
  required Widget avatarChild,
  required bool pinned,
}) {
  if (!pinned) return avatarChild;
  return Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      avatarChild,
      PositionedDirectional(
        top: -2,
        end: -4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 2,
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(
              Icons.push_pin_rounded,
              size: 12,
              color: kChatUiAccent,
            ),
          ),
        ),
      ),
    ],
  );
}

class ChatListFolderTabs extends StatelessWidget {
  const ChatListFolderTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ChatListFolder selected;
  final ValueChanged<ChatListFolder> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(ChatListFolder f, String label) {
      final sel = selected == f;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelected(f),
            borderRadius: BorderRadius.circular(20),
            splashColor: kChatUiAccent.withValues(alpha: 0.15),
            highlightColor: kChatUiAccent.withValues(alpha: 0.08),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? kChatUiAccent : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? kChatUiAccent : Colors.grey.shade300,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                  color: sel ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(ChatListFolder.all, AppLocaleKeys.chatFolderAll.tr),
              chip(
                ChatListFolder.privateChats,
                AppLocaleKeys.chatFolderPrivate.tr,
              ),
              chip(ChatListFolder.groups, AppLocaleKeys.chatFolderGroups.tr),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating context menu for pin / unpin chat (list row), anchored at [globalPosition].
Future<void> showChatListPinContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required String chatId,
  required bool isPinned,
  required Future<void> Function(String id) onTogglePin,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final size = overlay.size;
  final position = RelativeRect.fromRect(
    Rect.fromCenter(center: globalPosition, width: 1, height: 1),
    Offset.zero & size,
  );

  await showMenu<void>(
    context: context,
    position: position,
    color: const Color(0xFF2C2F3E),
    elevation: 10,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    menuPadding: EdgeInsets.zero,
    items: [
      PopupMenuItem<void>(
        padding: EdgeInsets.zero,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          minVerticalPadding: 10,
          leading: Icon(
            isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
            color: const Color(0xFFE8ECFF),
            size: 22,
          ),
          title: Text(
            isPinned
                ? AppLocaleKeys.chatListUnpinChat.tr
                : AppLocaleKeys.chatListPinChat.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        onTap: () {
          unawaited(onTogglePin(chatId));
        },
      ),
    ],
  );
}
