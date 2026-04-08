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
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/ChatIncomingMessageSound.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/chat_clipboard_image_reader.dart';
import 'package:point/Services/chat_image_paste_listener.dart';
import 'package:point/View/Chats/chat_message_display.dart';
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

class _ChatScreenState extends State<ChatScreen> {
  // -------- controllers / state -------
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  ChatImagePasteListener? _imagePasteListener;
  bool _isEmojiVisible = false;
  String? _pendingPastedImageUrl;
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
  Map<String, dynamic>? _selectedChat; // selected chat doc (id + data)

  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;

  /// يمنع إعادة إنشاء اشتراك الرسائل لنفس المحادثة عند كل snapshot.
  String? _messagesStreamChatId;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messageSoundSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _markReadSubscription;

  /// يمنع تطبيق دمج معاينات قديم بعد snapshot أحدث.
  int _chatsEnrichGen = 0;

  /// يمنع إلغاء اشتراك الصوت عند كل تحديث لقائمة المحادثات (كان يُرمى أول snapshot فيه الرسائل الجديدة).
  String? _messageSoundBoundChatId;

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
    _initUserThenLoad();
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
      _messageSoundBoundChatId = null;
      _markReadSubscription?.cancel();
      _markReadSubscription = null;
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
    _messageSoundSubscription?.cancel();
    _messageSoundSubscription = null;
    _markReadSubscription?.cancel();
    _markReadSubscription = null;
    _messageSoundBoundChatId = chatId;
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
      _messagesStreamChatId = null;
      return;
    }
    final id = _selectedChat!['id'] as String;
    if (_messagesStreamChatId == id && _messagesStream != null) return;
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
        _selectedChat = null;
      }
      if (!mounted || _chatsSubscription == null) return;
      _syncMessagesStreamWithSelection();
      setState(() {});
      _syncMessageSoundListener();
      return;
    }

    final ids = built.map((c) => c['id'] as String).toList();
    final previews =
        await FirestoreServices.fetchLatestMessagePreviewsForChatIds(
          _firestore,
          ids,
        );
    if (!mounted || gen != _chatsEnrichGen) return;

    final merged = _mergeChatsWithPreviews(built, previews);

    if (_selectedChat != null &&
        !merged.any((c) => c['id'] == _selectedChat!['id'])) {
      _selectedChat = null;
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
    Map<String, String?> previews,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final c in built) {
      final id = c['id'] as String;
      final isGroup = c['isGroup'] == true;
      final fromSub = previews[id];
      final docLm = (c['lastMessage'] ?? '').toString();

      if (!isGroup) {
        final preview =
            (fromSub != null && fromSub.trim().isNotEmpty)
                ? fromSub.trim()
                : docLm.trim();
        if (preview.isEmpty) continue;
        if (fromSub != null && fromSub.trim().isNotEmpty) {
          unawaited(
            FirestoreServices.patchChatLastMessageIfStale(
              _firestore,
              id,
              fromSub.trim(),
              docLm,
            ),
          );
        }
        out.add(Map<String, dynamic>.from(c)..['lastMessage'] = preview);
      } else {
        final display =
            (fromSub != null && fromSub.trim().isNotEmpty)
                ? fromSub.trim()
                : docLm.trim();
        if (fromSub != null && fromSub.trim().isNotEmpty) {
          unawaited(
            FirestoreServices.patchChatLastMessageIfStale(
              _firestore,
              id,
              fromSub.trim(),
              docLm,
            ),
          );
        }
        out.add(Map<String, dynamic>.from(c)..['lastMessage'] = display);
      }
    }
    return out;
  }

  @override
  void dispose() {
    _imagePasteListener?.dispose();
    final sub = _chatsSubscription;
    _chatsSubscription =
        null; // أي callback قادم من الـ stream سيرى null ولن يستدعي setState
    sub?.cancel();
    _messageSoundSubscription?.cancel();
    _markReadSubscription?.cancel();
    _messageSoundBoundChatId = null;
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
    _selectedChat = {
      'id': chatDoc.id,
      'participants': List<String>.from(chatData['participants'] ?? []),
      'lastMessage': chatData['lastMessage'] ?? '',
      'isGroup': chatData['isGroup'] ?? false,
    };
    Get.find<HomeController>().selectedChat = {
      'id': chatDoc.id,
      'participants': List<String>.from(chatData['participants'] ?? []),
      'lastMessage': chatData['lastMessage'] ?? '',
      'isGroup': chatData['isGroup'] ?? false,
    };

    _syncMessagesStreamWithSelection();

    setState(() {});
    _syncMessageSoundListener();
  }

  // **إضافة لفتح مجموعة القسم**
  Future<void> _openDepartmentGroup() async {
    if (_currentUserId == null || _currentUserDept == null) return;
    final deptGroupName = _currentUserDept!;
    final groupId = 'group_$deptGroupName';
    final groupRef = _firestore.collection('chats').doc(groupId);

    final groupDoc = await groupRef.get();
    if (groupDoc.exists) {
      final chatData = groupDoc.data() ?? {};
      _selectedChat = {
        'id': groupDoc.id,
        'participants': List<String>.from(chatData['participants'] ?? []),
        'lastMessage': chatData['lastMessage'] ?? '',
        'isGroup': chatData['isGroup'] ?? false,
        'title': chatData['title'],
      };

      _syncMessagesStreamWithSelection();
      _otherUserId = null; // لا يوجد طرف آخر محدد في المجموعة
      setState(() {});
      _syncMessageSoundListener();
    }
  }

  // -----------// إرسال رسالة (نص أو مرفق)
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final pendingImageUrl = _pendingPastedImageUrl;
    if (text.isEmpty && pendingImageUrl == null) return;
    _messageController.clear();
    if (!kIsWeb) {
      _messageFocusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _messageFocusNode.canRequestFocus) {
          _messageFocusNode.requestFocus();
        }
      });
    }
    if (pendingImageUrl != null) {
      setState(() => _pendingPastedImageUrl = null);
      await _sendChatPayload(
        lastMessagePreview: text.isNotEmpty ? text : '📷',
        messageType: 'image',
        text: text,
        attachmentUrl: pendingImageUrl,
      );
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
      'text': text.isNotEmpty ? text : lastMessagePreview,
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

    await msgRef.set(payload);

    await chatRef.update({
      'lastMessage': lastMessagePreview,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

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
    setState(() => _pendingPastedImageUrl = url);
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

  /// آخر رسالة لمجموعة القسم في القائمة (يُملأ من `_chats` بعد الدمج مع `messages`).
  String _subtitleForDepartmentGroupChat() {
    final dept = _currentUserDept;
    if (dept == null || dept.isEmpty) {
      return AppLocaleKeys.chatGroupConversation.tr;
    }
    final gid = 'group_$dept';
    for (final c in _chats) {
      if (c['id'] == gid) {
        final lm = (c['lastMessage'] ?? '').toString().trim();
        return lm.isNotEmpty ? lm : AppLocaleKeys.chatGroupConversation.tr;
      }
    }
    return AppLocaleKeys.chatGroupConversation.tr;
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
        return Scaffold(
          // key: widget.key,
          appBar: PreferredSize(
            preferredSize: Size(Get.width, Get.height),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.black),
                  onPressed: () {
                    // **استدعاء دالة التصغير الممررة**
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
                                      // filter chats by other user's name: do local filter using loaded employees
                                      // simple approach: filter by name substring
                                      setState(() {
                                        // نعتمد على الـ snapshot listener، ولكن يمكن إضافة فلترة محلية للمحادثات
                                        // بناءً على اسم الطرف الآخر (إذا كان متاحاً في كاش الـ _chats)
                                        // لتبسيط الأمر وتجنب تكرار الكود: نكتفي بترك الأمر للـ snapshot listener الحالي
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
                            _currentUserDept!.isNotEmpty)
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
                            subtitle: Text(
                              _subtitleForDepartmentGroupChat(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                                  : ListView.builder(
                                    itemCount: _chats.length,
                                    itemBuilder: (context, index) {
                                      final ch = _chats[index];
                                      final isGroup = ch['isGroup'] ?? false;
                                      final chatId = ch['id'] as String;

                                      String displayName;
                                      String? subtitle;
                                      String initial;
                                      String? employImage;
                                      Color avatarColor;
                                      IconData? avatarIcon;
                                      Color? titleColor;

                                      if (isGroup) {
                                        displayName =
                                            _localizedGroupTitleFromChat(ch);
                                        final lm =
                                            (ch['lastMessage'] ?? '')
                                                .toString()
                                                .trim();
                                        subtitle =
                                            lm.isNotEmpty
                                                ? lm
                                                : AppLocaleKeys
                                                    .chatGroupConversation
                                                    .tr;
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
                                        subtitle = ch['lastMessage'] ?? '';
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

                                          await _markMessagesAsRead(ch['id']);
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
                                          setState(() {});
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
                                        subtitle: SizedBox(
                                          width: 100,
                                          child: Text(
                                            subtitle ?? '',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(),
                                          ),
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
                            : SingleChildScrollView(
                              child: Column(
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
                                  // messages area (stream)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    margin: EdgeInsets.symmetric(horizontal: 5),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          Container(
                                            height: Get.height * 0.4,
                                            child:
                                                _messagesStream == null
                                                    ? Center(
                                                      child: Text(
                                                        AppLocaleKeys
                                                            .chatNoMessages
                                                            .tr,
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
                                                        return ListView.builder(
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
                                                                docs[i].data();
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

                                                            return Align(
                                                              alignment:
                                                                  isMe
                                                                      ? Alignment
                                                                          .centerRight
                                                                      : Alignment
                                                                          .centerLeft,
                                                              child: Container(
                                                                constraints: BoxConstraints(
                                                                  maxWidth:
                                                                      MediaQuery.of(
                                                                        context,
                                                                      ).size.width *
                                                                      0.6,
                                                                ),
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      12,
                                                                    ),
                                                                margin:
                                                                    const EdgeInsets.symmetric(
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      isMe
                                                                          ? Color(
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
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    // **عرض اسم المرسل في المجموعات فقط**
                                                                    if (!isMe &&
                                                                        (_selectedChat?['isGroup'] ??
                                                                            false))
                                                                      Padding(
                                                                        padding: const EdgeInsets.only(
                                                                          bottom:
                                                                              4.0,
                                                                        ),
                                                                        child: Text(
                                                                          senderName,
                                                                          style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize:
                                                                                10,
                                                                            color:
                                                                                Colors.blue.shade700,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    chatMessageBubbleContent(
                                                                      Map<
                                                                        String,
                                                                        dynamic
                                                                      >.from(d),
                                                                      isMe,
                                                                    ),
                                                                    // Text(
                                                                    //   d['text'] ??
                                                                    //       '',
                                                                    //   style: TextStyle(
                                                                    //     color:
                                                                    //         isMe
                                                                    //             ? Colors.white
                                                                    //             : Colors.black,
                                                                    //   ),
                                                                    // ),
                                                                    SizedBox(
                                                                      height: 6,
                                                                    ),
                                                                    Text(
                                                                      _formatTimestamp(
                                                                        ts,
                                                                      ),
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color:
                                                                            isMe
                                                                                ? Colors.white70
                                                                                : Colors.black54,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      },
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
                                                if (_pendingPastedImageUrl !=
                                                    null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          8,
                                                          0,
                                                          8,
                                                          6,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          child: InkWell(
                                                            onTap:
                                                                () => openChatMediaFromUrl(
                                                                  _pendingPastedImageUrl!,
                                                                ),
                                                            child: Image.network(
                                                              _pendingPastedImageUrl!,
                                                              width: 34,
                                                              height: 34,
                                                              fit: BoxFit.cover,
                                                              errorBuilder:
                                                                  (
                                                                    _,
                                                                    __,
                                                                    ___,
                                                                  ) => const Icon(
                                                                    Icons
                                                                        .image_outlined,
                                                                    size: 18,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            AppLocaleKeys
                                                                .chatPasteImage
                                                                .tr,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          tooltip:
                                                              AppLocaleKeys
                                                                  .commonCancel
                                                                  .tr,
                                                          icon: const Icon(
                                                            Icons.close,
                                                            size: 18,
                                                          ),
                                                          onPressed:
                                                              () => setState(
                                                                () =>
                                                                    _pendingPastedImageUrl =
                                                                        null,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
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
                                                                  final cap =
                                                                      _messageController
                                                                          .text
                                                                          .trim();
                                                                  final isVid =
                                                                      chatAttachmentIsVideo(
                                                                        picked
                                                                            .name,
                                                                      );
                                                                  await _sendChatPayload(
                                                                    lastMessagePreview:
                                                                        cap.isNotEmpty
                                                                            ? cap
                                                                            : (isVid
                                                                                ? '🎬'
                                                                                : '📷'),
                                                                    messageType:
                                                                        isVid
                                                                            ? 'video'
                                                                            : 'image',
                                                                    text: cap,
                                                                    attachmentUrl:
                                                                        url,
                                                                    fileName:
                                                                        isVid
                                                                            ? picked.name
                                                                            : null,
                                                                  );
                                                                  _messageController
                                                                      .clear();
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
                                                                  await _sendChatPayload(
                                                                    lastMessagePreview:
                                                                        v
                                                                            .first
                                                                            .name,
                                                                    messageType:
                                                                        'file',
                                                                    text: '',
                                                                    attachmentUrl:
                                                                        url,
                                                                    fileName:
                                                                        v
                                                                            .first
                                                                            .name,
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
                                                          await _sendChatPayload(
                                                            lastMessagePreview:
                                                                '🎤',
                                                            messageType:
                                                                'voice',
                                                            text: url,
                                                            attachmentUrl: url,
                                                            durationSec:
                                                                sec > 0
                                                                    ? sec
                                                                    : null,
                                                          );
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
