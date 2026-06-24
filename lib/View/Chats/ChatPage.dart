import 'dart:async';
import 'package:point/Utils/app_log.dart';
import 'package:point/Utils/text_input_bidi.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/AudioService.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/ChatIncomingMessageSound.dart';
import 'package:point/Services/FcmServices.dart' as fcm_notifications;
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/firestore/firestore_chat_api.dart';
import 'package:point/Services/firestore/firestore_query_limits.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/chat_clipboard_image_reader.dart';
import 'package:point/Services/chat_list_pins_persistence.dart';
import 'package:point/Services/chat_mark_read_scheduler.dart';
import 'package:point/Services/chat_scroll_persistence.dart';
import 'package:point/Services/chat_image_paste_listener.dart';
import 'package:point/View/Chats/chat_list_row_trailing.dart';
import 'package:point/View/Chats/chat_list_folder_utils.dart';
import 'package:point/View/Chats/chat_message_tile.dart';
import 'package:point/View/Chats/chat_media_gallery.dart';
import 'package:point/View/Chats/chat_pinned_messages_bar.dart';
import 'package:point/View/Chats/chat_message_list_panel.dart';
import 'package:point/View/Chats/pending_chat_attachment.dart';
import 'package:point/View/Chats/chat_list_tile_media_subtitle.dart';
import 'package:point/View/Chats/chat_private_typing.dart';
import 'package:point/View/Chats/chat_reply_draft_banner.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';
import 'package:point/Utils/chat_attachment_upload.dart';
import 'package:point/View/Chats/chat_voice_record_button.dart';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatScreen extends StatefulWidget {
  final VoidCallback onMinimize;
  final bool isFloatingPopUp; // <--- المتغير الجديد

  const ChatScreen({
    super.key,
    required this.onMinimize,
    this.isFloatingPopUp = false, // القيمة الافتراضية شاشة كاملة/عادية
  });
  // ...

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  // -------- controllers / state -------
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  ChatImagePasteListener? _imagePasteListener;
  bool _isEmojiVisible = false;
  PendingChatAttachment? _pendingAttachment;
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final PrivateChatTypingWriter _typingWriter;
  // final FirebaseAuth _auth = FirebaseAuth.instance;

  // local caches
  String? _currentUserId;
  String? _otherUserId;
  String? _currentUserName;
  // **إضافة لتخزين بيانات الموظف الحالي**
  List<String> _currentUserDepts = [];
  String? _currentUserRole;

  List<Map<String, dynamic>> _employees = []; // all employees
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<Map<String, dynamic>> _groupParticipants =
      []; // **لتخزين المشاركين في مجموعة القسم**

  List<Map<String, dynamic>> _chats = []; // chats list for current user
  String _chatListSearchQuery = '';
  ChatListFolder _chatListFolder = ChatListFolder.all;
  List<String> _pinnedChatIds = [];
  Map<String, dynamic>? _selectedChat; // selected chat doc (id + data)
  ChatReplyDraft? _replyDraft;

  final ChatMessageListPanelController _chatListPanelController =
      ChatMessageListPanelController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _orderedChatMessageDocs =
      [];

  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;

  /// يمنع إعادة إنشاء اشتراك الرسائل لنفس المحادثة عند كل snapshot.
  String? _messagesStreamChatId;

  ChatScrollSnapshot? _persistedOpenScroll;
  String? _persistedOpenScrollForChatId;
  int _chatMessageListEpoch = 0;

  /// Last known scroll per chat ([ItemPositionsListener] is often empty on switch).
  final Map<String, ChatScrollSnapshot> _scrollSnapshotCache = {};

  static const _kScrollDiskDebounceMs = 350;
  Timer? _scrollDiskFlushTimer;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messageSoundSubscription;

  /// يمنع تطبيق دمج معاينات قديم بعد snapshot أحدث.
  int _chatsEnrichGen = 0;
  final Set<String> _legacyPreviewFetched = {};

  /// يمنع إلغاء اشتراك الصوت عند كل تحديث لقائمة المحادثات (كان يُرمى أول snapshot فيه الرسائل الجديدة).
  String? _messageSoundBoundChatId;

  bool _loadingEmployees = true;
  bool _loadingChats = true;
  bool _isLoadingGroup = false; // **إضافة حالة تحميل للمجموعة**

  DateTime? _presenceOf(String? employeeId) {
    final id = employeeId?.trim() ?? '';
    if (id.isEmpty || !Get.isRegistered<HomeController>()) return null;
    return Get.find<HomeController>().employeeLastSeenAt(id);
  }

  bool _isOnlinePresence(DateTime? at) {
    if (at == null) return false;
    return DateTime.now().difference(at.toLocal()) <= kEmployeePresenceOnlineWindow;
  }

  void _syncPresenceWatchFromChats(List<Map<String, dynamic>> chats) {
    final uid = _currentUserId?.trim() ?? '';
    if (uid.isEmpty || uid == 'temp_current_user') return;
    if (!Get.isRegistered<HomeController>()) return;
    Get.find<HomeController>().setPresenceWatchIds(
      presenceWatchIdsFromChats(chats, uid),
    );
  }

  String _privatePresenceLabel(String? otherEmployeeId) {
    final at = _presenceOf(otherEmployeeId);
    if (_isOnlinePresence(at)) {
      final raw = 'employees.online_now'.tr;
      final lang = Get.locale?.languageCode.toLowerCase() ?? '';
      return lang == 'en' ? raw.toLowerCase() : raw;
    }
    if (at == null) return 'employees.last_seen_unknown'.tr;
    final when = FunHelper.formatTimeAgo(at.toLocal());
    return 'employees.last_seen_at'.trParams({'time': when});
  }

  int _connectedUsersCountForGroup(Map<String, dynamic> chat) {
    final participants = List<String>.from(chat['participants'] ?? const []);
    var count = 0;
    for (final id in participants) {
      if (id == (_currentUserId ?? '')) continue;
      if (_isOnlinePresence(_presenceOf(id))) count++;
    }
    return count;
  }

  Widget _avatarWithOnlineDot({
    required Widget avatar,
    required bool showOnlineDot,
  }) {
    if (!showOnlineDot) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  bool get _enableContentInsertion =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _typingWriter = PrivateChatTypingWriter(_firestore);
    _messageController.addListener(_onComposerTextChanged);
    _imagePasteListener = ChatImagePasteListener(
      onImagePasted: _handlePastedImage,
      onPasteError: _showPasteImageFailed,
      shouldHandle: () =>
          mounted &&
          _selectedChat != null &&
          !_messageFocusNode.hasFocus &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed),
    );
    WidgetsBinding.instance.addObserver(this);
    _initUserThenLoad();
  }

  void _flushScrollDiskTimer() {
    _scrollDiskFlushTimer?.cancel();
    _scrollDiskFlushTimer = null;
  }

  void _scheduleDebouncedDiskPersist() {
    _scrollDiskFlushTimer?.cancel();
    _scrollDiskFlushTimer = Timer(
      const Duration(milliseconds: _kScrollDiskDebounceMs),
      () {
        _scrollDiskFlushTimer = null;
        unawaited(_persistCurrentChatScrollIfAny());
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _flushScrollDiskTimer();
      unawaited(_persistCurrentChatScrollIfAny());
      unawaited(_typingWriter.clearTyping());
    }
  }

  void _onChatListScrollSnapshot(ChatScrollSnapshot snap) {
    final cid = _messagesStreamChatId;
    if (cid != null) {
      final len = _orderedChatMessageDocs.length;
      if (len == 0 || snap.index < len) {
        _scrollSnapshotCache[cid] = snap;
        _scheduleDebouncedDiskPersist();
      }
    }
  }

  void _onChatListDocsChanged(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    _orderedChatMessageDocs = docs;
    final chatId = _selectedChat?['id'] as String?;
    if (chatId != null && chatId.isNotEmpty) {
      ChatMediaGalleryStore.update(chatId, docs);
    }
  }

  Map<String, String> _participantNamesMap() {
    final names = <String, String>{};
    for (final emp in _groupParticipants) {
      final id = emp['id'] as String?;
      final name = emp['name'] as String?;
      if (id != null && name != null && name.trim().isNotEmpty) {
        names[id] = name.trim();
      }
    }
    return names;
  }

  void _onComposerTextChanged() {
    _typingWriter.onComposerTextChanged(_messageController.text);
  }

  void _rebindTypingWriter() {
    final uid = _currentUserId ?? '';
    if (uid.isEmpty) {
      _typingWriter.rebind(chatId: null, myUserId: '', isGroup: true);
      return;
    }
    final sel = _selectedChat;
    if (sel == null) {
      _typingWriter.rebind(chatId: null, myUserId: uid, isGroup: true);
      return;
    }
    final cid = sel['id'];
    if (cid is! String || cid.isEmpty) {
      _typingWriter.rebind(chatId: null, myUserId: uid, isGroup: true);
      return;
    }
    final isGroup = sel['isGroup'] ?? false;
    _typingWriter.rebind(
      chatId: cid,
      myUserId: uid,
      isGroup: isGroup == true,
    );
  }

  void _scrollToRepliedMessage(String messageId) {
    _chatListPanelController.scrollToMessageId(messageId);
  }

  /// Persists scroll for [chatId] using live positions only when that chat is the active stream.
  Future<void> _persistScrollSnapshotForChatId(
    String uid,
    String chatId,
  ) async {
    final live = _messagesStreamChatId == chatId
        ? _chatListPanelController.currentScrollSnapshot
        : null;
    final snap = live ?? _scrollSnapshotCache[chatId];
    if (snap == null) return;
    await ChatScrollPersistence.saveSnapshot(
      userId: uid,
      chatId: chatId,
      snapshot: snap,
    );
  }

  Future<void> _persistCurrentChatScrollIfAny() async {
    final uid = _currentUserId;
    final cid = _messagesStreamChatId;
    if (uid == null || cid == null) return;
    await _persistScrollSnapshotForChatId(uid, cid);
  }

  /// Next chats open: no conversation pre-selected ([HomeController.selectedChat]).
  void _clearStoredChatSelectionOnHome() {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().selectedChat = null;
    }
  }

  Future<void> _reloadPersistedScrollBumpListEpoch() async {
    final id = _selectedChat?['id'] as String?;
    final uid = _currentUserId;
    if (uid == null || id == null) {
      if (mounted) {
        setState(() {
          _persistedOpenScroll = null;
          _persistedOpenScrollForChatId = null;
        });
      }
      return;
    }
    final s = await ChatScrollPersistence.load(uid, id);
    if (!mounted) return;
    setState(() {
      _scrollSnapshotCache.remove(id);
      _persistedOpenScroll = s;
      _persistedOpenScrollForChatId = id;
      if (s != null) _chatMessageListEpoch++;
    });
  }

  KeyEventResult _onComposerKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final isArrowLeft = key == LogicalKeyboardKey.arrowLeft;
    final isArrowRight = key == LogicalKeyboardKey.arrowRight;
    if (isArrowLeft || isArrowRight) {
      final value = _messageController.value;
      final hasComposingRegion =
          value.composing.isValid && !value.composing.isCollapsed;
      final shouldRemapForRtl = shouldUseRtlVisualCaretNavigation(
        value.text,
        Directionality.of(context),
      );
      if (!hasComposingRegion && shouldRemapForRtl) {
        final remapped = remapHorizontalArrowForRtlVisual(
          text: value.text,
          selection: value.selection,
          isArrowLeft: isArrowLeft,
          shiftPressed: composerShiftPressed(),
          ctrlPressed: composerControlPressed(),
        );
        if (remapped != null && remapped != value.selection) {
          _messageController.selection = remapped;
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    final isEnter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    if (!chatComposerEnterKeySendsMessage()) {
      return KeyEventResult.ignored;
    }
    if (composerShiftPressed()) return KeyEventResult.ignored;
    final chatId = _selectedChat?['id'] as String?;
    final hc = Get.find<HomeController>();
    final busy = chatId != null && hc.isChatUploadActiveFor(chatId);
    if (!busy) {
      unawaited(_sendMessage());
    }
    return KeyEventResult.handled;
  }

  Future<void> _initUserThenLoad() async {
    final homeController = Get.find<HomeController>();
    // try to get current user from FirebaseAuth
    // final user = _auth.currentUser;
    if (homeController.currentEmployee.value != null) {
      _currentUserId = homeController.currentEmployee.value?.id;
      _currentUserName =
          homeController.currentEmployee.value?.name ??
          homeController.currentEmployee.value?.email ??
          'Me'.tr;
      // **جلب بيانات القسم والدور للمستخدم الحالي**
      _currentUserDepts = StorageKeys.normalizeDepartments(
        homeController.currentEmployee.value?.departments ?? const [],
      );
      _currentUserRole = homeController.currentEmployee.value?.role;
    } else {
      // if no users at all, create a temporary id (but better to have employees collection)
      _currentUserId = 'temp_current_user';
      _currentUserName = 'Me'.tr;
      _currentUserDepts = [];
      _currentUserRole = null;
    }

    await _loadEmployees();
    await _createOrLoadDepartmentGroup(); // **تحميل مجموعة القسم**
    await _reloadPinnedChats();
    _listenChats();
  }

  Future<void> _reloadPinnedChats() async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty || uid == 'temp_current_user') {
      _pinnedChatIds = [];
      return;
    }
    _pinnedChatIds = await ChatListPinsPersistence.loadPinnedChatIds(uid);
  }

  List<Map<String, dynamic>> _visibleChatsOrderedForSidebar() {
    final searched = _visibleChatsForSearch();
    final foldered = filterChatsByFolder(searched, _chatListFolder);
    return sortChatsPinnedFirst(foldered, _pinnedChatIds);
  }

  Future<void> _togglePinChat(String chatId) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty || uid == 'temp_current_user') return;
    final pinned = _pinnedChatIds.contains(chatId);
    if (pinned) {
      _pinnedChatIds = await ChatListPinsPersistence.unpinChat(
        uid,
        _pinnedChatIds,
        chatId,
      );
    } else {
      _pinnedChatIds = await ChatListPinsPersistence.pinChat(
        uid,
        _pinnedChatIds,
        chatId,
      );
    }
    if (mounted) setState(() {});
  }

  void _showChatListPinMenu(
    BuildContext menuContext,
    Offset globalPosition,
    String chatId,
  ) {
    if (!mounted) return;
    final pinned = _pinnedChatIds.contains(chatId);
    unawaited(
      showChatListPinContextMenu(
        context: menuContext,
        globalPosition: globalPosition,
        chatId: chatId,
        isPinned: pinned,
        onTogglePin: _togglePinChat,
      ),
    );
  }

  // ---------------- Employees ----------------
  Future<void> _loadEmployees() async {
    _loadingEmployees = true;
    setState(() {});
    final snapshot = await _firestore.collection('employees').get();
    _employees = snapshot.docs
        .where(
          (d) => d.id != _currentUserId,
        ) // exclude current user from 1:1 chat list
        .map((d) {
          final data = d.data();
          return {
            'id': d.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'image': data['image'] ?? '',
            'departments': StorageKeys.normalizeDepartments(
              (data['departments'] is List)
                  ? (data['departments'] as List).map((e) => e?.toString())
                  : [data['department']?.toString()],
            ),
            'role': data['role'] ?? '', // **إضافة حقل الدور**
          };
        })
        .toList();

    // For employee role: show only allowed chat targets.
    // Managers can still chat with anyone.
    if (_currentUserRole == 'employee') {
      final myDepts = _currentUserDepts;
      _employees = _employees.where((e) {
        final targetRole = e['role'];
        final targetDepts = List<String>.from(e['departments'] as List? ?? []);
        final isSpecialRole = StorageKeys.isChatElevatedRole(targetRole);
        final overlap = StorageKeys.departmentListsOverlap(
          myDepts,
          targetDepts,
        );
        return isSpecialRole || overlap;
      }).toList();
    }

    _filteredEmployees = List.from(_employees);
    _loadingEmployees = false;
    setState(() {});
  }

  void _filterEmployees(String q) {
    final qlower = q.trim().toLowerCase();
    if (qlower.isEmpty) {
      _filteredEmployees = List.from(_employees);
      setState(() {});
    } else {
      _filteredEmployees = _employees
          .where((e) => (e['name'] as String).toLowerCase().contains(qlower))
          .toList();
    }
    setState(() {});
  }

  // **---------------- Department Group Logic ----------------**

  List<String> _sidebarDepartmentSlugsForChat() {
    if (_currentUserRole == null) return [];
    if (StorageKeys.isChatElevatedRole(_currentUserRole)) {
      return List<String>.from(StorageKeys.departmentSlugs);
    }
    return List<String>.from(_currentUserDepts);
  }

  List<Map<String, dynamic>> _joinableDepartmentGroups() {
    final slugs = _sidebarDepartmentSlugsForChat();
    final groups = <Map<String, dynamic>>[];
    for (final slug in slugs) {
      final normalized = StorageKeys.normalizeDepartment(slug);
      if (normalized.isEmpty) continue;
      final chatId = 'group_$normalized';
      final existing = _chats.where((c) => c['id'] == chatId);
      final isJoined = existing.any((c) {
        final p = List<String>.from(c['participants'] ?? const []);
        return _currentUserId != null && p.contains(_currentUserId);
      });
      groups.add({
        'id': chatId,
        'slug': normalized,
        'title': normalized,
        'isJoined': isJoined,
      });
    }
    return groups;
  }

  Future<void> _createOrLoadDepartmentGroup() async {
    if (_currentUserId == null || _currentUserId == 'temp_current_user') {
      return;
    }
    final slugs = _sidebarDepartmentSlugsForChat();
    if (slugs.isEmpty) return;

    _isLoadingGroup = true;
    setState(() {});

    for (final deptGroupName in slugs) {
      await _syncSingleDepartmentGroup(deptGroupName);
    }

    _isLoadingGroup = false;
    setState(() {});
  }

  Future<void> _syncSingleDepartmentGroup(String deptGroupName) async {
    if (deptGroupName.isEmpty) return;
    final groupId = 'group_$deptGroupName';
    final groupRef = _firestore.collection('chats').doc(groupId);

    final List<String> participantsIds = [];
    _groupParticipants.clear();

    participantsIds.add(_currentUserId!);

    _employees.forEach((emp) {
      final empId = emp['id'] as String;
      final empDepts = List<String>.from(emp['departments'] as List? ?? []);
      final isSameDept = empDepts.any(
        (ed) => StorageKeys.matchesDepartment(ed, deptGroupName),
      );
      final isSpecialRole = StorageKeys.isChatElevatedRole(emp['role']);

      if ((isSameDept || isSpecialRole) &&
          empId != _currentUserId &&
          !participantsIds.contains(empId)) {
        participantsIds.add(empId);
        _groupParticipants.add(emp);
      }
    });

    final groupSnapshot = await groupRef.get();

    if (!groupSnapshot.exists) {
      await groupRef.set({
        'isGroup': true,
        'title': deptGroupName,
        'participants': participantsIds,
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      final existingParticipants = List<String>.from(
        groupSnapshot.data()?['participants'] ?? [],
      );
      if (!existingParticipants.contains(_currentUserId)) {
        await groupRef.update({
          'participants': [...existingParticipants, _currentUserId!],
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  void _syncMessageSoundListener() {
    final stream = _messagesStream;
    final uid = _currentUserId;
    final sel = _selectedChat;
    if (stream == null || uid == null || sel == null) {
      _messageSoundSubscription?.cancel();
      _messageSoundSubscription = null;
      final prevBound = _messageSoundBoundChatId;
      _messageSoundBoundChatId = null;
      if (prevBound != null) {
        ChatAudioFocus.unregisterMainLayoutChatOpen(prevBound);
      }
      ChatAudioFocus.clearForeground();
      if (uid != null) {
        unawaited(FirestoreServices.syncEmployeeActiveChatId(uid, null));
      }
      return;
    }
    final chatId = sel['id'] as String;
    unawaited(
      fcm_notifications.NotificationService().dismissChatMessageNotification(
        chatId,
      ),
    );
    ChatAudioFocus.setForeground(chatId);
    if (_messageSoundSubscription != null &&
        _messageSoundBoundChatId == chatId) {
      return;
    }
    if (_messageSoundBoundChatId != null &&
        _messageSoundBoundChatId != chatId) {
      ChatAudioFocus.unregisterMainLayoutChatOpen(_messageSoundBoundChatId!);
    }
    _messageSoundSubscription?.cancel();
    _messageSoundSubscription = null;
    _messageSoundBoundChatId = chatId;
    ChatAudioFocus.registerMainLayoutChatOpen(chatId);
    _messageSoundSubscription = attachIncomingMessageSoundSubscription(
      stream: stream,
      chatId: chatId,
      currentUserId: uid,
    );
    unawaited(FirestoreServices.syncEmployeeActiveChatId(uid, chatId));
  }

  /// يضبط [stream] الرسائل ليتوافق مع [_selectedChat] (مثلاً عند استعادة آخر محادثة من [HomeController]).
  void _syncMessagesStreamWithSelection() {
    if (_selectedChat == null) {
      _messagesStream = null;
      if (_messagesStreamChatId != null) {
        _flushScrollDiskTimer();
        _messagesStreamChatId = null;
        _orderedChatMessageDocs = [];
      }
      _rebindTypingWriter();
      return;
    }
    final id = _selectedChat!['id'] as String;
    if (_messagesStreamChatId == id && _messagesStream != null) {
      _rebindTypingWriter();
      return;
    }
    if (_messagesStreamChatId != null && _messagesStreamChatId != id) {
      ChatMarkReadScheduler.cancelForChat(_messagesStreamChatId!);
      _flushScrollDiskTimer();
      _orderedChatMessageDocs = [];
    }
    _messagesStreamChatId = id;
    _messagesStream = _firestore
        .collection('chats')
        .doc(id)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(FirestoreQueryLimits.chatMessagesPage)
        .snapshots();
    _rebindTypingWriter();
  }

  // **---------------- Chats (Private & Group) ----------------**
  void _listenChats() {
    if (_currentUserId == null) return;

    _chatsSubscription?.cancel();

    _selectedChat = Get.find<HomeController>().selectedChat;
    _syncMessagesStreamWithSelection();
    unawaited(_reloadPersistedScrollBumpListEpoch());
    _chatsSubscription = _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .listen(
          (snap) {
            // تجنّب setState بعد الـ dispose (مهم عند إرسال رسالة ثم إغلاق الشاشة بسرعة)
            if (!mounted || _chatsSubscription == null) return;
            final built = <Map<String, dynamic>>[];
            for (var doc in snap.docs) {
              final data = doc.data();
              final chat = {
                'id': doc.id,
                'participants': List<String>.from(data['participants'] ?? []),
                'lastMessage': data['lastMessage'] ?? '',
                'lastUpdated': data['lastUpdated'],
                'isGroup': data['isGroup'] ?? false, // **قراءة علامة المجموعة**
                'title': data['title'], // **قراءة اسم المجموعة**
                'lastMessageMeta': data['lastMessageMeta'],
                if (_currentUserId != null &&
                    _currentUserId != 'temp_current_user')
                  'unreadIncoming': FirestoreChatApi.unreadCountFromChatData(
                    data,
                    _currentUserId!,
                  ),
              };
              built.add(chat);
            }

            _chatsEnrichGen++;
            final gen = _chatsEnrichGen;
            if (!mounted || _chatsSubscription == null) return;
            unawaited(_applySnapshotAndEnrich(gen, built));
          },
          onError: (Object e, StackTrace st) {
            if (e is FirebaseException &&
                e.code == 'permission-denied' &&
                FirebaseAuth.instance.currentUser == null) {
              final sub = _chatsSubscription;
              _chatsSubscription = null;
              sub?.cancel();
              return;
            }
            appLog('⚠️ ChatScreen _listenChats: $e');
            if (!mounted || _chatsSubscription == null) return;
            setState(() {
              _loadingChats = false;
            });
          },
          cancelOnError: false,
        );
  }

  /// دمج قائمة المحادثات مع آخر رسالة من `messages` وإخفاء الفردية بلا أي رسالة.
  Future<void> _applySnapshotAndEnrich(
    int gen,
    List<Map<String, dynamic>> built,
  ) async {
    if (built.isEmpty) {
      if (!mounted || gen != _chatsEnrichGen) return;
      _chats = [];
      _loadingChats = false;
      if (_selectedChat != null) {
        await _persistCurrentChatScrollIfAny();
        _selectedChat = null;
        _persistedOpenScroll = null;
        _persistedOpenScrollForChatId = null;
      }
      if (!mounted || _chatsSubscription == null) return;
      _syncMessagesStreamWithSelection();
      setState(() {});
      _syncMessageSoundListener();
      return;
    }

    final needsLegacy = <String>[];
    for (final c in built) {
      final id = c['id'] as String;
      final isGroup = c['isGroup'] == true;
      final preview = (c['lastMessage'] ?? '').toString().trim();
      if (!isGroup &&
          preview.isEmpty &&
          !_legacyPreviewFetched.contains(id)) {
        needsLegacy.add(id);
      }
    }
    if (needsLegacy.isNotEmpty) {
      _legacyPreviewFetched.addAll(needsLegacy);
      final previews = await FirestoreServices.fetchLatestMessagePreviewsForChatIds(
        _firestore,
        needsLegacy,
      );
      for (final c in built) {
        final id = c['id'] as String;
        final p = previews[id];
        if (p != null && p.trim().isNotEmpty) {
          c['lastMessage'] = p.trim();
        }
      }
    }
    if (!mounted || gen != _chatsEnrichGen) return;

    final merged = _mergeChatsWithPreviews(built);

    if (_selectedChat != null &&
        !merged.any((c) => c['id'] == _selectedChat!['id'])) {
      await _persistCurrentChatScrollIfAny();
      _selectedChat = null;
      _persistedOpenScroll = null;
      _persistedOpenScrollForChatId = null;
    } else if (_selectedChat != null) {
      final sid = _selectedChat!['id'] as String;
      try {
        final row = merged.firstWhere((c) => c['id'] == sid);
        _selectedChat = Map<String, dynamic>.from(row);
        Get.find<HomeController>().selectedChat = Map<String, dynamic>.from(
          row,
        );
      } catch (_) {}
    }

    _chats = merged;
    _loadingChats = false;
    _syncPresenceWatchFromChats(merged);
    if (!mounted || _chatsSubscription == null) return;
    _syncMessagesStreamWithSelection();
    setState(() {});
    _syncMessageSoundListener();
  }

  List<Map<String, dynamic>> _mergeChatsWithPreviews(
    List<Map<String, dynamic>> built,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final c in built) {
      final isGroup = c['isGroup'] == true;
      var preview = (c['lastMessage'] ?? '').toString().trim();
      final meta = FirestoreChatApi.lastMessageMetaFromChatData(c);
      if (preview.isEmpty && meta != null) {
        preview = meta.previewText.trim();
      }
      if (!isGroup && preview.isEmpty) continue;

      final row = Map<String, dynamic>.from(c)..['lastMessage'] = preview;
      if (meta != null) {
        row['chatListThumbImageUrl'] = meta.imageThumbUrl;
        row['chatListThumbVideoUrl'] = meta.videoThumbUrl;
        row['chatListSubtitleLine'] = meta.subtitleLine;
      }
      out.add(row);
    }
    return out;
  }

  Widget _chatListSubtitleWidget(Map<String, dynamic> ch, String fallback) {
    final img = ch['chatListThumbImageUrl'] as String?;
    final vid = ch['chatListThumbVideoUrl'] as String?;
    final hasThumb =
        (img != null && img.trim().isNotEmpty) ||
        (vid != null && vid.trim().isNotEmpty);
    if (ch.containsKey('chatListSubtitleLine')) {
      final line = (ch['chatListSubtitleLine'] as String?) ?? '';
      return ChatListTileMediaSubtitle(
        imageUrl: img,
        videoUrl: vid,
        text: line.isNotEmpty ? line : (hasThumb ? '' : fallback),
      );
    }
    final lm = (ch['lastMessage'] ?? '').toString();
    final display = lm.trim().isNotEmpty ? lm : fallback;
    return ChatListTileMediaSubtitle(
      imageUrl: img,
      videoUrl: vid,
      text: display,
    );
  }

  @override
  void dispose() {
    _flushScrollDiskTimer();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_persistCurrentChatScrollIfAny());
    _imagePasteListener?.dispose();
    final sub = _chatsSubscription;
    _chatsSubscription =
        null; // أي callback قادم من الـ stream سيرى null ولن يستدعي setState
    sub?.cancel();
    _messageSoundSubscription?.cancel();
    final bound = _messageSoundBoundChatId;
    _messageSoundBoundChatId = null;
    if (bound != null) {
      ChatAudioFocus.unregisterMainLayoutChatOpen(bound);
    }
    ChatAudioFocus.clearForeground();
    if (_currentUserId != null) {
      unawaited(
        FirestoreServices.syncEmployeeActiveChatId(_currentUserId!, null),
      );
    }
    unawaited(_typingWriter.dispose());
    _messageController.removeListener(_onComposerTextChanged);
    _messageController.dispose();
    // Do not call unfocus() here: during Android route pop it can deadlock the
    // platform text input channel; dispose() releases focus.
    _messageFocusNode.dispose();
    _searchController.dispose();
    _clearStoredChatSelectionOnHome();
    super.dispose();
  }

  String _getSelectedChatNameSync() {
    if (_selectedChat == null) return '';

    // إذا كانت مجموعة، نستخدم العنوان (Title)
    if (_selectedChat!['isGroup'] == true) {
      return _localizedGroupTitleFromChat(_selectedChat!);
    }

    // للمحادثة الفردية، نجد اسم الطرف الآخر من الكاش
    final participants = List<String>.from(
      _selectedChat!['participants'] ?? [],
    );
    final otherId = participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => 'N/A',
    );
    final other = _employees.firstWhere(
      (e) => e['id'] == otherId,
      orElse: () => {},
    );
    return other.isNotEmpty ? other['name'] : otherId.toString();
  }

  String _localizedGroupTitleFromChat(Map<String, dynamic> chat) {
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

  String? _departmentGroupAssetPathFromSlug(String rawDepartment) {
    final department = StorageKeys.normalizeDepartment(rawDepartment);
    if (department.isEmpty) return null;
    switch (department) {
      case StorageKeys.departmentContentWriting:
        return 'assets/images/content_writing_group_pic.png';
      case StorageKeys.departmentDesign:
        return 'assets/images/design_group_pic.png';
      case StorageKeys.departmentMontage:
        return 'assets/images/montage_group_pic.png';
      case StorageKeys.departmentPhotography:
        return 'assets/images/photograph_group_pic.png';
      case StorageKeys.departmentProgramming:
        return 'assets/images/programming_group_pic.png';
      case StorageKeys.departmentPromotion:
        return 'assets/images/promotion_group_pic.png';
      case StorageKeys.departmentPublishing:
        return 'assets/images/publish_group_pic.png';
      default:
        return null;
    }
  }

  String? _departmentGroupAssetPathFromChat(Map<String, dynamic> chat) {
    final chatId = (chat['id'] ?? '').toString();
    final rawTitle = (chat['title'] ?? '').toString();
    final fromChatId = chatId.startsWith('group_') && chatId.length > 6
        ? chatId.substring(6)
        : '';
    return _departmentGroupAssetPathFromSlug(
      fromChatId.isNotEmpty ? fromChatId : rawTitle,
    );
  }

  bool _chatMatchesListSearch(Map<String, dynamic> ch) {
    final q = _chatListSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    final isGroup = ch['isGroup'] ?? false;
    if (isGroup) {
      if (_localizedGroupTitleFromChat(ch).toLowerCase().contains(q)) {
        return true;
      }
      final raw = (ch['title'] ?? '').toString().toLowerCase();
      return raw.contains(q);
    }
    final participants = List<String>.from(ch['participants'] ?? []);
    final otherId = participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => 'N/A',
    );
    final other = _employees.firstWhere(
      (e) => e['id'] == otherId,
      orElse: () => {},
    );
    if (other.isNotEmpty) {
      final n = (other['name'] as String? ?? '').toLowerCase();
      if (n.contains(q)) return true;
      final em = (other['email'] ?? '').toString().toLowerCase();
      if (em.contains(q)) return true;
    }
    if (otherId.length <= 10) {
      return otherId.toLowerCase().contains(q);
    }
    return false;
  }

  List<Map<String, dynamic>> _visibleChatsForSearch() {
    final q = _chatListSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return _chats;
    return _chats.where(_chatMatchesListSearch).toList();
  }

  String? _getSelectedChatOtherImageUrlSync() {
    if (_selectedChat == null) return null;
    if (_selectedChat!['isGroup'] == true) return null;
    final participants = List<String>.from(
      _selectedChat!['participants'] ?? [],
    );
    final otherId = participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => 'N/A',
    );
    final other = _employees.firstWhere(
      (e) => e['id'] == otherId,
      orElse: () => {},
    );
    if (other.isEmpty) return null;
    final im = (other['image'] ?? '').toString().trim();
    return im.isEmpty ? null : im;
  }

  // ---------------- Create or open chat ----------------
  Future<void> _openOrCreateChatWith(String otherUserId) async {
    if (_currentUserId == null) return;

    final prevId = _selectedChat?['id'] as String?;
    if (prevId != null) {
      await _persistScrollSnapshotForChatId(_currentUserId!, prevId);
    }
    _flushScrollDiskTimer();

    final ids = [_currentUserId!, otherUserId]..sort();
    final chatId = ids.join('_');

    final chatRef = _firestore.collection('chats').doc(chatId);

    // لا get() قبل إنشاء مستند جديد. إن وُجد المستند، قد يفشل merge إن شمل الحقول
    // غير المسموحة في allow update — نُسقط إلى update(lastMessage, lastUpdated) فقط.
    try {
      await chatRef.set({
        'participants': ids,
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
        'isGroup': false, // **محادثة فردية**
      }, SetOptions(merge: true));
    } catch (e) {
      if (!e.toString().contains('permission-denied')) rethrow;
      await chatRef.update({
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    // select it
    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data() ?? {};
    final newChatId = chatDoc.id;
    final openSnap = await ChatScrollPersistence.load(
      _currentUserId!,
      newChatId,
    );
    _selectedChat = {
      'id': newChatId,
      'participants': List<String>.from(chatData['participants'] ?? []),
      'lastMessage': chatData['lastMessage'] ?? '',
      'isGroup': chatData['isGroup'] ?? false,
    };
    Get.find<HomeController>().selectedChat = {
      'id': newChatId,
      'participants': List<String>.from(chatData['participants'] ?? []),
      'lastMessage': chatData['lastMessage'] ?? '',
      'isGroup': chatData['isGroup'] ?? false,
    };

    _syncMessagesStreamWithSelection();

    setState(() {
      _scrollSnapshotCache.remove(newChatId);
      if (prevId != newChatId) {
        _chatMessageListEpoch++;
      }
      _persistedOpenScroll = openSnap;
      _persistedOpenScrollForChatId = newChatId;
    });
    _syncMessageSoundListener();
  }

  Future<void> _openOrJoinDepartmentGroup(String rawSlug) async {
    if (_currentUserId == null || _currentUserId == 'temp_current_user') return;

    final slug = StorageKeys.normalizeDepartment(rawSlug);
    if (slug.isEmpty) return;

    final prevId = _selectedChat?['id'] as String?;
    if (prevId != null) {
      await _persistScrollSnapshotForChatId(_currentUserId!, prevId);
    }
    _flushScrollDiskTimer();

    final chatId = 'group_$slug';
    final chatRef = _firestore.collection('chats').doc(chatId);
    final snap = await chatRef.get();
    if (!snap.exists) {
      await chatRef.set({
        'isGroup': true,
        'title': slug,
        'participants': [_currentUserId!],
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      final participants = List<String>.from(
        snap.data()?['participants'] ?? [],
      );
      if (!participants.contains(_currentUserId)) {
        await chatRef.update({
          'participants': [...participants, _currentUserId!],
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    }

    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data() ?? {};
    final openSnap = await ChatScrollPersistence.load(_currentUserId!, chatId);
    final row = {
      'id': chatId,
      'participants': List<String>.from(chatData['participants'] ?? []),
      'lastMessage': chatData['lastMessage'] ?? '',
      'lastUpdated': chatData['lastUpdated'],
      'isGroup': chatData['isGroup'] ?? true,
      'title': chatData['title'] ?? slug,
    };

    _selectedChat = Map<String, dynamic>.from(row);
    Get.find<HomeController>().selectedChat = Map<String, dynamic>.from(row);
    _syncMessagesStreamWithSelection();

    setState(() {
      _scrollSnapshotCache.remove(chatId);
      if (prevId != chatId) {
        _chatMessageListEpoch++;
      }
      _persistedOpenScroll = openSnap;
      _persistedOpenScrollForChatId = chatId;
    });
    _syncMessageSoundListener();
  }

  // -----------// إرسال رسالة (نص أو مرفق)
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final pending = _pendingAttachment;
    if (text.isEmpty && pending == null) return;
    unawaited(_typingWriter.clearTyping());
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

  /// تحديث معاينة آخر رسالة في القائمة فور الإرسال (قبل اكتمال Firestore).
  void _optimisticPatchLastMessage(String chatId, String preview) {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _chats.length; i++) {
        if (_chats[i]['id'] == chatId) {
          final m = Map<String, dynamic>.from(_chats[i]);
          m['lastMessage'] = preview;
          _chats[i] = m;
          break;
        }
      }
      if (_selectedChat != null && _selectedChat!['id'] == chatId) {
        _selectedChat = Map<String, dynamic>.from(_selectedChat!)
          ..['lastMessage'] = preview;
        Get.find<HomeController>().selectedChat = Map<String, dynamic>.from(
          _selectedChat!,
        );
      }
    });
  }

  Future<void> _sendChatPayload({
    required String lastMessagePreview,
    String messageType = 'text',
    String text = '',
    String? attachmentUrl,
    String? fileName,
    int? durationSec,
  }) async {
    if (_selectedChat == null || _currentUserId == null) return;
    if (messageType == 'text' && text.trim().isEmpty) return;
    if (messageType != 'text' &&
        (attachmentUrl == null || attachmentUrl.trim().isEmpty)) {
      return;
    }

    unawaited(_typingWriter.clearTyping());
    final chatId = _selectedChat!['id'] as String;
    final isGroup = _selectedChat!['isGroup'] ?? false;
    if (ChatAudioFocus.incomingTreatAsInChat(chatId)) {
      unawaited(AudioService.instance.playActiveChatOutgoingSound());
    }
    _optimisticPatchLastMessage(chatId, lastMessagePreview);
    final chatRef = _firestore.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    Get.find<HomeController>().openChat(
      OpenChatModel(
        id: chatId,
        name: _getSelectedChatNameSync(),
        avatar: isGroup ? '' : (_getSelectedChatOtherImageUrlSync() ?? ''),
        isGroup: isGroup,
      ),
    );
    final participants = List<String>.from(
      _selectedChat!['participants'] ?? [],
    );
    final otherId = participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => 'N/A',
    );

    final payload = <String, dynamic>{
      'senderId': _currentUserId,
      'senderName': _currentUserName,
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
      chatId: chatId,
      actorParticipantId: _currentUserId!,
      lastMessagePreview: lastMessagePreview,
      messageData: payload,
      participantIds: participants,
    );

    final fcmChatLabel = _getSelectedChatNameSync();
    if (!isGroup && otherId.isNotEmpty && otherId != 'N/A') {
      await FirestoreServices.sendFcm(
        userId: otherId,
        title: '$_currentUserName',
        body: lastMessagePreview,
        notificationType: 'chat_message',
        fcmDataExtras: {
          'chatId': chatId,
          'chatTitle': '$_currentUserName',
          'chatDisplayName': fcmChatLabel,
          'senderName': _currentUserName ?? '',
          'isGroup': '0',
        },
      );
    } else if (isGroup) {
      for (var id in participants) {
        if (id != _currentUserId) {
          await FirestoreServices.sendFcm(
            userId: id,
            title: 'chat.fcm_in_group_title'.trParams({
              'user': _currentUserName ?? '',
              'group': _localizedGroupTitleFromChat(_selectedChat!),
            }),
            body: lastMessagePreview,
            notificationType: 'chat_message',
            fcmDataExtras: {
              'chatId': chatId,
              'chatTitle': _localizedGroupTitleFromChat(_selectedChat!),
              'chatDisplayName': fcmChatLabel,
              'senderName': _currentUserName ?? '',
              'isGroup': '1',
            },
          );
        }
      }
    }
  }

  // ---------------- Helpers ----------------
  String _initialFromName(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    return parts.first[0].toUpperCase();
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return AppLocaleKeys.commonNow.tr;
    } else if (diff.inMinutes < 60) {
      return AppLocaleKeys.commonMinutesAgo.trParams({
        'count': '${diff.inMinutes}',
      });
    } else if (diff.inHours < 24) {
      return AppLocaleKeys.commonHoursAgo.trParams({
        'count': '${diff.inHours}',
      });
    } else if (diff.inDays < 7) {
      return 'chat.days_ago'.trParams({'count': '${diff.inDays}'});
    } else {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
  }

  Future<void> _handlePastedImage(Uint8List bytes, String mimeType) async {
    if (!mounted || _selectedChat == null) return;
    final controller = Get.find<HomeController>();
    if (controller.isUploading.value) return;

    final fileName =
        'pasted_${DateTime.now().millisecondsSinceEpoch}.${_extFromMime(mimeType)}';
    final chatId = _selectedChat!['id'] as String;
    final pending = await stageChatMediaUpload(
      bytes: bytes,
      fileName: fileName,
      chatId: chatId,
      home: controller,
      activityWriter: _typingWriter,
    );
    if (!mounted || pending == null) return;
    setState(() => _pendingAttachment = pending);
    controller.uploadedFilesPaths.clear();
  }

  Future<void> _pasteImageFromClipboard() async {
    final data = await readClipboardImageData();
    if (!mounted || _selectedChat == null) return;
    if (data == null || data.bytes.isEmpty) {
      _showPasteImageFailed();
      return;
    }
    await _handlePastedImage(data.bytes, data.mimeType);
  }

  void _showPasteImageFailed() {
    if (!mounted) return;
    FunHelper.showSnackbarDeduped(
      AppLocaleKeys.errorTitle.tr,
      AppLocaleKeys.chatPasteImageFailed.tr,
      dedupeKey: 'chat_paste_image_failed',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      autoHideAfter: const Duration(seconds: 2),
    );
  }

  String _extFromMime(String mimeType) {
    final t = mimeType.trim().toLowerCase();
    if (t == 'image/jpeg' || t == 'image/jpg') return 'jpg';
    if (t == 'image/webp') return 'webp';
    if (t == 'image/gif') return 'gif';
    if (t == 'image/bmp') return 'bmp';
    return 'png';
  }

  // ---------------- UI dialogs ----------------
  Future<void> _showAddChatDialog() async {
    _searchController.clear();
    _filterEmployees('');
    final groups = _joinableDepartmentGroups();
    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: StatefulBuilder(
            builder: (ctx, setStateDialog) {
              // نستخدم StatefulBuilder لتمكين إعادة بناء داخل الـ Dialog
              void filterEmployeesDialog(String q) {
                final qlower = q.trim().toLowerCase();
                if (qlower.isEmpty) {
                  _filteredEmployees = List.from(_employees);
                } else {
                  _filteredEmployees = _employees
                      .where(
                        (e) => (e['name'] as String).toLowerCase().contains(
                          qlower,
                        ),
                      )
                      .toList();
                }
                setStateDialog(() {});
              }

              final qlower = _searchController.text.trim().toLowerCase();
              final filteredGroups = qlower.isEmpty
                  ? groups
                  : groups.where((g) {
                      final localized = _localizedGroupTitleFromChat(
                        g,
                      ).toLowerCase();
                      final raw = (g['title'] ?? '').toString().toLowerCase();
                      return localized.contains(qlower) || raw.contains(qlower);
                    }).toList();
              final hasItems =
                  _filteredEmployees.isNotEmpty || filteredGroups.isNotEmpty;

              return Container(
                width: 420,
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocaleKeys.chatSearch.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: AppLocaleKeys.chatSearchEmployee.tr,
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => filterEmployeesDialog(v),
                    ),
                    SizedBox(height: 12),
                    Container(
                      constraints: BoxConstraints(maxHeight: 360),
                      child: _loadingEmployees
                          ? Center(child: CircularProgressIndicator())
                          : !hasItems
                          ? Center(
                              child: Text(AppLocaleKeys.chatNoEmployees.tr),
                            )
                          : ListView(
                              children: [
                                if (filteredGroups.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      6,
                                      16,
                                      4,
                                    ),
                                    child: Text(
                                      AppLocaleKeys.chatPickerGroupsSection.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blueGrey.shade700,
                                      ),
                                    ),
                                  ),
                                  ...filteredGroups.map((group) {
                                    final joined = group['isJoined'] == true;
                                    final displayName =
                                        _localizedGroupTitleFromChat(group);
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            Colors.blueGrey.shade100,
                                        child: const Icon(
                                          Icons.group,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      title: Text(displayName),
                                      subtitle: Text(
                                        joined
                                            ? AppLocaleKeys.chatGroupJoined.tr
                                            : AppLocaleKeys
                                                  .chatGroupTapToJoin
                                                  .tr,
                                      ),
                                      onTap: () async {
                                        Navigator.of(ctx).pop();
                                        await _openOrJoinDepartmentGroup(
                                          (group['slug'] ?? '')
                                              .toString()
                                              .trim(),
                                        );
                                      },
                                    );
                                  }),
                                ],
                                if (_filteredEmployees.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      10,
                                      16,
                                      4,
                                    ),
                                    child: Text(
                                      AppLocaleKeys.chatPickEmployee.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blueGrey.shade700,
                                      ),
                                    ),
                                  ),
                                  ..._filteredEmployees.map((emp) {
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.grey.shade200,
                                        child: Text(
                                          _initialFromName(emp['name']),
                                          style: TextStyle(color: Colors.black),
                                        ),
                                      ),
                                      title: Text(emp['name']),
                                      subtitle: Text(emp['email'] ?? ''),
                                      onTap: () async {
                                        Navigator.of(ctx).pop();
                                        await _openOrCreateChatWith(emp['id']);
                                      },
                                    );
                                  }),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    // Keep UI EXACTLY like design you provided:
    return GetBuilder<HomeController>(
      builder: (controller) {
        final visibleChats = _visibleChatsOrderedForSidebar();
        return Scaffold(
          // key: widget.key,
          appBar: PreferredSize(
            preferredSize: Size(Get.width, Get.height),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.black),
                  onPressed: () async {
                    await _persistCurrentChatScrollIfAny();
                    if (!mounted) return;
                    _clearStoredChatSelectionOnHome();
                    widget.onMinimize();
                  },
                ),
              ],
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              color: const Color(0xfff7f9fc),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                // ===== RIGHT: chats history (design has this on the right originally) =====
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: EdgeInsets.only(top: 30, right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        // search + add
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: SizedBox(
                            height: 45,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: AppLocaleKeys.chatSearch.tr,
                                      prefixIcon: Icon(Icons.search),
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        _chatListSearchQuery = v;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: _showAddChatDialog,
                                    child: Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Icon(
                                        Icons.add,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ChatListFolderTabs(
                          selected: _chatListFolder,
                          onSelected: (f) {
                            setState(() => _chatListFolder = f);
                          },
                        ),
                        if (_isLoadingGroup || _loadingChats)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                minHeight: 4,
                                color: kChatUiAccent,
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ),
                          ),

                        // chats list
                        Expanded(
                          child: _loadingChats
                              ? const SizedBox.shrink()
                              : _chats.isEmpty
                              ? Center(
                                  child: Text(AppLocaleKeys.chatNoChats.tr),
                                )
                              : visibleChats.isEmpty &&
                                    _chatListSearchQuery.trim().isNotEmpty
                              ? Center(
                                  child: Text(
                                    AppLocaleKeys.chatSearchNoMatches.tr,
                                  ),
                                )
                              : visibleChats.isEmpty
                              ? Center(
                                  child: Text(AppLocaleKeys.chatFolderEmpty.tr),
                                )
                              : ListView.builder(
                                  itemCount: visibleChats.length,
                                  itemBuilder: (context, index) {
                                    final ch = visibleChats[index];
                                    final isGroup = ch['isGroup'] ?? false;
                                    final chatId = ch['id'] as String;

                                    String displayName;
                                    String initial;
                                    String? employImage;
                                    Color avatarColor;
                                    IconData? avatarIcon;
                                    String? groupAssetPath;
                                    Color? titleColor;
                                    String? titleSubline;
                                    var showPrivateOnlineDot = false;
                                    String? otherIdForPresence;

                                    if (isGroup) {
                                      displayName =
                                          _localizedGroupTitleFromChat(ch);
                                      initial = _initialFromName(displayName);
                                      avatarColor = Colors.blueGrey.shade100;
                                      avatarIcon = Icons.group;
                                      groupAssetPath =
                                          _departmentGroupAssetPathFromChat(ch);
                                      titleColor = Colors.blue.shade700;
                                      final connected =
                                          _connectedUsersCountForGroup(ch);
                                      titleSubline =
                                          AppLocaleKeys.chatConnectedCount
                                              .trParams({
                                                'count': '$connected',
                                              });
                                    } else {
                                      // محادثة فردية
                                      final participants = List<String>.from(
                                        ch['participants'] ?? [],
                                      );
                                      final otherId = participants.firstWhere(
                                        (id) => id != _currentUserId,
                                        orElse: () => 'N/A',
                                      );

                                      _otherUserId = otherId;
                                      appLog(_otherUserId.toString());
                                      otherIdForPresence = otherId;
                                      final other = _employees.firstWhere(
                                        (e) => e['id'] == otherId,
                                        orElse: () => {},
                                      );
                                      displayName = other.isNotEmpty
                                          ? other['name']
                                          : (otherId.length > 10
                                                ? AppLocaleKeys
                                                      .chatUnknownUser
                                                      .tr
                                                : otherId);
                                      initial = _initialFromName(displayName);
                                      employImage = other['image'];
                                      avatarColor = Colors.grey.shade200;
                                      avatarIcon = null;
                                      groupAssetPath = null;
                                      titleColor = Colors.black;
                                      showPrivateOnlineDot = _isOnlinePresence(
                                        _presenceOf(otherIdForPresence),
                                      );
                                      titleSubline =
                                          _privatePresenceLabel(otherIdForPresence);
                                    }

                                    return GestureDetector(
                                      onLongPressStart: (details) {
                                        _showChatListPinMenu(
                                          context,
                                          details.globalPosition,
                                          chatId,
                                        );
                                      },
                                      child: ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        tileColor:
                                            _selectedChat != null &&
                                                _selectedChat!['id'] == chatId
                                            ? Colors.grey.shade100
                                            : null,
                                        onTap: () async {
                                          final prevId =
                                              _selectedChat?['id'] as String?;
                                          final uid = _currentUserId;
                                          if (uid != null && prevId != null) {
                                            await _persistScrollSnapshotForChatId(
                                              uid,
                                              prevId,
                                            );
                                          }
                                          _flushScrollDiskTimer();
                                          _replyDraft = null;
                                          final nextChatId = ch['id'] as String;
                                          _scrollSnapshotCache.remove(
                                            nextChatId,
                                          );
                                          _selectedChat = ch;
                                          final participants =
                                              List<String>.from(
                                                ch['participants'] ?? [],
                                              );
                                          final otherId = participants
                                              .firstWhere(
                                                (id) => id != _currentUserId,
                                                orElse: () => 'N/A',
                                              );

                                          _otherUserId = otherId;
                                          _syncMessagesStreamWithSelection();
                                          appLog(_otherUserId.toString());

                                          final openSnap =
                                              _currentUserId != null
                                              ? await ChatScrollPersistence.load(
                                                  _currentUserId!,
                                                  nextChatId,
                                                )
                                              : null;

                                          if (!isGroup) {
                                            final participants =
                                                List<String>.from(
                                                  ch['participants'] ?? [],
                                                );
                                            _otherUserId = participants
                                                .firstWhere(
                                                  (id) => id != _currentUserId,
                                                );
                                          } else {
                                            _otherUserId = null;
                                          }
                                          if (!mounted) return;
                                          setState(() {
                                            if (prevId != nextChatId) {
                                              _chatMessageListEpoch++;
                                            }
                                            _persistedOpenScroll = openSnap;
                                            _persistedOpenScrollForChatId =
                                                nextChatId;
                                          });
                                          _syncMessageSoundListener();
                                        },
                                        leading: chatListLeadingWithPinBadge(
                                          pinned: _pinnedChatIds.contains(
                                            chatId,
                                          ),
                                          avatarChild: _avatarWithOnlineDot(
                                            showOnlineDot: !isGroup &&
                                                showPrivateOnlineDot,
                                            avatar: chatLeadingAvatar(
                                              radius: 24,
                                              backgroundColor: avatarColor,
                                              initial: initial,
                                              groupIcon: avatarIcon,
                                              assetImagePath: groupAssetPath,
                                              imageUrl: employImage
                                                  ?.toString()
                                                  .trim(),
                                            ),
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight:
                                                      ((ch['unreadIncoming']
                                                                  as int?) ??
                                                              0) >
                                                          0
                                                      ? FontWeight.bold
                                                      : FontWeight.w400,
                                                  color: titleColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: _chatListSubtitleWidget(
                                            ch,
                                            isGroup
                                                ? AppLocaleKeys
                                                      .chatGroupConversation
                                                      .tr
                                                : '',
                                          ),
                                        ),
                                        trailing: ChatListRowTrailing(
                                          titleSubline: titleSubline,
                                          highlightSubline: !isGroup &&
                                              showPrivateOnlineDot,
                                          unreadCount:
                                              (ch['unreadIncoming'] as int?) ??
                                              0,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: 10),

                // ===== LEFT: active chat messages (design had left side as chat view) =====
                Expanded(
                  flex: 5,
                  child: Container(
                    // keep exactly the same structure inside
                    child: _selectedChat == null
                        ? Center(
                            child: Text(
                              AppLocaleKeys.chatSelectFromList.tr,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 18,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // header
                              Container(
                                margin: EdgeInsets.only(top: 30, left: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          final isGroup =
                                              _selectedChat!['isGroup'] ==
                                              true;
                                          final name =
                                              _getSelectedChatNameSync();
                                          final rawOtherImg =
                                              _getSelectedChatOtherImageUrlSync();
                                          final otherUrlTrim =
                                              rawOtherImg?.trim() ?? '';
                                          String? otherParticipantId;
                                          if (!isGroup &&
                                              _currentUserId != null) {
                                            final parts =
                                                List<String>.from(
                                              _selectedChat!['participants'] ??
                                                  const [],
                                            );
                                            for (final id in parts) {
                                              if (id != _currentUserId) {
                                                otherParticipantId = id;
                                                break;
                                              }
                                            }
                                          }
                                          final privateOnlineDot =
                                              !isGroup &&
                                              _isOnlinePresence(
                                                _presenceOf(otherParticipantId),
                                              );

                                          Widget avatar;
                                          if (!isGroup &&
                                              isChatImageHttpUrl(rawOtherImg)) {
                                            avatar = _avatarWithOnlineDot(
                                              showOnlineDot: privateOnlineDot,
                                              avatar: CircleAvatar(
                                                radius: 28,
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                child: ClipOval(
                                                  child: Image.network(
                                                    otherUrlTrim,
                                                    width: 56,
                                                    height: 56,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (
                                                      _,
                                                      __,
                                                      ___,
                                                    ) =>
                                                        Text(
                                                      _initialFromName(name),
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else {
                                            avatar = _avatarWithOnlineDot(
                                              showOnlineDot:
                                                  privateOnlineDot && !isGroup,
                                              avatar: chatLeadingAvatar(
                                                radius: 28,
                                                backgroundColor: isGroup
                                                    ? Colors
                                                        .blueGrey
                                                        .shade100
                                                    : Colors.grey.shade200,
                                                initial:
                                                    _initialFromName(name),
                                                groupIcon: isGroup
                                                    ? Icons.group
                                                    : null,
                                                assetImagePath: isGroup
                                                    ? _departmentGroupAssetPathFromChat(
                                                        _selectedChat!,
                                                      )
                                                    : null,
                                                imageUrl: isGroup
                                                    ? null
                                                    : (otherUrlTrim.isEmpty
                                                          ? null
                                                          : rawOtherImg),
                                              ),
                                            );
                                          }

                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              avatar,
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow
                                                              .ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    ChatActivitySubline(
                                                      chatId:
                                                          (_selectedChat!['id']
                                                                  as String?) ??
                                                              '',
                                                      isGroup: isGroup,
                                                      otherUserId:
                                                          otherParticipantId,
                                                      groupParticipantIds: isGroup
                                                          ? List<String>.from(
                                                              _selectedChat![
                                                                      'participants'] ??
                                                                  const [],
                                                            )
                                                          : const [],
                                                      participantNames:
                                                          _participantNamesMap(),
                                                      selfUserId:
                                                          _currentUserId ?? '',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedChat!['isGroup'] == true
                                          ? AppLocaleKeys.chatGroupType.tr
                                          : AppLocaleKeys.chatPrivateType.tr,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 15),
                              // messages area (stream) — no outer [SingleChildScrollView]
                              // nesting (it prevented [ItemPositionsListener] from working).
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: _messagesStream == null ||
                                          _currentUserId == null
                                      ? Center(
                                          child: Text(
                                            AppLocaleKeys.chatNoMessages.tr,
                                          ),
                                        )
                                      : Builder(
                                          builder: (context) {
                                            final selChatId =
                                                _selectedChat!['id'] as String;
                                            final mem =
                                                _scrollSnapshotCache[selChatId];
                                            final disk =
                                                _persistedOpenScrollForChatId ==
                                                    selChatId
                                                ? _persistedOpenScroll
                                                : null;
                                            final persistedForResolve =
                                                mem ?? disk;
                                            return ChatMessagesViewport(
                                              chatId: selChatId,
                                              child: ChatMessageListHost(
                                              stream: _messagesStream!,
                                              chatId: selChatId,
                                              currentUserId: _currentUserId!,
                                              listEpoch: _chatMessageListEpoch,
                                              panelController:
                                                  _chatListPanelController,
                                              persistedScroll:
                                                  persistedForResolve,
                                              usePersistedScroll:
                                                  persistedForResolve != null,
                                              loadingWidget: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                              emptyWidget: Center(
                                                child: Text(
                                                  AppLocaleKeys
                                                      .chatNoMessages
                                                      .tr,
                                                ),
                                              ),
                                              onDocsChanged:
                                                  _onChatListDocsChanged,
                                              onScrollSnapshotChanged:
                                                  _onChatListScrollSnapshot,
                                              pinnedBannerBuilder:
                                                  (context, pinnedDocs) =>
                                                      Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                  12,
                                                  8,
                                                  12,
                                                  4,
                                                ),
                                                child: ChatPinnedMessagesBar(
                                                  pinnedDocs: pinnedDocs,
                                                  isGroup:
                                                      _selectedChat!['isGroup'] ==
                                                      true,
                                                  onTapMessage:
                                                      _scrollToRepliedMessage,
                                                ),
                                              ),
                                              itemBuilder: (context, doc, i) {
                                                final d = doc.data();
                                                final mid = doc.id;
                                                final isMe =
                                                    d['senderId'] ==
                                                    _currentUserId;
                                                final ts =
                                                    d['timestamp']
                                                        as Timestamp?;
                                                final senderName =
                                                    d['senderName'] ??
                                                    AppLocaleKeys
                                                        .chatSenderFallback
                                                        .tr;
                                                final isRead =
                                                    d['isRead'] == true;

                                                return Padding(
                                                  key: ValueKey(mid),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                                  child: ChatMessageTile(
                                                    chatId: selChatId,
                                                    messageId: mid,
                                                    message:
                                                        Map<
                                                          String,
                                                          dynamic
                                                        >.from(d),
                                                    isMe: isMe,
                                                    isGroup:
                                                        _selectedChat!['isGroup'] ==
                                                        true,
                                                    senderName: senderName,
                                                    showGroupSenderName: !isMe &&
                                                        (_selectedChat?['isGroup'] ??
                                                            false),
                                                    timestamp: ts,
                                                    formatTime:
                                                        _formatTimestamp,
                                                    isAdmin:
                                                        _currentUserRole ==
                                                        'admin',
                                                    currentUserId:
                                                        _currentUserId!,
                                                    currentUserDisplayName:
                                                        _currentUserName,
                                                    onReply: (draft) =>
                                                        setState(
                                                      () => _replyDraft = draft,
                                                    ),
                                                    onReplyPreviewTap:
                                                        _scrollToRepliedMessage,
                                                    bubbleDecoration:
                                                        BoxDecoration(
                                                      color: isMe
                                                          ? AppColors.primary
                                                          : Colors
                                                              .grey
                                                              .shade100,
                                                      borderRadius:
                                                          BorderRadius.only(
                                                        topLeft:
                                                            const Radius.circular(
                                                          17,
                                                        ),
                                                        topRight:
                                                            const Radius.circular(
                                                          17,
                                                        ),
                                                        bottomLeft:
                                                            Radius.circular(
                                                          isMe ? 17 : 5,
                                                        ),
                                                        bottomRight:
                                                            Radius.circular(
                                                          isMe ? 5 : 17,
                                                        ),
                                                      ),
                                                    ),
                                                    maxWidthFactor: 0.6,
                                                    alignment: isMe
                                                        ? Alignment.centerRight
                                                        : Alignment.centerLeft,
                                                    columnCrossAxis: isMe
                                                        ? CrossAxisAlignment.end
                                                        : CrossAxisAlignment
                                                            .start,
                                                    showReadReceipts: true,
                                                    messageIsRead: isRead,
                                                  ),
                                                );
                                              },
                                            ),
                                            );
                                          },
                                        ),
                                ),
                              ),

                              // input text and send button
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 860,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        ChatUploadProgressBanner(
                                          chatId: _selectedChat!['id'] as String,
                                        ),
                                        if (_replyDraft != null)
                                          ChatReplyDraftBanner(
                                            draft: _replyDraft!,
                                            onCancel: () => setState(
                                              () => _replyDraft = null,
                                            ),
                                          ),
                                        if (_pendingAttachment != null)
                                          PendingAttachmentStrip(
                                            pending: _pendingAttachment!,
                                            onCancel: () => setState(
                                              () => _pendingAttachment = null,
                                            ),
                                            onTapPreview:
                                                (_pendingAttachment!
                                                            .messageType ==
                                                        'image' ||
                                                    _pendingAttachment!
                                                            .messageType ==
                                                        'video')
                                                ? () => openChatMediaFromUrl(
                                                    _pendingAttachment!
                                                        .attachmentUrl,
                                                    chatId: _selectedChat!['id']
                                                        as String?,
                                                  )
                                                : null,
                                          ),
                                        Obx(() {
                                          final chatId =
                                              _selectedChat!['id'] as String;
                                          final busy = controller
                                              .isChatUploadActiveFor(chatId);
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons
                                                      .sentiment_satisfied_alt_outlined,
                                                ),
                                                onPressed: busy
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          _isEmojiVisible =
                                                              !_isEmojiVisible;
                                                          FocusScope.of(
                                                            context,
                                                          ).unfocus();
                                                        });
                                                      },
                                              ),
                                              if (chatMobileCameraSupported())
                                                IconButton(
                                                  tooltip: AppLocaleKeys
                                                      .chatAttachPhoto
                                                      .tr,
                                                  icon: const Icon(
                                                    Icons.camera_alt_outlined,
                                                  ),
                                                  onPressed: busy
                                                      ? null
                                                      : () async {
                                                          final shot =
                                                              await controller
                                                                  .pickChatCameraImageBytes();
                                                          if (shot == null) {
                                                            return;
                                                          }
                                                          final pending =
                                                              await stageChatMediaUpload(
                                                            bytes: shot.bytes,
                                                            fileName:
                                                                shot.fileName,
                                                            chatId: _selectedChat![
                                                                    'id']
                                                                as String,
                                                            home: controller,
                                                            activityWriter:
                                                                _typingWriter,
                                                          );
                                                          if (pending == null) {
                                                            return;
                                                          }
                                                          setState(
                                                            () =>
                                                                _pendingAttachment =
                                                                    pending,
                                                          );
                                                          controller
                                                              .uploadedFilesPaths
                                                              .clear();
                                                        },
                                                ),
                                              IconButton(
                                                tooltip: AppLocaleKeys
                                                    .chatAttachGallery
                                                    .tr,
                                                icon: const Icon(
                                                  Icons.perm_media_outlined,
                                                ),
                                                onPressed: busy
                                                    ? null
                                                    : () async {
                                                        final v = await controller
                                                            .pickOneChatGalleryMedia();
                                                        if (v.isEmpty ||
                                                            v.first.bytes ==
                                                                null) {
                                                          return;
                                                        }
                                                        final picked = v.first;
                                                        final pending =
                                                            await stageChatMediaUpload(
                                                          bytes: picked.bytes!,
                                                          fileName: picked.name,
                                                          chatId: _selectedChat![
                                                                  'id']
                                                              as String,
                                                          home: controller,
                                                          activityWriter:
                                                              _typingWriter,
                                                        );
                                                        if (pending == null) {
                                                          return;
                                                        }
                                                        setState(
                                                          () =>
                                                              _pendingAttachment =
                                                                  pending,
                                                        );
                                                        controller
                                                            .uploadedFilesPaths
                                                            .clear();
                                                      },
                                              ),
                                              IconButton(
                                                tooltip: AppLocaleKeys
                                                    .chatAttachFile
                                                    .tr,
                                                icon: const Icon(
                                                  Icons.attach_file,
                                                ),
                                                onPressed: busy
                                                    ? null
                                                    : () async {
                                                        final v = await controller
                                                            .pickOneChatFile();
                                                        if (v.isEmpty ||
                                                            v.first.bytes ==
                                                                null) {
                                                          return;
                                                        }
                                                        final pending =
                                                            await stageChatFileUpload(
                                                          bytes: v.first.bytes!,
                                                          fileName: v.first.name,
                                                          chatId: _selectedChat![
                                                                  'id']
                                                              as String,
                                                          home: controller,
                                                          activityWriter:
                                                              _typingWriter,
                                                        );
                                                        if (pending == null) {
                                                          return;
                                                        }
                                                        setState(
                                                          () =>
                                                              _pendingAttachment =
                                                                  pending,
                                                        );
                                                        controller
                                                            .uploadedFilesPaths
                                                            .clear();
                                                      },
                                              ),
                                              IconButton(
                                                tooltip: AppLocaleKeys
                                                    .chatPasteImage
                                                    .tr,
                                                icon: const Icon(
                                                  Icons.content_paste,
                                                ),
                                                onPressed: busy
                                                    ? null
                                                    : _pasteImageFromClipboard,
                                              ),
                                              ChatVoiceRecordButton(
                                                chatId:
                                                    _selectedChat!['id']
                                                        as String,
                                                activityWriter: _typingWriter,
                                                onUploaded: (url, sec) async {
                                                  setState(
                                                    () => _pendingAttachment =
                                                        PendingChatAttachment(
                                                          messageType: 'voice',
                                                          attachmentUrl: url,
                                                          durationSec: sec > 0
                                                              ? sec
                                                              : null,
                                                        ),
                                                  );
                                                  controller.uploadedFilesPaths
                                                      .clear();
                                                },
                                              ),
                                              Expanded(
                                                child: Theme(
                                                  data: Theme.of(context).copyWith(
                                                    textSelectionTheme:
                                                        const TextSelectionThemeData(
                                                          cursorColor: AppColors.primary,
                                                          selectionHandleColor:
                                                              AppColors.primary,
                                                          selectionColor: Color(0x33514091),
                                                        ),
                                                  ),
                                                  child: Focus(
                                                    onKeyEvent:
                                                        _onComposerKeyEvent,
                                                    child: TextField(
                                                      cursorColor: AppColors.primary,
                                                      controller:
                                                          _messageController,
                                                      focusNode:
                                                          _messageFocusNode,
                                                      contentInsertionConfiguration:
                                                          _enableContentInsertion
                                                          ? ContentInsertionConfiguration(
                                                              allowedMimeTypes:
                                                                  const <
                                                                    String
                                                                  >[
                                                                    'image/png',
                                                                    'image/jpeg',
                                                                    'image/webp',
                                                                    'image/gif',
                                                                  ],
                                                              onContentInserted:
                                                                  (
                                                                    KeyboardInsertedContent
                                                                    content,
                                                                  ) {
                                                                    final data =
                                                                        content
                                                                            .data;
                                                                    if (data ==
                                                                            null ||
                                                                        data.isEmpty) {
                                                                      _showPasteImageFailed();
                                                                      return;
                                                                    }
                                                                    unawaited(
                                                                      _handlePastedImage(
                                                                        data,
                                                                        content
                                                                            .mimeType,
                                                                      ),
                                                                    );
                                                                  },
                                                            )
                                                          : null,
                                                      minLines: 1,
                                                      maxLines: 6,
                                                      keyboardType:
                                                          TextInputType
                                                              .multiline,
                                                      textInputAction:
                                                          chatComposerTextInputAction(),
                                                      readOnly: busy,
                                                      textAlignVertical:
                                                          TextAlignVertical
                                                              .center,
                                                      textDirection:
                                                          textDirectionForTypedChatMessage(
                                                            _messageController
                                                                .text,
                                                            Directionality.of(
                                                              context,
                                                            ),
                                                          ),
                                                      textAlign:
                                                          TextAlign.start,
                                                      decoration: InputDecoration(
                                                        hintText: AppLocaleKeys
                                                            .chatWriteMessage
                                                            .tr,
                                                        filled: true,
                                                        fillColor: Colors
                                                            .grey
                                                            .shade100,
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          borderSide:
                                                              BorderSide.none,
                                                        ),
                                                        contentPadding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 8,
                                                            ),
                                                      ),
                                                      onTap: () {
                                                        if (_isEmojiVisible) {
                                                          setState(
                                                            () =>
                                                                _isEmojiVisible =
                                                                    false,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              MouseRegion(
                                                cursor:
                                                    SystemMouseCursors.click,
                                                child: GestureDetector(
                                                  onTap: busy
                                                      ? null
                                                      : _sendMessage,
                                                  child: Container(
                                                    width: 45,
                                                    height: 45,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            15,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.send,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Emoji Picker
                              Offstage(
                                offstage: !_isEmojiVisible,
                                child: SizedBox(
                                  height: 250,
                                  child: EmojiPicker(
                                    onEmojiSelected: (category, emoji) {
                                      _messageController.text += emoji.emoji;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
