import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/Utils/AppNotificationInbox.dart';
import 'package:point/Utils/text_input_bidi.dart';
import 'package:point/Services/AudioService.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/ChatIncomingMessageSound.dart';
import 'package:point/Services/FcmServices.dart' as fcm_notifications;
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/firestore/firestore_chat_api.dart';
import 'package:point/Services/chat_clipboard_image_reader.dart';
import 'package:point/Services/chat_scroll_persistence.dart';
import 'package:point/View/Chats/MChatPage.dart';
import 'package:point/View/Chats/chat_message_display.dart';
import 'package:point/View/Chats/chat_message_tile.dart';
import 'package:point/View/Chats/chat_reply_draft_banner.dart';
import 'package:point/View/Chats/pending_chat_attachment.dart';
import 'package:point/View/Chats/chat_scroll_to_latest_fab.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';
import 'package:point/View/Chats/chat_voice_record_button.dart';
import 'package:point/View/Chats/telegram_style_attachment_menu.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/SideMenu.dart';

class ResponsiveScaffold extends StatelessWidget {
  // final Widget sidebar;
  final Widget body;
  final int selectedTab;
  final int? subSelected;
  final String title;
  final bool? sideMenu;
  ResponsiveScaffold({
    super.key,
    required this.body,
    this.title = '',
    this.subSelected,
    this.sideMenu,
    required this.selectedTab,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // استخدم 1100 ليتطابق مع Responsive.isDesktop وتجنب تكرار الهيدر في النطاق 1000–1100
            if (constraints.maxWidth >= 1100) {
              return Scaffold(
                backgroundColor: Color(0xffF2F2F7),
                // bottomNavigationBar: ,
                // appBar:
                body: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sideMenu != false)
                          SizedBox(
                            child: CustomSidebar(
                              selectedTab: selectedTab,
                              subSelected: subSelected,
                            ),
                          ),
                        Expanded(
                          child: Column(
                            children: [
                              PreferredSize(
                                preferredSize: Size(Get.width, 60),
                                child: Obx(
                                  () => HeaderWidget(
                                    employee: true,

                                    name:
                                        controller.effectiveEmployee?.name ??
                                        '',
                                    role:
                                        controller.effectiveEmployee?.role ??
                                        '',
                                    departments:
                                        controller
                                            .effectiveEmployee
                                            ?.departments ??
                                        const [],
                                    avatarUrl:
                                        controller.effectiveEmployee?.image ??
                                        kDefaultAvatarUrl,
                                  ),
                                ),
                              ),
                              Expanded(child: body),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 20,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: ChatOverlay(),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // شاشة صغيرة (موبايل)
              return Scaffold(
                appBar: PreferredSize(
                  preferredSize: Size(Get.width, 88),
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(22),
                          bottomRight: Radius.circular(22),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            // Left: Menu / Back (محمي من النوتش بسبب SafeArea)
                            if (sideMenu != false)
                              Builder(
                                builder: (context) => Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.menu,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      Scaffold.of(context).openDrawer();
                                    },
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'app.dashboard_title'.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Obx(
                              () => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 6),
                                  _MobileHeaderIconButton(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    count: controller.totalUnreadMessages.value,
                                    onTap: () {
                                      Get.to(
                                        () =>
                                            ChatsListScreen(onMinimize: () {}),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  _MobileHeaderIconButton(
                                    icon: Icons.notifications_none_rounded,
                                    count: unreadInAppInboxCount(
                                      controller.notifications,
                                    ),
                                    onTap: () {
                                      showInAppNotificationsDialog(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                drawer: Drawer(
                  child: CustomSidebar(
                    selectedTab: selectedTab,
                    subSelected: subSelected,
                  ),
                ),
                body: body,
              );
            }
          },
        );
      },
    );
  }
}

class _MobileHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const _MobileHeaderIconButton({
    required this.icon,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = count > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 20),
            onPressed: onTap,
          ),
        ),
        if (hasBadge)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class ChatOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chats = Get.find<HomeController>().openChats;
      if (chats.isEmpty) return const SizedBox();

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: chats.map((c) => ChatPopup(chat: c)).toList(),
      );
    });
  }
}

class ChatPopup extends StatefulWidget {
  final OpenChatModel chat;
  const ChatPopup({super.key, required this.chat});

  @override
  State<ChatPopup> createState() => _ChatPopupState();
}

class _ChatPopupState extends State<ChatPopup> with WidgetsBindingObserver {
  Offset offset = Offset.zero;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messageSoundSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _markReadSubscription;
  late String _chatId;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  PendingChatAttachment? _pendingAttachment;
  ChatReplyDraft? _replyDraft;
  final ItemScrollController _chatMessageItemScrollController =
      ItemScrollController();
  final ItemPositionsListener _chatItemPositionsListener =
      ItemPositionsListener.create();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _orderedChatMessageDocs =
      [];

  late final Future<ChatScrollSnapshot?> _openScrollPrefsFuture;
  ChatScrollSnapshot? _lastScrollSnapshotForPersist;

  static const _kScrollDiskDebounceMs = 350;
  Timer? _scrollDiskFlushTimer;

  /// Remount [ScrollablePositionedList] when restoring from minimized (matches [ChatPage] epoch).
  int _chatMessageListEpoch = 0;

  /// Disk snapshot after expand-from-minimized; [FutureBuilder] prefs can be stale vs [ChatScrollPersistence].
  ChatScrollSnapshot? _diskScrollOverride;

  bool? _scrollFabVisibleLast;
  int _scrollUnreadBelowLast = -1;

  void _flushScrollDiskTimer() {
    _scrollDiskFlushTimer?.cancel();
    _scrollDiskFlushTimer = null;
  }

  void _scheduleDebouncedDiskPersist(String uid) {
    _scrollDiskFlushTimer?.cancel();
    _scrollDiskFlushTimer = Timer(
      const Duration(milliseconds: _kScrollDiskDebounceMs),
      () {
        _scrollDiskFlushTimer = null;
        unawaited(_persistPopupScrollSnapshot(uid));
      },
    );
  }

  Future<void> _persistPopupScrollSnapshot(String uid) async {
    final live = chatScrollSnapshotFromItemPositions(
      _chatItemPositionsListener.itemPositions.value,
    );
    final snap = live ?? _lastScrollSnapshotForPersist;
    if (snap == null) return;
    await ChatScrollPersistence.saveSnapshot(
      userId: uid,
      chatId: _chatId,
      snapshot: snap,
    );
  }

  Future<void> _reloadDiskScrollAfterExpand() async {
    final uid = Get.find<HomeController>().currentEmployee.value?.id;
    if (uid == null || !mounted) return;
    final s = await ChatScrollPersistence.load(uid, _chatId);
    if (!mounted) return;
    setState(() {
      _diskScrollOverride = s;
      _lastScrollSnapshotForPersist = null;
      _chatMessageListEpoch++;
      _scrollFabVisibleLast = null;
      _scrollUnreadBelowLast = -1;
    });
  }

  void _scrollToRepliedMessage(String messageId) {
    final idx = _orderedChatMessageDocs.indexWhere((d) => d.id == messageId);
    if (idx < 0) return;
    scheduleScrollChatToMessageIndex(
      controller: _chatMessageItemScrollController,
      index: idx,
      mounted: () => mounted,
    );
  }

  void _onPopupInputFocus() {
    if (mounted) setState(() {});
  }

  void _onComposerTextChanged() {
    if (mounted) setState(() {});
  }

  KeyEventResult _onComposerKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isEnter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    if (composerShiftPressed()) return KeyEventResult.ignored;
    final busy = Get.find<HomeController>().isUploading.value;
    if (!busy) {
      unawaited(_sendMessage());
    }
    return KeyEventResult.handled;
  }

  Future<void> _showPopupAttachmentMenu(BuildContext anchorContext) async {
    final controller = Get.find<HomeController>();
    if (!mounted) return;

    final action = await showTelegramStyleAttachmentMenu(
      context: context,
      anchorContext: anchorContext,
      photoLabel: 'chat.attach_gallery'.tr,
      fileLabel: 'chat.attach_file'.tr,
      pasteImageLabel: 'chat.paste_image'.tr,
      voiceLabel: 'chat.attach_voice'.tr,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case ChatAttachmentMenuAction.photo:
        final v = await controller.pickOneChatGalleryMedia();
        if (!mounted || v.isEmpty || v.first.bytes == null) return;
        final picked = v.first;
        final url = await controller.uploadFiles(
          filePathOrBytes: picked.bytes!,
          fileName: picked.name,
          useBlockingUploadDialog: false,
        );
        if (url == null || !mounted) return;
        final isVid = chatAttachmentIsVideo(picked.name);
        setState(
          () => _pendingAttachment = PendingChatAttachment(
            messageType: isVid ? 'video' : 'image',
            attachmentUrl: url,
            fileName: isVid ? picked.name : null,
          ),
        );
        controller.uploadedFilesPaths.clear();
        return;
      case ChatAttachmentMenuAction.file:
        final v = await controller.pickOneChatFile();
        if (!mounted || v.isEmpty || v.first.bytes == null) return;
        final url = await controller.uploadFiles(
          filePathOrBytes: v.first.bytes!,
          fileName: v.first.name,
          useBlockingUploadDialog: false,
        );
        if (url == null || !mounted) return;
        setState(
          () => _pendingAttachment = PendingChatAttachment(
            messageType: 'file',
            attachmentUrl: url,
            fileName: v.first.name,
          ),
        );
        controller.uploadedFilesPaths.clear();
        return;
      case ChatAttachmentMenuAction.voice:
        await _showPopupVoiceAttachmentSheet();
        return;
      case ChatAttachmentMenuAction.pasteImage:
        await _pasteImageFromClipboard();
        return;
    }
  }

  Future<void> _pasteImageFromClipboard() async {
    final data = await readClipboardImageData();
    if (!mounted) return;
    if (data == null || data.bytes.isEmpty) {
      _showPasteImageFailed();
      return;
    }
    await _handlePastedImage(data.bytes, data.mimeType);
  }

  Future<void> _handlePastedImage(Uint8List bytes, String mimeType) async {
    if (!mounted) return;
    final controller = Get.find<HomeController>();
    if (controller.isUploading.value) return;

    final fileName =
        'pasted_${DateTime.now().millisecondsSinceEpoch}.${_extFromMime(mimeType)}';
    final url = await controller.uploadFiles(
      filePathOrBytes: bytes,
      fileName: fileName,
      useBlockingUploadDialog: false,
    );
    if (!mounted || url == null) return;
    setState(
      () => _pendingAttachment = PendingChatAttachment(
        messageType: 'image',
        attachmentUrl: url,
      ),
    );
    controller.uploadedFilesPaths.clear();
  }

  String _extFromMime(String mimeType) {
    final t = mimeType.trim().toLowerCase();
    if (t == 'image/jpeg' || t == 'image/jpg') return 'jpg';
    if (t == 'image/webp') return 'webp';
    if (t == 'image/gif') return 'gif';
    if (t == 'image/bmp') return 'bmp';
    return 'png';
  }

  void _showPasteImageFailed() {
    if (!mounted) return;
    FunHelper.showSnackbarDeduped(
      AppLocaleKeys.errorTitle.tr,
      'chat.paste_image_failed'.tr,
      dedupeKey: 'chat_paste_image_failed',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      autoHideAfter: const Duration(seconds: 2),
    );
  }

  Future<void> _showPopupVoiceAttachmentSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2C2F3E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'chat.attach_voice'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Theme(
                  data: Theme.of(context).copyWith(
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),
                  child: ChatVoiceRecordButton(
                    onUploaded: (url, sec) async {
                      if (Navigator.of(ctx).canPop()) Navigator.pop(ctx);
                      if (!mounted) return;
                      setState(
                        () => _pendingAttachment = PendingChatAttachment(
                          messageType: 'voice',
                          attachmentUrl: url,
                          durationSec: sec > 0 ? sec : null,
                        ),
                      );
                      Get.find<HomeController>().uploadedFilesPaths.clear();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _syncExpandedPopupRegistration() {
    if (!mounted) return;
    if (widget.chat.minimized) {
      ChatAudioFocus.unregisterExpandedChatPopup(_chatId);
    } else {
      ChatAudioFocus.registerExpandedChatPopup(_chatId);
    }
  }

  void _syncPopupSoundAndFocus() {
    _messageSoundSubscription?.cancel();
    _messageSoundSubscription = null;
    _markReadSubscription?.cancel();
    _markReadSubscription = null;
    final uid = Get.find<HomeController>().currentEmployee.value?.id;
    final stream = _messagesStream;
    if (stream == null || uid == null) {
      ChatAudioFocus.clearForegroundIfEqualsUnlessMainLayoutShows(_chatId);
      if (uid != null) {
        unawaited(FirestoreServices.syncEmployeeActiveChatId(uid, null));
      }
      return;
    }
    if (!widget.chat.minimized) {
      unawaited(
        fcm_notifications.NotificationService().dismissChatMessageNotification(
          _chatId,
        ),
      );
      ChatAudioFocus.setForeground(_chatId);
      unawaited(FirestoreServices.syncEmployeeActiveChatId(uid, _chatId));
      _messageSoundSubscription = attachIncomingMessageSoundSubscription(
        stream: stream,
        chatId: _chatId,
        currentUserId: uid,
      );
      _markReadSubscription = stream.listen((_) {
        unawaited(
          FirestoreServices.markIncomingMessagesReadInChat(_chatId, uid),
        );
      });
      unawaited(FirestoreServices.markIncomingMessagesReadInChat(_chatId, uid));
    } else {
      ChatAudioFocus.clearForegroundIfEqualsUnlessMainLayoutShows(_chatId);
      unawaited(FirestoreServices.syncEmployeeActiveChatId(uid, null));
    }
  }

  @override
  void initState() {
    super.initState();
    _chatId = widget.chat.id;
    final uid = Get.find<HomeController>().currentEmployee.value?.id ?? '';
    _openScrollPrefsFuture = uid.isEmpty
        ? Future<ChatScrollSnapshot?>.value(null)
        : ChatScrollPersistence.load(uid, _chatId);
    _messagesStream = _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();

    _syncPopupSoundAndFocus();
    _syncExpandedPopupRegistration();
    _chatItemPositionsListener.itemPositions.addListener(
      _onPopupScrollPositions,
    );
    _messageFocusNode.addListener(_onPopupInputFocus);
    _messageController.addListener(_onComposerTextChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _flushScrollDiskTimer();
      final uid = Get.find<HomeController>().currentEmployee.value?.id;
      if (uid != null) {
        unawaited(_persistPopupScrollSnapshot(uid));
      }
    }
  }

  void _onPopupScrollPositions() {
    final snap = chatScrollSnapshotFromItemPositions(
      _chatItemPositionsListener.itemPositions.value,
    );
    if (snap != null) {
      final len = _orderedChatMessageDocs.length;
      if (len == 0 || snap.index < len) {
        _lastScrollSnapshotForPersist = snap;
        final uid = Get.find<HomeController>().currentEmployee.value?.id;
        if (uid != null) {
          _scheduleDebouncedDiskPersist(uid);
        }
      }
    }
    final uid = Get.find<HomeController>().currentEmployee.value?.id;
    final docs = _orderedChatMessageDocs;
    final n = docs.length;
    if (uid != null && n > 0) {
      final showFab = !chatReverseListShowsLatest(
        positionsListener: _chatItemPositionsListener,
        itemCount: n,
      );
      final unreadBelow = chatReverseListUnreadIncomingBelowCount(
        positionsListener: _chatItemPositionsListener,
        itemCount: n,
        docs: docs,
        currentUserId: uid,
      );
      if (_scrollFabVisibleLast != showFab ||
          _scrollUnreadBelowLast != unreadBelow) {
        _scrollFabVisibleLast = showFab;
        _scrollUnreadBelowLast = unreadBelow;
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void didUpdateWidget(ChatPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.minimized != widget.chat.minimized) {
      if (oldWidget.chat.minimized && !widget.chat.minimized) {
        unawaited(_reloadDiskScrollAfterExpand());
      } else if (!oldWidget.chat.minimized && widget.chat.minimized) {
        _flushScrollDiskTimer();
        final uid = Get.find<HomeController>().currentEmployee.value?.id;
        if (uid != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_persistPopupScrollSnapshot(uid));
          });
        }
        setState(() {
          _diskScrollOverride = null;
        });
      }
      _syncPopupSoundAndFocus();
    }
    _syncExpandedPopupRegistration();
  }

  @override
  void dispose() {
    ChatAudioFocus.unregisterExpandedChatPopup(_chatId);
    _flushScrollDiskTimer();
    WidgetsBinding.instance.removeObserver(this);
    final uid = Get.find<HomeController>().currentEmployee.value?.id;
    if (uid != null) {
      unawaited(_persistPopupScrollSnapshot(uid));
      unawaited(FirestoreServices.syncEmployeeActiveChatId(uid, null));
    }
    _chatItemPositionsListener.itemPositions.removeListener(
      _onPopupScrollPositions,
    );
    _messageSoundSubscription?.cancel();
    _markReadSubscription?.cancel();
    ChatAudioFocus.clearForegroundIfEqualsUnlessMainLayoutShows(_chatId);
    _messageFocusNode.removeListener(_onPopupInputFocus);
    // Do not call unfocus() here: during Android teardown it can deadlock IME;
    // dispose() releases focus.
    _messageFocusNode.dispose();
    _messageController.removeListener(_onComposerTextChanged);
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (!widget.chat.minimized) {
          ChatAudioFocus.setForeground(_chatId);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 280,
        height: widget.chat.minimized ? 45 : 360,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        transform: Matrix4.translationValues(offset.dx, offset.dy, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Column(
          children: [
            /// HEADER
            GestureDetector(
              onPanUpdate: (d) {
                setState(() {
                  offset += d.delta;
                });
              },
              onTap: () {
                controller.toggleMinimize(
                  widget.chat.id,
                  !widget.chat.minimized,
                );
                controller.clearUnread(widget.chat.id);
              },
              child: Container(
                height: 45,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          chatLeadingAvatar(
                            radius: 14,
                            backgroundColor: widget.chat.isGroup
                                ? Colors.blueGrey.shade100
                                : Colors.grey.shade200,
                            initial: chatInitialFromName(widget.chat.name),
                            groupIcon: widget.chat.isGroup ? Icons.group : null,
                            imageUrl: widget.chat.isGroup
                                ? null
                                : widget.chat.avatar,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.chat.name,
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.chat.unreadCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              widget.chat.unreadCount.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          widget.chat.isGroup
                              ? AppLocaleKeys.chatGroupType.tr
                              : AppLocaleKeys.chatPrivateType.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => controller.closeChat(widget.chat.id),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            /// عند الطي كان يُزال [StreamBuilder] من الشجرة فيُلغى الاشتراك وقد لا تُعاد الرسائل عند الفتح.
            Expanded(
              child: Visibility(
                visible: !widget.chat.minimized,
                maintainState: true,
                maintainSize: false,
                maintainAnimation: true,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: FutureBuilder<ChatScrollSnapshot?>(
                          future: _openScrollPrefsFuture,
                          builder: (context, fSnap) {
                            final prefsDone =
                                fSnap.connectionState == ConnectionState.done;
                            final persisted = fSnap.data;
                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: _messagesStream,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return Center(
                                    child: Text('chat.start_first'.tr),
                                  );
                                }

                                final messages = snapshot.data!.docs;
                                _orderedChatMessageDocs = messages;

                                final uid =
                                    controller.currentEmployee.value?.id ?? '';
                                final showScrollFab =
                                    !chatReverseListShowsLatest(
                                      positionsListener:
                                          _chatItemPositionsListener,
                                      itemCount: messages.length,
                                    );
                                final unreadBelow = uid.isNotEmpty
                                    ? chatReverseListUnreadIncomingBelowCount(
                                        positionsListener:
                                            _chatItemPositionsListener,
                                        itemCount: messages.length,
                                        docs: messages,
                                        currentUserId: uid,
                                      )
                                    : 0;
                                final fromPrefs = prefsDone ? persisted : null;
                                final persistedForResolve =
                                    _lastScrollSnapshotForPersist ??
                                    fromPrefs ??
                                    _diskScrollOverride;
                                final openScroll = uid.isNotEmpty
                                    ? resolveChatOpenScroll(
                                        itemCount: messages.length,
                                        currentUserId: uid,
                                        docs: messages,
                                        persisted: persistedForResolve,
                                        usePersisted:
                                            persistedForResolve != null,
                                      )
                                    : (index: 0, alignment: 1.0);

                                return Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Positioned.fill(
                                      child: ScrollablePositionedList.builder(
                                        key: ValueKey(
                                          '${_chatId}_$_chatMessageListEpoch',
                                        ),
                                        itemScrollController:
                                            _chatMessageItemScrollController,
                                        itemPositionsListener:
                                            _chatItemPositionsListener,
                                        initialScrollIndex: openScroll.index,
                                        initialAlignment: openScroll.alignment,
                                        reverse: true,
                                        itemCount: messages.length,
                                        itemBuilder: (context, index) {
                                          final msg = messages[index].data();
                                          final mid = messages[index].id;
                                          final isMe =
                                              msg['senderId'] ==
                                              controller
                                                  .currentEmployee
                                                  .value
                                                  ?.id;
                                          final senderName =
                                              msg['senderName'] ??
                                              'chat.unknown_sender'.tr;
                                          final timestamp =
                                              msg['timestamp'] as Timestamp?;
                                          final isRead = msg['isRead'] ?? false;

                                          final rowUid = controller
                                              .currentEmployee
                                              .value
                                              ?.id;
                                          if (rowUid == null) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            key: ValueKey(mid),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                              horizontal: 8,
                                            ),
                                            child: ChatMessageTile(
                                              chatId: _chatId,
                                              messageId: mid,
                                              message:
                                                  Map<String, dynamic>.from(
                                                    msg,
                                                  ),
                                              isMe: isMe,
                                              isGroup: widget.chat.isGroup,
                                              senderName: senderName,
                                              showGroupSenderName:
                                                  widget.chat.isGroup && !isMe,
                                              timestamp: timestamp,
                                              formatTime: _formatTimestamp,
                                              isAdmin:
                                                  controller
                                                      .currentEmployee
                                                      .value
                                                      ?.role ==
                                                  'admin',
                                              currentUserId: rowUid,
                                              currentUserDisplayName: controller
                                                  .currentEmployee
                                                  .value
                                                  ?.name,
                                              onReply: (draft) => setState(
                                                () => _replyDraft = draft,
                                              ),
                                              onReplyPreviewTap:
                                                  _scrollToRepliedMessage,
                                              bubbleDecoration: BoxDecoration(
                                                color: isMe
                                                    ? const Color(0xFF465FFF)
                                                    : Colors.white,
                                                borderRadius: BorderRadius.only(
                                                  topLeft:
                                                      const Radius.circular(15),
                                                  topRight:
                                                      const Radius.circular(15),
                                                  bottomLeft: Radius.circular(
                                                    isMe ? 15 : 4,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    isMe ? 4 : 15,
                                                  ),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.05,
                                                        ),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              maxWidthFactor: 0.7,
                                              alignment: isMe
                                                  ? Alignment.centerRight
                                                  : Alignment.centerLeft,
                                              columnCrossAxis: isMe
                                                  ? CrossAxisAlignment.end
                                                  : CrossAxisAlignment.start,
                                              showReadReceipts: true,
                                              messageIsRead: isRead,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      right: 6,
                                      bottom: 10,
                                      child: ChatScrollToLatestFab(
                                        visible: showScrollFab,
                                        badgeCount: unreadBelow,
                                        onPressed: () =>
                                            scheduleScrollChatToLatest(
                                              controller:
                                                  _chatMessageItemScrollController,
                                              mounted: () => mounted,
                                            ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    const ChatUploadProgressBanner(),
                    if (_replyDraft != null)
                      ChatReplyDraftBanner(
                        draft: _replyDraft!,
                        fontSize: 12,
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                        onCancel: () => setState(() => _replyDraft = null),
                      ),
                    if (_pendingAttachment != null)
                      PendingAttachmentStrip(
                        pending: _pendingAttachment!,
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                        titleFontSize: 12,
                        onCancel: () =>
                            setState(() => _pendingAttachment = null),
                        onTapPreview:
                            (_pendingAttachment!.messageType == 'image' ||
                                _pendingAttachment!.messageType == 'video')
                            ? () => openChatMediaFromUrl(
                                _pendingAttachment!.attachmentUrl,
                              )
                            : null,
                      ),

                    /// INPUT
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: EdgeInsets.fromLTRB(
                        8,
                        4,
                        8,
                        _messageFocusNode.hasFocus ? 10 : 8,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: _messageFocusNode.hasFocus ? 2 : 6,
                        vertical: _messageFocusNode.hasFocus ? 4 : 2,
                      ),
                      constraints: BoxConstraints(
                        minHeight: _messageFocusNode.hasFocus ? 50 : 46,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          _messageFocusNode.hasFocus ? 24 : 22,
                        ),
                        border: Border.all(
                          color: _messageFocusNode.hasFocus
                              ? const Color(0xFF465FFF).withValues(alpha: 0.35)
                              : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: _messageFocusNode.hasFocus ? 10 : 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Obx(() {
                        final busy =
                            Get.find<HomeController>().isUploading.value;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Builder(
                              builder: (buttonContext) {
                                return IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 44,
                                  ),
                                  tooltip: 'chat.attach_sheet_title'.tr,
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.grey.shade700,
                                    size: 24,
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () => _showPopupAttachmentMenu(
                                          buttonContext,
                                        ),
                                );
                              },
                            ),
                            Expanded(
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  textSelectionTheme:
                                      const TextSelectionThemeData(
                                        cursorColor: Color(0xFF465FFF),
                                        selectionHandleColor: Color(0xFF465FFF),
                                        selectionColor: Color(0x33465FFF),
                                      ),
                                ),
                                child: Focus(
                                  onKeyEvent: _onComposerKeyEvent,
                                  child: TextField(
                                    cursorColor: const Color(0xFF465FFF),
                                    controller: _messageController,
                                    focusNode: _messageFocusNode,
                                    minLines: 1,
                                    maxLines: 5,
                                    keyboardType: TextInputType.multiline,
                                    readOnly: busy,
                                    textAlignVertical: TextAlignVertical.center,
                                    textDirection:
                                        textDirectionForTypedChatMessage(
                                          _messageController.text,
                                          Directionality.of(context),
                                        ),
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      fontSize: _messageFocusNode.hasFocus
                                          ? 15.5
                                          : 14.5,
                                      height: 1.35,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'chat.write_message'.tr,
                                      hintStyle: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 10,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 44,
                              ),
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Color(0xFF465FFF),
                                size: 24,
                              ),
                              onPressed: busy ? null : _sendMessage,
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final pending = _pendingAttachment;
    if (text.isEmpty && pending == null) return;
    _messageController.clear();
    if (!kIsWeb) {
      _messageFocusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _messageFocusNode.canRequestFocus) {
          _messageFocusNode.requestFocus();
        }
      });
    }
    if (pending != null) {
      setState(() => _pendingAttachment = null);
      final lastPrev = lastMessagePreviewForPending(pending, text);
      switch (pending.messageType) {
        case 'image':
          await _sendChatPayload(
            lastMessagePreview: lastPrev,
            messageType: 'image',
            text: text,
            attachmentUrl: pending.attachmentUrl,
          );
          break;
        case 'video':
          await _sendChatPayload(
            lastMessagePreview: lastPrev,
            messageType: 'video',
            text: text,
            attachmentUrl: pending.attachmentUrl,
            fileName: pending.fileName,
          );
          break;
        case 'file':
          await _sendChatPayload(
            lastMessagePreview: lastPrev,
            messageType: 'file',
            text: text,
            attachmentUrl: pending.attachmentUrl,
            fileName: pending.fileName,
          );
          break;
        case 'voice':
          await _sendChatPayload(
            lastMessagePreview: lastPrev,
            messageType: 'voice',
            text: text,
            attachmentUrl: pending.attachmentUrl,
            durationSec: pending.durationSec,
          );
          break;
      }
      return;
    }
    unawaited(
      _sendChatPayload(
        lastMessagePreview: text,
        messageType: 'text',
        text: text,
      ),
    );
  }

  Future<void> _sendChatPayload({
    required String lastMessagePreview,
    String messageType = 'text',
    String text = '',
    String? attachmentUrl,
    String? fileName,
    int? durationSec,
  }) async {
    if (messageType == 'text' && text.trim().isEmpty) return;
    if (messageType != 'text' &&
        (attachmentUrl == null || attachmentUrl.trim().isEmpty)) {
      return;
    }

    final hc = Get.find<HomeController>();
    final me = hc.currentEmployee.value;
    if (me?.id == null) return;

    if (ChatAudioFocus.incomingTreatAsInChat(_chatId)) {
      unawaited(AudioService.instance.playActiveChatOutgoingSound());
    }

    final chatRef = _firestore.collection('chats').doc(_chatId);
    final msgRef = chatRef.collection('messages').doc();

    final payload = <String, dynamic>{
      'senderId': me!.id,
      'senderName': me.name ?? me.email ?? '',
      'text': messageType == 'text'
          ? (text.isNotEmpty ? text : lastMessagePreview)
          : text.trim(),
      'messageType': messageType,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };
    if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
      payload['attachmentUrl'] = attachmentUrl;
    }
    if (fileName != null && fileName.isNotEmpty) {
      payload['fileName'] = fileName;
    }
    if (durationSec != null) {
      payload['durationSec'] = durationSec;
    }
    final reply = _replyDraft;
    if (reply != null) {
      payload['replyToMessageId'] = reply.messageId;
      payload['replyPreview'] = reply.preview;
      final rsn = reply.replySenderName;
      if (rsn != null && rsn.trim().isNotEmpty) {
        payload['replySenderName'] = rsn.trim();
      }
      final riu = reply.replyImageUrl?.trim();
      if (riu != null && riu.isNotEmpty) {
        payload['replyImageUrl'] = riu;
      }
      final rvu = reply.replyVideoUrl?.trim();
      if (rvu != null && rvu.isNotEmpty) {
        payload['replyVideoUrl'] = rvu;
      }
    }

    await msgRef.set(payload);
    if (mounted) {
      setState(() => _replyDraft = null);
    }

    await FirestoreChatApi.updateChatAfterMessageSend(
      fs: _firestore,
      chatId: _chatId,
      actorParticipantId: me.id!,
      lastMessagePreview: lastMessagePreview,
    );

    final chatSnap = await chatRef.get();
    final data = chatSnap.data() ?? {};
    final isGroup = data['isGroup'] == true;
    final participants = List<String>.from(data['participants'] ?? []);
    final title = data['title']?.toString() ?? widget.chat.name;
    final chatForTitle = Map<String, dynamic>.from(data)..['id'] = _chatId;
    final fcmChatLabel = chatConversationTitleForPushDisplay(chatForTitle);

    if (!isGroup) {
      final others = participants.where((id) => id != me.id).toList();
      if (others.isNotEmpty) {
        await FirestoreServices.sendFcm(
          userId: others.first,
          title: me.name ?? me.email ?? '',
          body: lastMessagePreview,
          notificationType: 'chat_message',
          fcmDataExtras: {
            'chatId': _chatId,
            'chatTitle': me.name ?? me.email ?? '',
            'chatDisplayName': fcmChatLabel,
            'senderName': me.name ?? me.email ?? '',
            'isGroup': '0',
          },
        );
      }
    } else {
      for (final id in participants) {
        if (id != me.id) {
          await FirestoreServices.sendFcm(
            userId: id,
            title: 'chat.fcm_in_group_title'.trParams({
              'user': me.name ?? '',
              'group': title,
            }),
            body: lastMessagePreview,
            notificationType: 'chat_message',
            fcmDataExtras: {
              'chatId': _chatId,
              'chatTitle': title,
              'chatDisplayName': fcmChatLabel,
              'senderName': me.name ?? me.email ?? '',
              'isGroup': '1',
            },
          );
        }
      }
    }
  }
}

String _formatTimestamp(Timestamp? ts) {
  if (ts == null) return '';
  final dt = ts.toDate();
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) {
    return 'chat.seconds_ago'.tr;
  } else if (diff.inMinutes < 60) {
    return 'common.minutes_ago'.trParams({'count': '${diff.inMinutes}'});
  } else if (diff.inHours < 24) {
    return 'common.hours_ago'.trParams({'count': '${diff.inHours}'});
  } else if (diff.inDays < 7) {
    return 'chat.days_ago'.trParams({'count': '${diff.inDays}'});
  } else {
    return DateFormat('dd/MM/yyyy').format(dt);
  }
}
