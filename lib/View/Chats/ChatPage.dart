import 'dart:async';
import 'package:point/Utils/app_log.dart';
import 'package:point/Utils/text_input_bidi.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/AudioService.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/ChatIncomingMessageSound.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/firestore/firestore_chat_api.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/chat_clipboard_image_reader.dart';
import 'package:point/Services/chat_scroll_persistence.dart';
import 'package:point/Services/chat_image_paste_listener.dart';
import 'package:point/View/Chats/chat_message_display.dart';
import 'package:point/View/Chats/chat_message_tile.dart';
import 'package:point/View/Chats/pending_chat_attachment.dart';
import 'package:point/View/Chats/chat_scroll_to_latest_fab.dart';
import 'package:point/View/Chats/chat_list_tile_media_subtitle.dart';
import 'package:point/View/Chats/chat_reply_draft_banner.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';
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
  final FirestoreServices _firestoreServices = FirestoreServices();
  // final FirebaseAuth _auth = FirebaseAuth.instance;

  // local caches
  String? _currentUserId;
  String? _otherUserId;
  String? _currentUserName;
  // **إضافة لتخزين بيانات الموظف الحالي**
  String? _currentUserDept;
  String? _currentUserRole;

  List<Map<String, dynamic>> _employees = []; // all employees
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<Map<String, dynamic>> _groupParticipants =
      []; // **لتخزين المشاركين في مجموعة القسم**

  List<Map<String, dynamic>> _chats = []; // chats list for current user
  String _chatListSearchQuery = '';
  Map<String, dynamic>? _selectedChat; // selected chat doc (id + data)
  ChatReplyDraft? _replyDraft;

  final ItemScrollController _chatMessageItemScrollController =
      ItemScrollController();
  final ItemPositionsListener _chatItemPositionsListener =
      ItemPositionsListener.create();
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _markReadSubscription;

  /// يمنع تطبيق دمج معاينات قديم بعد snapshot أحدث.
  int _chatsEnrichGen = 0;

  /// يمنع إلغاء اشتراك الصوت عند كل تحديث لقائمة المحادثات (كان يُرمى أول snapshot فيه الرسائل الجديدة).
  String? _messageSoundBoundChatId;

  /// Avoid rebuilding the whole chat on every [ItemPositionsListener] tick (hurts scroll + FAB is enough).
  bool? _scrollFabVisibleLast;
  int _scrollUnreadBelowLast = -1;

  bool _loadingEmployees = true;
  bool _loadingChats = true;
  bool _isLoadingGroup = false; // **إضافة حالة تحميل للمجموعة**

  bool get _enableContentInsertion =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onComposerTextChanged);
    _imagePasteListener = ChatImagePasteListener(
      onImagePasted: _handlePastedImage,
      onPasteError: _showPasteImageFailed,
      shouldHandle:
          () =>
              mounted &&
              _selectedChat != null &&
              !_messageFocusNode.hasFocus &&
              (WidgetsBinding.instance.lifecycleState == null ||
                  WidgetsBinding.instance.lifecycleState ==
                      AppLifecycleState.resumed),
    );
    _chatItemPositionsListener.itemPositions.addListener(
      _onChatScrollPositions,
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
    }
  }

  void _onChatScrollPositions() {
    final cid = _messagesStreamChatId;
    final snap = chatScrollSnapshotFromItemPositions(
      _chatItemPositionsListener.itemPositions.value,
    );
    if (cid != null && snap != null) {
      final len = _orderedChatMessageDocs.length;
      if (len == 0 || snap.index < len) {
        _scrollSnapshotCache[cid] = snap;
        _scheduleDebouncedDiskPersist();
      }
    }
    final uid = _currentUserId;
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

  void _onComposerTextChanged() {
    if (mounted) setState(() {});
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

  /// Persists scroll for [chatId] using live positions only when that chat is the active stream.
  Future<void> _persistScrollSnapshotForChatId(String uid, String chatId) async {
    final live =
        _messagesStreamChatId == chatId
            ? chatScrollSnapshotFromItemPositions(
              _chatItemPositionsListener.itemPositions.value,
            )
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
      _currentUserDept = StorageKeys.normalizeDepartment(
        homeController.currentEmployee.value?.department,
      );
      _currentUserRole = homeController.currentEmployee.value?.role;
    } else {
      // if no users at all, create a temporary id (but better to have employees collection)
      _currentUserId = 'temp_current_user';
      _currentUserName = 'Me'.tr;
      _currentUserDept = null;
      _currentUserRole = null;
    }

    await _loadEmployees();
    await _createOrLoadDepartmentGroup(); // **تحميل مجموعة القسم**
    _listenChats();
  }

  // ---------------- Employees ----------------
  Future<void> _loadEmployees() async {
    _loadingEmployees = true;
    setState(() {});
    final snapshot = await _firestore.collection('employees').get();
    _employees =
        snapshot.docs
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
                'dept': data['department'] ?? '', // **إضافة حقل القسم**
                'role': data['role'] ?? '', // **إضافة حقل الدور**
              };
            })
            .toList();

    // For employee role: show only allowed chat targets.
    // Managers can still chat with anyone.
    if (_currentUserRole == 'employee') {
      final myDept = _currentUserDept;
      _employees =
          _employees.where((e) {
            final targetRole = e['role'];
            final targetDept = e['dept'];
            final isSpecialRole = StorageKeys.isChatElevatedRole(targetRole);
            final isSameDept =
                myDept != null && myDept.isNotEmpty
                    ? StorageKeys.matchesDepartment(targetDept, myDept)
                    : false;
            return isSpecialRole || isSameDept;
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
      _filteredEmployees =
          _employees
              .where(
                (e) => (e['name'] as String).toLowerCase().contains(qlower),
              )
              .toList();
    }
    setState(() {});
  }

  // **---------------- Department Group Logic ----------------**

  Future<void> _createOrLoadDepartmentGroup() async {
    if (_currentUserId == null ||
        _currentUserDept == null ||
        _currentUserDept!.isEmpty) {
      return; // لا يمكن إنشاء مجموعة بدون مُعرف مستخدم أو قسم
    }

    _isLoadingGroup = true;
    setState(() {});

    final deptGroupName = _currentUserDept!;
    final groupId = 'group_$deptGroupName';
    final groupRef = _firestore.collection('chats').doc(groupId);

    // 1. تحديد المشاركين في المجموعة
    // هم جميع الموظفين في نفس القسم + جميع الأدمن والسوبر فايزر
    final List<String> participantsIds = [];
    _groupParticipants.clear();

    // إضافة الموظف الحالي
    participantsIds.add(_currentUserId!);

    // إضافة الموظفين من نفس القسم والموظفين ذوي الأدوار الخاصة (Admin/Supervisor)
    _employees.forEach((emp) {
      final empId = emp['id'] as String;
      final empDept = emp['dept'];

      // تحقق إذا كان موظف من نفس القسم (ويستثنى الموظف الحالي الذي أضفناه بالفعل)
      final isSameDept = StorageKeys.matchesDepartment(empDept, deptGroupName);

      // تحقق إذا كان أدمن أو سوبر فايزر
      final isSpecialRole = StorageKeys.isChatElevatedRole(emp['role']);

      if ((isSameDept || isSpecialRole) &&
          empId != _currentUserId &&
          !participantsIds.contains(empId)) {
        participantsIds.add(empId);
        _groupParticipants.add(
          emp,
        ); // إضافة بيانات المشاركين الآخرين للاستخدام المحلي
      }
    });

    // 2. تحديث/إنشاء المجموعة
    final groupSnapshot = await groupRef.get();

    if (!groupSnapshot.exists) {
      // إنشاء مستند المجموعة إذا لم يكن موجودًا
      await groupRef.set({
        'isGroup': true, // **علامة للمجموعة**
        'title': deptGroupName, // canonical department key
        'participants': participantsIds,
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // تحديث قائمة المشاركين في حالة وجودها (لإضافة الأدمن/السوبر فايزر الجدد أو موظفي القسم الجدد)
      // قد تحتاج إلى التحقق من Participants قبل التحديث لتجنب الكتابة المتكررة
      final existingParticipants = List<String>.from(
        groupSnapshot.data()?['participants'] ?? [],
      );
      // Runtime: فقط تأكد أن الموظف الحالي موجود داخل المجموعة.
      // باقي الأعضاء يتم ضبطهم عبر backfill/عمليات المديرين.
      if (!existingParticipants.contains(_currentUserId)) {
        await groupRef.update({
          'participants': [...existingParticipants, _currentUserId!],
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    }

    _isLoadingGroup = false;
    setState(() {});
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
      _markReadSubscription?.cancel();
      _markReadSubscription = null;
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
    _markReadSubscription?.cancel();
    _markReadSubscription = null;
    _messageSoundBoundChatId = chatId;
    ChatAudioFocus.registerMainLayoutChatOpen(chatId);
    _messageSoundSubscription = attachIncomingMessageSoundSubscription(
      stream: stream,
      chatId: chatId,
      currentUserId: uid,
    );
    unawaited(FirestoreServices.syncEmployeeActiveChatId(uid, chatId));
    _markReadSubscription = stream.listen((_) {
      unawaited(FirestoreServices.markIncomingMessagesReadInChat(chatId, uid));
    });
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
      return;
    }
    final id = _selectedChat!['id'] as String;
    if (_messagesStreamChatId == id && _messagesStream != null) return;
    if (_messagesStreamChatId != null && _messagesStreamChatId != id) {
      _flushScrollDiskTimer();
      _orderedChatMessageDocs = [];
      _scrollFabVisibleLast = null;
      _scrollUnreadBelowLast = -1;
    }
    _messagesStreamChatId = id;
    _messagesStream =
        _firestore
            .collection('chats')
            .doc(id)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .snapshots();
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

    final ids = built.map((c) => c['id'] as String).toList();
    final metas =
        await FirestoreServices.fetchLatestMessageMetaForChatIds(
          _firestore,
          ids,
        );
    if (!mounted || gen != _chatsEnrichGen) return;

    final merged = _mergeChatsWithPreviews(built, metas);

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
    if (!mounted || _chatsSubscription == null) return;
    _syncMessagesStreamWithSelection();
    setState(() {});
    _syncMessageSoundListener();
  }

  List<Map<String, dynamic>> _mergeChatsWithPreviews(
    List<Map<String, dynamic>> built,
    Map<String, ChatListLastMessageMeta?> metas,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final c in built) {
      final id = c['id'] as String;
      final isGroup = c['isGroup'] == true;
      final meta = metas[id];
      final docLm = (c['lastMessage'] ?? '').toString();

      final fromMeta = meta?.previewText;
      final preview =
          (fromMeta != null && fromMeta.trim().isNotEmpty)
              ? fromMeta.trim()
              : docLm.trim();

      if (!isGroup && preview.isEmpty) continue;

      if (fromMeta != null && fromMeta.trim().isNotEmpty) {
        unawaited(
          FirestoreServices.patchChatLastMessageIfStale(
            _firestore,
            id,
            fromMeta.trim(),
            docLm,
          ),
        );
      }

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
    _chatItemPositionsListener.itemPositions.removeListener(
      _onChatScrollPositions,
    );
    _imagePasteListener?.dispose();
    final sub = _chatsSubscription;
    _chatsSubscription =
        null; // أي callback قادم من الـ stream سيرى null ولن يستدعي setState
    sub?.cancel();
    _messageSoundSubscription?.cancel();
    _markReadSubscription?.cancel();
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
    _messageController.removeListener(_onComposerTextChanged);
    _messageController.dispose();
    _messageFocusNode.unfocus();
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

  bool _deptGroupTileVisibleForSearch() {
    final q = _chatListSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (_currentUserDept == null || _currentUserDept!.isEmpty) return false;
    final gid = 'group_$_currentUserDept';
    for (final c in _chats) {
      if (c['id'] == gid) return _chatMatchesListSearch(c);
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
    final openSnap = await ChatScrollPersistence.load(_currentUserId!, newChatId);
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
      _scrollFabVisibleLast = null;
      _scrollUnreadBelowLast = -1;
    });
    _syncMessageSoundListener();
  }

  // **إضافة لفتح مجموعة القسم**
  Future<void> _openDepartmentGroup() async {
    if (_currentUserId == null || _currentUserDept == null) return;
    final prevId = _selectedChat?['id'] as String?;
    if (prevId != null) {
      await _persistScrollSnapshotForChatId(_currentUserId!, prevId);
    }
    _flushScrollDiskTimer();
    final deptGroupName = _currentUserDept!;
    final groupId = 'group_$deptGroupName';
    final groupRef = _firestore.collection('chats').doc(groupId);

    final groupDoc = await groupRef.get();
    if (groupDoc.exists) {
      final chatData = groupDoc.data() ?? {};
      final gid = groupDoc.id;
      final openSnap = await ChatScrollPersistence.load(_currentUserId!, gid);
      _selectedChat = {
        'id': gid,
        'participants': List<String>.from(chatData['participants'] ?? []),
        'lastMessage': chatData['lastMessage'] ?? '',
        'isGroup': chatData['isGroup'] ?? false,
        'title': chatData['title'],
      };

      _syncMessagesStreamWithSelection();
      _otherUserId = null; // لا يوجد طرف آخر محدد في المجموعة
      setState(() {
        _scrollSnapshotCache.remove(gid);
        if (prevId != gid) {
          _chatMessageListEpoch++;
        }
        _persistedOpenScroll = openSnap;
        _persistedOpenScrollForChatId = gid;
        _scrollFabVisibleLast = null;
        _scrollUnreadBelowLast = -1;
      });
      _syncMessageSoundListener();
    }
  }

  // -----------// إرسال رسالة (نص أو مرفق)
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
    );

    if (!isGroup && otherId.isNotEmpty && otherId != 'N/A') {
      await FirestoreServices.sendFcm(
        userId: otherId,
        title: '$_currentUserName',
        body: lastMessagePreview,
        notificationType: 'chat_message',
        fcmDataExtras: {'chatId': chatId},
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
            fcmDataExtras: {'chatId': chatId},
          );
        }
      }
    }
  }

  Future<void> _markMessagesAsRead(String chatId) async {
    if (_currentUserId == null) return;
    await FirestoreServices.markIncomingMessagesReadInChat(
      chatId,
      _currentUserId!,
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocaleKeys.chatPasteImageFailed.tr)),
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
                  _filteredEmployees =
                      _employees
                          .where(
                            (e) => (e['name'] as String).toLowerCase().contains(
                              qlower,
                            ),
                          )
                          .toList();
                }
                setStateDialog(() {});
              }

              return Container(
                width: 420,
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocaleKeys.chatPickEmployee.tr,
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
                      child:
                          _loadingEmployees
                              ? Center(child: CircularProgressIndicator())
                              : _filteredEmployees.isEmpty
                              ? Center(
                                child: Text(AppLocaleKeys.chatNoEmployees.tr),
                              )
                              : ListView.builder(
                                itemCount: _filteredEmployees.length,
                                itemBuilder: (context, idx) {
                                  final emp = _filteredEmployees[idx];
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
                                },
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
        final visibleChats = _visibleChatsForSearch();
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
                                        color: Color(0xff00A389),
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

                        // **عرض مجموعة القسم أولاً**
                        if (_currentUserDept != null &&
                            _currentUserDept!.isNotEmpty &&
                            _deptGroupTileVisibleForSearch())
                          ListTile(
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.blueGrey.shade100,
                              child: Icon(Icons.group, color: Colors.blueGrey),
                            ),
                            title: Text(
                              '${AppLocaleKeys.chatDepartmentGroup.tr} ${_currentUserDept!.tr}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            subtitle: Builder(
                              builder: (context) {
                                final dept = _currentUserDept;
                                final fb =
                                    AppLocaleKeys.chatGroupConversation.tr;
                                if (dept == null || dept.isEmpty) {
                                  return Text(fb);
                                }
                                final gid = 'group_$dept';
                                for (final c in _chats) {
                                  if (c['id'] == gid) {
                                    return _chatListSubtitleWidget(c, fb);
                                  }
                                }
                                return Text(fb);
                              },
                            ),
                            tileColor:
                                _selectedChat != null &&
                                        _selectedChat!['id'] ==
                                            'group_$_currentUserDept'
                                    ? Colors.blue.shade50
                                    : null,
                            onTap: _openDepartmentGroup,
                          ),
                        if (_isLoadingGroup)
                          Center(
                            child: LinearProgressIndicator(),
                          ), // مؤشر تحميل المجموعة
                        // chats list
                        Expanded(
                          child:
                              _loadingChats
                                  ? Center(child: CircularProgressIndicator())
                                  : _chats.isEmpty
                                  ? Center(
                                    child: Text(AppLocaleKeys.chatNoChats.tr),
                                  )
                                  : visibleChats.isEmpty &&
                                      _chatListSearchQuery
                                          .trim()
                                          .isNotEmpty
                                  ? Center(
                                    child: Text(
                                      AppLocaleKeys.chatSearchNoMatches.tr,
                                    ),
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
                                      Color? titleColor;

                                      if (isGroup) {
                                        displayName =
                                            _localizedGroupTitleFromChat(ch);
                                        initial = _initialFromName(displayName);
                                        avatarColor = Colors.blueGrey.shade100;
                                        avatarIcon = Icons.group;
                                        titleColor = Colors.blue.shade700;

                                        // تخطي عرض مجموعة القسم مرة أخرى إذا تم عرضها بالفعل في الأعلى
                                        if (chatId == 'group_$_currentUserDept')
                                          return SizedBox.shrink();
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
                                        final other = _employees.firstWhere(
                                          (e) => e['id'] == otherId,
                                          orElse: () => {},
                                        );
                                        displayName =
                                            other.isNotEmpty
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
                                        titleColor = Colors.black;
                                      }

                                      return ListTile(
                                        tileColor:
                                            _selectedChat != null &&
                                                    _selectedChat!['id'] ==
                                                        chatId
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
                                          _scrollSnapshotCache.remove(nextChatId);
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

                                          await _markMessagesAsRead(nextChatId);
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
                                            _scrollFabVisibleLast = null;
                                            _scrollUnreadBelowLast = -1;
                                          });
                                          _syncMessageSoundListener();
                                        },
                                        leading: CircleAvatar(
                                          radius: 24,
                                          backgroundColor: avatarColor,
                                          child:
                                              avatarIcon != null
                                                  ? Icon(
                                                    avatarIcon,
                                                    color: Colors.black54,
                                                  )
                                                  : (employImage != null &&
                                                      employImage
                                                          .toString()
                                                          .trim()
                                                          .isNotEmpty)
                                                  ? ClipOval(
                                                    child: Image.network(
                                                      employImage.toString(),
                                                      width: 48,
                                                      height: 48,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, __, ___) => Text(
                                                            initial,
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          ),
                                                    ),
                                                  )
                                                  : Text(
                                                    initial,
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                        ),
                                        title: Text(
                                          displayName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: titleColor,
                                          ),
                                        ),
                                        subtitle: _chatListSubtitleWidget(
                                          ch,
                                          isGroup
                                              ? AppLocaleKeys
                                                  .chatGroupConversation
                                                  .tr
                                              : '',
                                        ),
                                        //counter
                                        trailing: StreamBuilder<int>(
                                          stream: _firestoreServices
                                              .unreadIncomingCountStream(
                                                chatId,
                                                _currentUserId ?? '',
                                              ),
                                          builder: (context, snap) {
                                            final count = snap.data ?? 0;
                                            if (count > 0) {
                                              return CircleAvatar(
                                                radius: 10,
                                                backgroundColor:
                                                    Colors.blue.shade100,
                                                child: Text(
                                                  count.toString(),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              );
                                            }
                                            return SizedBox.shrink();
                                          },
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
                    child:
                        _selectedChat == null
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Builder(
                                              builder: (context) {
                                                final isGroup =
                                                    _selectedChat!['isGroup'] ==
                                                    true;
                                                return chatLeadingAvatar(
                                                  radius: 28,
                                                  backgroundColor:
                                                      isGroup
                                                          ? Colors
                                                              .blueGrey
                                                              .shade100
                                                          : Colors
                                                              .grey
                                                              .shade200,
                                                  initial: _initialFromName(
                                                    _getSelectedChatNameSync(),
                                                  ),
                                                  groupIcon:
                                                      isGroup
                                                          ? Icons.group
                                                          : null,
                                                  imageUrl:
                                                      isGroup
                                                          ? null
                                                          : _getSelectedChatOtherImageUrlSync(),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _getSelectedChatNameSync(),
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _selectedChat!['isGroup'] == true
                                              ? AppLocaleKeys.chatGroupType.tr
                                              : AppLocaleKeys
                                                  .chatPrivateType
                                                  .tr,
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
                                      child:
                                          _messagesStream == null
                                              ? Center(
                                                child: Text(
                                                  AppLocaleKeys.chatNoMessages.tr,
                                                ),
                                              )
                                              : StreamBuilder<
                                                      QuerySnapshot<
                                                        Map<String, dynamic>
                                                      >
                                                    >(
                                                      stream: _messagesStream,
                                                      builder: (
                                                        context,
                                                        snapshot,
                                                      ) {
                                                        if (snapshot
                                                                .connectionState ==
                                                            ConnectionState
                                                                .waiting) {
                                                          return Center(
                                                            child:
                                                                CircularProgressIndicator(),
                                                          );
                                                        }
                                                        final docs =
                                                            snapshot
                                                                .data
                                                                ?.docs ??
                                                            [];
                                                        if (docs.isEmpty) {
                                                          return Center(
                                                            child: Text(
                                                              AppLocaleKeys
                                                                  .chatNoMessages
                                                                  .tr,
                                                            ),
                                                          );
                                                        }
                                                        _orderedChatMessageDocs =
                                                            docs;
                                                        final showScrollFab =
                                                            !chatReverseListShowsLatest(
                                                          positionsListener:
                                                              _chatItemPositionsListener,
                                                          itemCount: docs.length,
                                                        );
                                                        final unreadBelow =
                                                            chatReverseListUnreadIncomingBelowCount(
                                                          positionsListener:
                                                              _chatItemPositionsListener,
                                                          itemCount: docs.length,
                                                          docs: docs,
                                                          currentUserId:
                                                              _currentUserId!,
                                                        );
                                                        final selChatId =
                                                            _selectedChat!['id']
                                                                as String;
                                                        final mem =
                                                            _scrollSnapshotCache[
                                                                selChatId];
                                                        final disk =
                                                            _persistedOpenScrollForChatId ==
                                                                    selChatId
                                                                ? _persistedOpenScroll
                                                                : null;
                                                        final persistedForResolve =
                                                            mem ?? disk;
                                                        final openScroll =
                                                            resolveChatOpenScroll(
                                                          itemCount: docs.length,
                                                          currentUserId:
                                                              _currentUserId!,
                                                          docs: docs,
                                                          persisted:
                                                              persistedForResolve,
                                                          usePersisted:
                                                              persistedForResolve !=
                                                                  null,
                                                        );
                                                        return Stack(
                                                          clipBehavior:
                                                              Clip.none,
                                                          alignment: Alignment
                                                              .bottomRight,
                                                          children: [
                                                            Positioned.fill(
                                                              child: ScrollablePositionedList
                                                                  .builder(
                                                                key: ValueKey(
                                                                  '${selChatId}_$_chatMessageListEpoch',
                                                                ),
                                                                itemScrollController:
                                                                    _chatMessageItemScrollController,
                                                                itemPositionsListener:
                                                                    _chatItemPositionsListener,
                                                                initialScrollIndex:
                                                                    openScroll.index,
                                                                initialAlignment:
                                                                    openScroll.alignment,
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                  16,
                                                                ),
                                                                itemCount:
                                                                    docs.length,
                                                                reverse: true,
                                                                itemBuilder: (
                                                                  context,
                                                                  i,
                                                                ) {
                                                                  final d =
                                                                      docs[i]
                                                                          .data();
                                                                  final mid =
                                                                      docs[i].id;
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

                                                                  return Padding(
                                                                    key:
                                                                        ValueKey(
                                                                          mid,
                                                                        ),
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                    child: ChatMessageTile(
                                                                      chatId:
                                                                          _selectedChat!['id']
                                                                              as String,
                                                                      messageId:
                                                                          mid,
                                                                      message: Map<
                                                                        String,
                                                                        dynamic
                                                                      >.from(
                                                                        d,
                                                                      ),
                                                                      isMe:
                                                                          isMe,
                                                                      isGroup:
                                                                          _selectedChat!['isGroup'] ==
                                                                          true,
                                                                      senderName:
                                                                          senderName,
                                                                      showGroupSenderName:
                                                                          !isMe &&
                                                                          (_selectedChat?['isGroup'] ??
                                                                              false),
                                                                      timestamp:
                                                                          ts,
                                                                      formatTime:
                                                                          _formatTimestamp,
                                                                      isAdmin:
                                                                          _currentUserRole ==
                                                                          'admin',
                                                                      currentUserId:
                                                                          _currentUserId!,
                                                                      currentUserDisplayName:
                                                                          _currentUserName,
                                                                      onReply:
                                                                          (
                                                                            draft,
                                                                          ) => setState(
                                                                            () => _replyDraft =
                                                                                draft,
                                                                          ),
                                                                      onReplyPreviewTap:
                                                                          _scrollToRepliedMessage,
                                                                      bubbleDecoration: BoxDecoration(
                                                                        color: isMe
                                                                            ? const Color(
                                                                                0xff465FFF,
                                                                              )
                                                                            : Colors
                                                                                .grey
                                                                                .shade100,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                          12,
                                                                        ),
                                                                      ),
                                                                      maxWidthFactor:
                                                                          0.6,
                                                                      alignment: isMe
                                                                          ? Alignment
                                                                              .centerRight
                                                                          : Alignment
                                                                              .centerLeft,
                                                                      columnCrossAxis: isMe
                                                                          ? CrossAxisAlignment
                                                                              .end
                                                                          : CrossAxisAlignment
                                                                              .start,
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                            Positioned(
                                                              right: 6,
                                                              bottom: 10,
                                                              child: ChatScrollToLatestFab(
                                                                visible:
                                                                    showScrollFab,
                                                                badgeCount:
                                                                    unreadBelow,
                                                                onPressed: () =>
                                                                    scheduleScrollChatToLatest(
                                                                  controller:
                                                                      _chatMessageItemScrollController,
                                                                  mounted: () =>
                                                                      mounted,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                    ),
                                  ),

                                          // input text and send button
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                const ChatUploadProgressBanner(),
                                                if (_replyDraft != null)
                                                  ChatReplyDraftBanner(
                                                    draft: _replyDraft!,
                                                    onCancel:
                                                        () => setState(
                                                          () =>
                                                              _replyDraft =
                                                                  null,
                                                        ),
                                                  ),
                                                if (_pendingAttachment != null)
                                                  PendingAttachmentStrip(
                                                    pending:
                                                        _pendingAttachment!,
                                                    onCancel:
                                                        () => setState(
                                                          () =>
                                                              _pendingAttachment =
                                                                  null,
                                                        ),
                                                    onTapPreview:
                                                        (_pendingAttachment!
                                                                        .messageType ==
                                                                    'image' ||
                                                                _pendingAttachment!
                                                                        .messageType ==
                                                                    'video')
                                                            ? () =>
                                                                openChatMediaFromUrl(
                                                                  _pendingAttachment!
                                                                      .attachmentUrl,
                                                                )
                                                            : null,
                                                  ),
                                                Obx(() {
                                                  final busy =
                                                      controller
                                                          .isUploading
                                                          .value;
                                                  return Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(
                                                          Icons
                                                              .sentiment_satisfied_alt_outlined,
                                                        ),
                                                        onPressed:
                                                            busy
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
                                                      IconButton(
                                                        tooltip:
                                                            AppLocaleKeys
                                                                .chatAttachGallery
                                                                .tr,
                                                        icon: const Icon(
                                                          Icons
                                                              .perm_media_outlined,
                                                        ),
                                                        onPressed:
                                                            busy
                                                                ? null
                                                                : () async {
                                                                  final v =
                                                                      await controller
                                                                          .pickOneChatGalleryMedia();
                                                                  if (v.isEmpty ||
                                                                      v.first.bytes ==
                                                                          null) {
                                                                    return;
                                                                  }
                                                                  final picked =
                                                                      v.first;
                                                                  final url = await controller.uploadFiles(
                                                                    filePathOrBytes:
                                                                        picked
                                                                            .bytes!,
                                                                    fileName:
                                                                        picked
                                                                            .name,
                                                                    useBlockingUploadDialog:
                                                                        false,
                                                                  );
                                                                  if (url ==
                                                                      null) {
                                                                    return;
                                                                  }
                                                                  final isVid =
                                                                      chatAttachmentIsVideo(
                                                                        picked
                                                                            .name,
                                                                      );
                                                                  setState(
                                                                    () =>
                                                                        _pendingAttachment =
                                                                            PendingChatAttachment(
                                                                              messageType:
                                                                                  isVid
                                                                                      ? 'video'
                                                                                      : 'image',
                                                                              attachmentUrl:
                                                                                  url,
                                                                              fileName:
                                                                                  isVid
                                                                                      ? picked.name
                                                                                      : null,
                                                                            ),
                                                                  );
                                                                  controller
                                                                      .uploadedFilesPaths
                                                                      .clear();
                                                                },
                                                      ),
                                                      IconButton(
                                                        tooltip:
                                                            AppLocaleKeys
                                                                .chatAttachFile
                                                                .tr,
                                                        icon: const Icon(
                                                          Icons.attach_file,
                                                        ),
                                                        onPressed:
                                                            busy
                                                                ? null
                                                                : () async {
                                                                  final v =
                                                                      await controller
                                                                          .pickOneChatFile();
                                                                  if (v.isEmpty ||
                                                                      v.first.bytes ==
                                                                          null) {
                                                                    return;
                                                                  }
                                                                  final url = await controller.uploadFiles(
                                                                    filePathOrBytes:
                                                                        v
                                                                            .first
                                                                            .bytes!,
                                                                    fileName:
                                                                        v
                                                                            .first
                                                                            .name,
                                                                    useBlockingUploadDialog:
                                                                        false,
                                                                  );
                                                                  if (url ==
                                                                      null) {
                                                                    return;
                                                                  }
                                                                  setState(
                                                                    () =>
                                                                        _pendingAttachment =
                                                                            PendingChatAttachment(
                                                                              messageType:
                                                                                  'file',
                                                                              attachmentUrl:
                                                                                  url,
                                                                              fileName:
                                                                                  v
                                                                                      .first
                                                                                      .name,
                                                                            ),
                                                                  );
                                                                  controller
                                                                      .uploadedFilesPaths
                                                                      .clear();
                                                                },
                                                      ),
                                                      IconButton(
                                                        tooltip:
                                                            AppLocaleKeys
                                                                .chatPasteImage
                                                                .tr,
                                                        icon: const Icon(
                                                          Icons.content_paste,
                                                        ),
                                                        onPressed:
                                                            busy
                                                                ? null
                                                                : _pasteImageFromClipboard,
                                                      ),
                                                      ChatVoiceRecordButton(
                                                        onUploaded: (
                                                          url,
                                                          sec,
                                                        ) async {
                                                          setState(
                                                            () =>
                                                                _pendingAttachment =
                                                                    PendingChatAttachment(
                                                                      messageType:
                                                                          'voice',
                                                                      attachmentUrl:
                                                                          url,
                                                                      durationSec:
                                                                          sec > 0
                                                                              ? sec
                                                                              : null,
                                                                    ),
                                                          );
                                                          controller
                                                              .uploadedFilesPaths
                                                              .clear();
                                                        },
                                                      ),
                                                      Expanded(
                                                        child: Focus(
                                                          onKeyEvent:
                                                              _onComposerKeyEvent,
                                                          child: TextField(
                                                            controller:
                                                                _messageController,
                                                            focusNode:
                                                                _messageFocusNode,
                                                            contentInsertionConfiguration:
                                                                _enableContentInsertion
                                                                    ? ContentInsertionConfiguration(
                                                                      allowedMimeTypes: const <
                                                                        String
                                                                      >[
                                                                        'image/png',
                                                                        'image/jpeg',
                                                                        'image/webp',
                                                                        'image/gif',
                                                                      ],
                                                                      onContentInserted: (
                                                                        KeyboardInsertedContent
                                                                        content,
                                                                      ) {
                                                                        final data =
                                                                            content.data;
                                                                        if (data ==
                                                                                null ||
                                                                            data.isEmpty) {
                                                                          _showPasteImageFailed();
                                                                          return;
                                                                        }
                                                                        unawaited(
                                                                          _handlePastedImage(
                                                                            data,
                                                                            content.mimeType,
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
                                                              hintText:
                                                                  AppLocaleKeys
                                                                      .chatWriteMessage
                                                                      .tr,
                                                              filled: true,
                                                              fillColor:
                                                                  Colors
                                                                      .grey
                                                                      .shade100,
                                                              border: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                borderSide:
                                                                    BorderSide
                                                                        .none,
                                                              ),
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        16,
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
                                                      const SizedBox(width: 8),
                                                      MouseRegion(
                                                        cursor:
                                                            SystemMouseCursors
                                                                .click,
                                                        child: GestureDetector(
                                                          onTap:
                                                              busy
                                                                  ? null
                                                                  : _sendMessage,
                                                          child: Container(
                                                            width: 45,
                                                            height: 45,
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Color(
                                                                    0xff465FFF,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        15,
                                                                      ),
                                                                ),
                                                            child: Icon(
                                                              Icons.send,
                                                              color:
                                                                  Colors.white,
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

                                          // Emoji Picker
                                          Offstage(
                                            offstage: !_isEmojiVisible,
                                            child: SizedBox(
                                              height: 250,
                                              child: EmojiPicker(
                                                onEmojiSelected: (
                                                  category,
                                                  emoji,
                                                ) {
                                                  _messageController.text +=
                                                      emoji.emoji;
                                                },
                                                //   config: const Config(
                                                //     columns: 7,
                                                //     emojiSizeMax: 32.0,
                                                //     verticalSpacing: 0,
                                                //     horizontalSpacing: 0,
                                                //     gridPadding: EdgeInsets.zero,
                                                //     initCategory: Category.RECENT,
                                                //     bgColor: Color(0xFFF2F2F2),
                                                //     indicatorColor: Colors.blue,
                                                //     iconColor: Colors.grey,
                                                //     iconColorSelected: Colors.blue,
                                                //     backspaceColor: Colors.blue,
                                                //     skinToneDialogBgColor: Colors.white,
                                                //     skinToneIndicatorColor: Colors.grey,
                                                //     enableSkinTones: true,
                                                //     showRecentsTab: true,
                                                //     recentsLimit: 28,
                                                //     noRecents: Text(
                                                //       'لا توجد رموز حديثة',
                                                //       textAlign: TextAlign.center,
                                                //     ),
                                                //     // textDirection: TextDirection.rtl,
                                                //     tabIndicatorAnimDuration: kTabScrollDuration,
                                                //     categoryIcons: CategoryIcons(),
                                                //     buttonMode: ButtonMode.MATERIAL,
                                                //   ),
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
