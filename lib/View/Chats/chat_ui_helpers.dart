import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';

/// scroll_to_index asserts `duration > Duration.zero`; use 1ms for instant jumps.
const Duration kChatInstantScrollDuration = Duration(milliseconds: 1);

/// Presence heartbeat interval (see [HomeController._presenceHeartbeatInterval]).
const Duration kEmployeePresenceHeartbeatInterval = Duration(seconds: 90);

/// User is "online" when last heartbeat is within this window.
const Duration kEmployeePresenceOnlineWindow = Duration(minutes: 2);

/// Max distinct presence docs watched by non-manager employees in chat UI.
const int kEmployeePresenceWatchIdCap = 30;

/// Collect other participants from chat rows for targeted presence listeners.
Set<String> presenceWatchIdsFromChats(
  Iterable<Map<String, dynamic>> chats,
  String selfUserId, {
  int cap = kEmployeePresenceWatchIdCap,
}) {
  final self = selfUserId.trim();
  if (self.isEmpty) return const {};
  final ids = <String>{};
  for (final ch in chats) {
    for (final raw in List<String>.from(ch['participants'] ?? const [])) {
      final id = raw.trim();
      if (id.isEmpty || id == self) continue;
      ids.add(id);
      if (ids.length >= cap) return ids;
    }
  }
  return ids;
}

/// Call at the top of an [Obx] builder so GetX tracks presence map updates.
RxMap<String, DateTime>? chatPresenceMapForObx() {
  if (!Get.isRegistered<HomeController>()) return null;
  final map = Get.find<HomeController>().employeePresenceById;
  map.length;
  return map;
}

Future<void> chatScrollToIndexInstant(
  AutoScrollController controller,
  int index, {
  AutoScrollPosition? preferPosition,
}) {
  return controller.scrollToIndex(
    index,
    preferPosition: preferPosition,
    duration: kChatInstantScrollDuration,
  );
}

/// Tracks whether the user is actively scrolling the chat message list.
class ChatScrollInteraction {
  ChatScrollInteraction._();

  static int _dragDepth = 0;
  static Timer? _activityTimer;

  static bool get userIsScrolling => _dragDepth > 0;

  static void onScrollStart() {
    _dragDepth++;
    _armActivityEndTimer();
  }

  static void onScrollEnd() {
    if (_dragDepth > 0) _dragDepth--;
    _armActivityEndTimer();
  }

  /// Wheel / trackpad updates between start and end.
  static void onScrollActivity() {
    if (_dragDepth == 0) _dragDepth = 1;
    _armActivityEndTimer();
  }

  static void _armActivityEndTimer() {
    _activityTimer?.cancel();
    _activityTimer = Timer(const Duration(milliseconds: 150), () {
      _dragDepth = 0;
    });
  }

  /// Clears stale scroll activity after chat switch or list reset.
  static void reset() {
    _activityTimer?.cancel();
    _activityTimer = null;
    _dragDepth = 0;
  }
}

/// Chat list / message canvas background.
Color chatShellBackground(BuildContext context) =>
    context.appTheme.pageBackground;

/// Sidebar and list panel surface.
Color chatListPanelBackground(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? context.appTheme.elevatedSurface
      : context.appTheme.cardSurface;
}

Color chatSearchFieldFill(BuildContext context) => context.appTheme.inputFill;

/// Incoming message bubble on desktop/web chat.
Color chatIncomingBubbleColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? context.appTheme.elevatedSurface
    : Colors.grey.shade100;

/// Incoming bubble where light mode uses solid white (mobile / popup).
Color chatIncomingBubbleColorBright(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? context.appTheme.elevatedSurface
    : Colors.white;

Color chatPinnedBarBackground(BuildContext context) =>
    context.appTheme.panelTint;

Color chatAvatarPlaceholder(BuildContext context) =>
    context.appTheme.unselected;

Color chatListSelectedTile(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? context.appTheme.panelTint
    : Colors.grey.shade100;

Color chatBubbleTextColor(BuildContext context, bool isMe) => isMe
    ? Colors.white
    : (Theme.of(context).brightness == Brightness.dark
        ? context.appTheme.primaryText
        : Colors.black);

Color chatBubbleMutedTextColor(BuildContext context, bool isMe) => isMe
    ? Colors.white70
    : (Theme.of(context).brightness == Brightness.dark
        ? context.appTheme.mutedText
        : Colors.black54);

/// Android/iOS camera capture for chat attachments (not web/desktop).
bool chatMobileCameraSupported() {
  return !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

/// Scrolls a reverse chat [ListView] so the item at [index] is visible.
void scheduleScrollChatToMessageIndex({
  required AutoScrollController controller,
  required int index,
  required bool Function() mounted,
  Duration duration = const Duration(milliseconds: 380),
  Curve curve = Curves.easeOutCubic,
  double alignment = 0.35,
}) {
  if (index < 0) return;
  var attempts = 0;
  var blockedByScrollRetries = 0;
  void tryScroll() {
    if (!mounted()) return;
    if (ChatScrollInteraction.userIsScrolling) {
      blockedByScrollRetries++;
      if (blockedByScrollRetries > 8) return;
      Future<void>.delayed(const Duration(milliseconds: 150), tryScroll);
      return;
    }
    if (!controller.hasClients) {
      attempts++;
      if (attempts > 24) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
      return;
    }
    final prefer = alignment >= 0.65
        ? AutoScrollPosition.end
        : (alignment <= 0.35
              ? AutoScrollPosition.begin
              : AutoScrollPosition.middle);
    unawaited(
      controller.scrollToIndex(
        index,
        preferPosition: prefer,
        duration: duration,
      ),
    );
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
}

/// Scrolls a **reverse** chat list to the newest message (scroll offset `0`).
void scheduleScrollChatToLatest({
  required ScrollController controller,
  required bool Function() mounted,
  Duration duration = const Duration(milliseconds: 320),
  Curve curve = Curves.easeOutCubic,
}) {
  var attempts = 0;
  var blockedByScrollRetries = 0;
  void tryScroll() {
    if (!mounted()) return;
    if (ChatScrollInteraction.userIsScrolling) {
      blockedByScrollRetries++;
      if (blockedByScrollRetries > 8) return;
      Future<void>.delayed(const Duration(milliseconds: 150), tryScroll);
      return;
    }
    if (!controller.hasClients) {
      attempts++;
      if (attempts > 24) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
      return;
    }
    final target = controller.position.minScrollExtent;
    if (duration <= Duration.zero) {
      controller.jumpTo(target);
      return;
    }
    unawaited(
      controller.animateTo(target, duration: duration, curve: curve).catchError((
        _,
      ) {
        if (mounted() && controller.hasClients) {
          controller.jumpTo(target);
        }
      }),
    );
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
}

/// Reply target while composing (references an existing message).
class ChatReplyDraft {
  final String messageId;
  final String preview;
  final String? replySenderName;

  /// Thumbnail URL when the quoted message is an image (`attachmentUrl`).
  final String? replyImageUrl;

  /// Video file URL when the quoted message is a video (thumbnail generated client-side).
  final String? replyVideoUrl;

  const ChatReplyDraft({
    required this.messageId,
    required this.preview,
    this.replySenderName,
    this.replyImageUrl,
    this.replyVideoUrl,
  });
}

/// Short snippet for storing on the outgoing message (`replyPreview`).
String chatReplyPreviewFromMessage(Map<String, dynamic> m) {
  if (m['deleted'] == true) {
    return '🗑';
  }
  final type = (m['messageType'] as String?)?.trim() ?? 'text';
  final text = (m['text'] ?? '').toString().trim();
  switch (type) {
    case 'voice':
      final voiceUrl = (m['attachmentUrl'] as String?)?.trim() ?? '';
      if (text.isNotEmpty &&
          text != '🎤' &&
          text != voiceUrl &&
          !text.startsWith('http://') &&
          !text.startsWith('https://')) {
        if (text.length <= 160) return text;
        return '${text.substring(0, 160)}…';
      }
      return '🎤';
    case 'image':
      if (text.isNotEmpty && text != '📷') {
        if (text.length <= 160) return text;
        return '${text.substring(0, 160)}…';
      }
      return '📷';
    case 'video':
      if (text.isNotEmpty && text != '🎬') {
        if (text.length <= 160) return text;
        return '${text.substring(0, 160)}…';
      }
      return '🎬';
    case 'file':
      final fn = (m['fileName'] as String?)?.trim() ?? '';
      if (text.isNotEmpty && text != fn && text != '📎') {
        if (text.length <= 160) return text;
        return '${text.substring(0, 160)}…';
      }
      return fn.isNotEmpty ? '📎 $fn' : '📎';
    default:
      if (text.isEmpty) return ' ';
      if (text.length <= 160) return text;
      return '${text.substring(0, 160)}…';
  }
}

/// `attachmentUrl` for image messages, for reply thumbnails.
String? replyImageUrlFromMessage(Map<String, dynamic> m) {
  if (m['deleted'] == true) return null;
  final type = (m['messageType'] as String?)?.trim() ?? 'text';
  if (type != 'image') return null;
  final u = (m['attachmentUrl'] as String?)?.trim();
  if (u == null || u.isEmpty) return null;
  return u;
}

/// `attachmentUrl` for video messages (used to generate a thumbnail).
String? replyVideoUrlFromMessage(Map<String, dynamic> m) {
  if (m['deleted'] == true) return null;
  final type = (m['messageType'] as String?)?.trim() ?? 'text';
  if (type != 'video') return null;
  final u = (m['attachmentUrl'] as String?)?.trim();
  if (u == null || u.isEmpty) return null;
  return u;
}

/// Text beside the reply thumbnail in bubbles (avoid raw 📷 / 🎬 when a thumb is shown).
String replyQuotePreviewLine(Map<String, dynamic> m) {
  final preview = (m['replyPreview'] as String?)?.trim() ?? '';
  final hasImg = (m['replyImageUrl'] as String?)?.trim().isNotEmpty ?? false;
  final hasVid = (m['replyVideoUrl'] as String?)?.trim().isNotEmpty ?? false;
  if (hasImg && (preview.isEmpty || preview == '📷')) {
    return AppLocaleKeys.chatReplyMediaPhoto.tr;
  }
  if (hasVid && (preview.isEmpty || preview == '🎬')) {
    return AppLocaleKeys.chatReplyMediaVideo.tr;
  }
  if (preview.isEmpty) {
    return AppLocaleKeys.chatReplyOriginalMissing.tr;
  }
  return preview;
}

String chatInitialFromName(String name) {
  if (name.trim().isEmpty) return '?';
  final parts = name.trim().split(' ');
  return parts.first[0].toUpperCase();
}

bool isChatImageHttpUrl(String? raw) {
  if (raw == null) return false;
  final t = raw.trim();
  return t.startsWith('http://') || t.startsWith('https://');
}

/// شريط تقدم رفيع للشات عند الرفع إلى التخزين (بدون حوار يغطي الشاشة).
class ChatUploadProgressBanner extends StatelessWidget {
  final String chatId;

  const ChatUploadProgressBanner({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HomeController>();
    return Obx(() {
      if (!c.isChatUploadActiveFor(chatId)) return const SizedBox.shrink();
      final p = c.uploadProgress.value.clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'common.uploading'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.appTheme.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 4,
                backgroundColor: context.appTheme.unselected,
                color: context.appTheme.accentText,
              ),
            ),
            const SizedBox(height: 2),
            TextButton(
              onPressed: c.cancelActiveUpload,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                AppLocaleKeys.commonCancel.tr,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTheme.mutedText,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

bool chatIsOnlineFromLastSeen(DateTime? at) {
  if (at == null) return false;
  return DateTime.now().difference(at.toLocal()) <= kEmployeePresenceOnlineWindow;
}

String chatPrivatePresenceLabelFromLastSeen(DateTime? at) {
  if (chatIsOnlineFromLastSeen(at)) {
    final raw = AppLocaleKeys.employeesOnlineNow.tr;
    final lang = Get.locale?.languageCode.toLowerCase() ?? '';
    return lang == 'en' ? raw.toLowerCase() : raw;
  }
  if (at == null) return AppLocaleKeys.employeesLastSeenUnknown.tr;
  return AppLocaleKeys.employeesLastSeenAt.trParams({
    'time': FunHelper.formatTimeAgo(at.toLocal()),
  });
}

int chatGroupConnectedCountFromPresence(
  RxMap<String, DateTime> presence,
  List<String> participantIds,
  String selfUserId,
) {
  var count = 0;
  for (final id in participantIds) {
    if (id == selfUserId) continue;
    if (chatIsOnlineFromLastSeen(presence[id])) count++;
  }
  return count;
}

/// Presence / connected-count subline for chat headers and list trailing text.
class ChatPresenceSubline extends StatelessWidget {
  final bool isGroup;
  final String? otherUserId;
  final List<String> groupParticipantIds;
  final String selfUserId;
  final bool allowEmpty;

  const ChatPresenceSubline({
    super.key,
    required this.isGroup,
    this.otherUserId,
    this.groupParticipantIds = const [],
    required this.selfUserId,
    this.allowEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<HomeController>()) {
      return _buildText(
        context,
        isGroup
            ? AppLocaleKeys.chatConnectedCount.trParams({'count': '0'})
            : AppLocaleKeys.employeesLastSeenUnknown.tr,
        isOnline: false,
      );
    }

    return Obx(() {
      final presence = chatPresenceMapForObx()!;

      if (isGroup) {
        final count = chatGroupConnectedCountFromPresence(
          presence,
          groupParticipantIds,
          selfUserId,
        );
        return _buildText(
          context,
          AppLocaleKeys.chatConnectedCount.trParams({'count': '$count'}),
          isOnline: false,
        );
      }

      final id = otherUserId?.trim() ?? '';
      final at = id.isEmpty ? null : presence[id];
      final online = chatIsOnlineFromLastSeen(at);
      final label = chatPrivatePresenceLabelFromLastSeen(at);
      if (allowEmpty && label.isEmpty) {
        return const SizedBox.shrink();
      }
      return _buildText(context, label, isOnline: online);
    });
  }

  Widget _buildText(BuildContext context, String label, {required bool isOnline}) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        color: !isGroup && isOnline
            ? const Color(0xFF16A34A)
            : context.appTheme.mutedText,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

Widget chatLeadingAvatar({
  required double radius,
  required Color backgroundColor,
  required String initial,
  IconData? groupIcon,
  String? assetImagePath,
  String? imageUrl,
  Color iconColor = Colors.blueGrey,
  Color initialTextColor = Colors.black,
}) {
  Widget fallbackChild() {
    if (groupIcon != null) {
      return Icon(groupIcon, color: iconColor);
    }
    return Text(initial, style: TextStyle(color: initialTextColor));
  }

  final localAsset = assetImagePath?.trim() ?? '';
  if (localAsset.isNotEmpty) {
    final dim = radius * 2;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: Image.asset(
          localAsset,
          width: dim,
          height: dim,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallbackChild(),
        ),
      ),
    );
  }
  if (groupIcon != null) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: fallbackChild(),
    );
  }
  if (isChatImageHttpUrl(imageUrl)) {
    final u = imageUrl!.trim();
    final dim = radius * 2;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: Image.network(
          u,
          width: dim,
          height: dim,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Text(
            initial,
            style: TextStyle(color: initialTextColor, fontSize: 14),
          ),
        ),
      ),
    );
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    child: fallbackChild(),
  );
}

/// Human-readable chat title for list rows and FCM payloads (matches [ChatPage]
/// and chat list localized department titles).
String chatConversationTitleForPushDisplay(Map<String, dynamic> chat) {
  final isGroup = chat['isGroup'] == true;
  if (!isGroup) {
    return (chat['displayName'] ?? '').toString().trim();
  }
  final rawTitle = (chat['title'] ?? '').toString().trim();
  final chatId = (chat['id'] ?? '').toString();
  String? department;
  if (chatId.startsWith('group_') && chatId.length > 6) {
    department = chatId.substring(6);
  }
  department = StorageKeys.normalizeDepartment(
    (department == null || department.isEmpty) ? rawTitle : department,
  );
  if (department.isNotEmpty) {
    return 'department.$department'.tr;
  }
  if (rawTitle.isNotEmpty) {
    return rawTitle.tr;
  }
  return AppLocaleKeys.chatDepartmentGroup.tr;
}
