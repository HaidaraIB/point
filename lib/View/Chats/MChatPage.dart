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
// يجب أن يكون هذا الملف متاحًا لديك، وإلا سيعطي خطأ
import 'package:point/Services/AudioService.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/ChatIncomingMessageSound.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/firestore/firestore_chat_api.dart';
import 'package:point/Services/firestore/firestore_query_limits.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/chat_clipboard_image_reader.dart';
import 'package:point/Services/chat_list_pins_persistence.dart';
import 'package:point/Services/chat_scroll_persistence.dart';
import 'package:point/Services/chat_image_paste_listener.dart';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Routing/app_route_observer.dart';
import 'package:point/Services/FcmServices.dart' as fcm_notifications;
import 'package:point/View/Chats/chat_message_tile.dart';
import 'package:point/View/Chats/chat_media_gallery.dart';
import 'package:point/View/Chats/chat_pinned_messages_bar.dart';
import 'package:point/View/Chats/chat_message_list_panel.dart';
import 'package:point/View/Chats/pending_chat_attachment.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';
import 'package:point/View/Chats/chat_list_tile_media_subtitle.dart';
import 'package:point/View/Chats/chat_reply_draft_banner.dart';
import 'package:point/View/Chats/chat_list_row_trailing.dart';
import 'package:point/View/Chats/chat_list_folder_utils.dart';
import 'package:point/View/Chats/chat_private_typing.dart';
import 'package:point/View/Chats/chat_voice_record_button.dart';
import 'package:point/View/Chats/telegram_style_attachment_menu.dart';
import 'package:point/Utils/chat_attachment_upload.dart';

// **********************************************
// ********* الشاشة الجديدة 1: قائمة المحادثات *********
// **********************************************

class ChatsListScreen extends StatefulWidget {
  // نحافظ على المتغيرات التي كانت موجودة في الشاشة الأصلية
  final VoidCallback onMinimize;
  final bool isFloatingPopUp;

  const ChatsListScreen({
    super.key,
    required this.onMinimize,
    this.isFloatingPopUp = false,
  });

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  // -------- controllers / state -------
  final TextEditingController _searchController = TextEditingController();
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreServices _firestoreServices = FirestoreServices();

  // local caches
  String? _currentUserId;
  String? _currentUserName;
  List<String> _currentUserDepts = [];
  String? _currentUserRole;

  List<Map<String, dynamic>> _employees = []; // all employees
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<Map<String, dynamic>> _groupParticipants = [];

  List<Map<String, dynamic>> _chats = []; // chats list for current user
  String _chatListSearchQuery = '';
  ChatListFolder _chatListFolder = ChatListFolder.all;
  List<String> _pinnedChatIds = [];

  bool _loadingEmployees = true;
  bool _loadingChats = true;
  bool _isLoadingGroup = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatsListSub;
  int _chatsEnrichGen = 0;
  final Set<String> _legacyPreviewFetched = {};
  Worker? _presenceWorker;

  DateTime? _presenceOf(String? employeeId) {
    final id = employeeId?.trim() ?? '';
    if (id.isEmpty || !Get.isRegistered<HomeController>()) return null;
    return Get.find<HomeController>().employeeLastSeenAt(id);
  }

  bool _isOnlinePresence(DateTime? at) {
    if (at == null) return false;
    return DateTime.now().difference(at.toLocal()) <= const Duration(minutes: 2);
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

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<HomeController>()) {
      final hc = Get.find<HomeController>();
      _presenceWorker = ever<Map<String, DateTime>>(hc.employeePresenceById, (_) {
        if (!mounted) return;
        setState(() {});
      });
    }
    _initUserThenLoad();
  }

  @override
  void dispose() {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().selectedChat = null;
    }
    _chatsListSub?.cancel();
    _presenceWorker?.dispose();
    _presenceWorker = null;
    _searchController.dispose();
    super.dispose();
  }

  // يتم استدعاؤها عند تغيير الشاشة إلى وضع الـ Full Screen
  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _listenChats(); // إعادة الاستماع في حالة الحاجة إلى تحديث
  // }

  Future<void> _initUserThenLoad() async {
    final homecontroller = Get.find<HomeController>();
    if (homecontroller.currentEmployee.value != null) {
      _currentUserId = homecontroller.currentEmployee.value?.id;
      _currentUserName =
          homecontroller.currentEmployee.value?.name ??
          homecontroller.currentEmployee.value?.email ??
          AppLocaleKeys.me.tr;
      _currentUserRole = homecontroller.currentEmployee.value?.role;
      _currentUserDepts = StorageKeys.normalizeDepartments(
        homecontroller.currentEmployee.value?.departments ?? const [],
      );
    } else {
      _currentUserId = 'temp_current_user';
      _currentUserName = AppLocaleKeys.me.tr;
      _currentUserDepts = [];
      _currentUserRole = null;
    }

    await _loadEmployees();
    await _createOrLoadDepartmentGroup();
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

  List<Map<String, dynamic>> _visibleChatsOrderedForList() {
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
    if (mounted) setState(() {});
    final snapshot = await _firestore.collection('employees').get();
    final all = snapshot.docs
        .where((d) => d.id != _currentUserId)
        // exclude current user from 1:1 chat list
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
            'role': data['role'] ?? '',
          };
        })
        .toList();

    // For employee role: allow chat target only when it is either:
    // - elevated role (admin/supervisor)
    // - same department as current user
    // This is a UX constraint; final enforcement is done in Firestore rules.
    if (_currentUserRole == 'employee') {
      final myDepts = _currentUserDepts;
      _employees = all.where((e) {
        final targetRole = e['role'];
        final targetDepts = List<String>.from(e['departments'] as List? ?? []);
        final isSpecialRole = StorageKeys.isChatElevatedRole(targetRole);
        final overlap = StorageKeys.departmentListsOverlap(
          myDepts,
          targetDepts,
        );
        return isSpecialRole || overlap;
      }).toList();
    } else {
      _employees = all;
    }

    _filteredEmployees = List.from(_employees);
    _loadingEmployees = false;
    if (mounted) setState(() {});
  }

  void _filterEmployees(String q) {
    final qlower = q.trim().toLowerCase();
    if (qlower.isEmpty) {
      _filteredEmployees = List.from(_employees);
      if (mounted) setState(() {});
    } else {
      _filteredEmployees = _employees
          .where((e) => (e['name'] as String).toLowerCase().contains(qlower))
          .toList();
    }
    if (mounted) setState(() {});
  }

  // ---------------- Department Group Logic ----------------
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

  Future<Map<String, dynamic>?> _ensureJoinedDepartmentGroup(
    String rawSlug,
  ) async {
    if (_currentUserId == null || _currentUserId == 'temp_current_user') {
      return null;
    }
    final slug = StorageKeys.normalizeDepartment(rawSlug);
    if (slug.isEmpty) return null;
    final chatId = 'group_$slug';
    final ref = _firestore.collection('chats').doc(chatId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
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
        await ref.update({
          'participants': [...participants, _currentUserId!],
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    }
    final joinedSnap = await ref.get();
    final data = joinedSnap.data() ?? {};
    return {
      'id': joinedSnap.id,
      'participants': List<String>.from(data['participants'] ?? const []),
      'lastMessage': data['lastMessage'] ?? '',
      'lastUpdated': data['lastUpdated'],
      'isGroup': data['isGroup'] ?? true,
      'title': data['title'] ?? slug,
    };
  }

  Future<void> _createOrLoadDepartmentGroup() async {
    if (_currentUserId == null || _currentUserId == 'temp_current_user') {
      return;
    }
    final slugs = _sidebarDepartmentSlugsForChat();
    if (slugs.isEmpty) return;

    _isLoadingGroup = true;
    if (mounted) setState(() {});

    for (final deptGroupName in slugs) {
      await _syncSingleDepartmentGroup(deptGroupName);
    }

    _isLoadingGroup = false;
    if (mounted) setState(() {});
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

  // ---------------- Chats (Private & Group) ----------------
  void _listenChats() {
    if (_currentUserId == null) return;

    _chatsListSub?.cancel();
    _chatsListSub = _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .listen(
          (snap) {
            final built = <Map<String, dynamic>>[];
            for (var doc in snap.docs) {
              final data = doc.data();
              final chat = {
                'id': doc.id,
                'participants': List<String>.from(data['participants'] ?? []),
                'lastMessage': data['lastMessage'] ?? '',
                'lastUpdated': data['lastUpdated'],
                'isGroup': data['isGroup'] ?? false,
                'title': data['title'],
                'lastMessageMeta': data['lastMessageMeta'],
              };
              built.add(chat);
            }

            _chatsEnrichGen++;
            final gen = _chatsEnrichGen;
            if (!mounted) return;
            unawaited(_applySnapshotAndEnrich(gen, built));
          },
          onError: (Object e, StackTrace st) {
            if (e is FirebaseException &&
                e.code == 'permission-denied' &&
                FirebaseAuth.instance.currentUser == null) {
              final sub = _chatsListSub;
              _chatsListSub = null;
              sub?.cancel();
              return;
            }
            appLog('⚠️ MChatPage _listenChats: $e');
            if (!mounted) return;
            setState(() {
              _loadingChats = false;
            });
          },
          cancelOnError: false,
        );
  }

  Future<void> _applySnapshotAndEnrich(
    int gen,
    List<Map<String, dynamic>> built,
  ) async {
    if (built.isEmpty) {
      if (!mounted || gen != _chatsEnrichGen) return;
      _chats = [];
      _loadingChats = false;
      if (mounted) setState(() {});
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

    _chats = _mergeChatsWithPreviews(built);
    _loadingChats = false;
    if (mounted) setState(() {});
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

  // ---------------- Navigation ----------------
  // لفتح محادثة فردية أو إنشاءها والانتقال لشاشة الرسائل
  Future<void> _openOrCreateChatWith(Map<String, dynamic> otherEmployee) async {
    if (_currentUserId == null) return;
    final otherUserId = otherEmployee['id'] as String;

    final ids = [_currentUserId!, otherUserId]..sort();
    final chatId = ids.join('_');

    final chatRef = _firestore.collection('chats').doc(chatId);

    try {
      await chatRef.set({
        'participants': ids,
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
        'isGroup': false,
      }, SetOptions(merge: true));
    } catch (e) {
      if (!e.toString().contains('permission-denied')) rethrow;
      await chatRef.update({
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    // جلب بيانات المحادثة المفتوحة أو المنشأة
    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data() ?? {};
    final selectedChatData = {
      'id': chatDoc.id,
      'participants': List<String>.from(chatData['participants'] ?? []),
      'lastMessage': chatData['lastMessage'] ?? '',
      'isGroup': chatData['isGroup'] ?? false,
      // بيانات الطرف الآخر لسهولة العرض في شاشة الرسائل
      'displayName': otherEmployee['name'],
    };

    // الانتقال إلى شاشة الرسائل (MessageScreen)
    final img = (otherEmployee['image'] ?? '').toString().trim();
    await Get.to(
      () => MessageScreen(
        chat: selectedChatData,
        currentUserId: _currentUserId!,
        currentUserName: _currentUserName!,
        otherUserId: otherUserId,
        otherAvatarUrl: img.isEmpty ? null : img,
      ),
    );
    if (mounted) setState(() {});
  }

  // لفتح محادثة موجودة والانتقال لشاشة الرسائل
  Future<void> _openExistingChat(Map<String, dynamic> chat) async {
    String displayName;
    String? otherId;
    String? otherAvatarUrl;

    if (chat['isGroup'] == true) {
      displayName = _localizedGroupTitleFromChat(chat);
    } else {
      final participants = List<String>.from(chat['participants'] ?? []);
      otherId = participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => 'N/A',
      );
      final other = _employees.firstWhere(
        (e) => e['id'] == otherId,
        orElse: () => {},
      );
      displayName = other.isNotEmpty
          ? other['name']
          : (otherId.length > 10 ? AppLocaleKeys.chatUnknownUser.tr : otherId);
      if (other.isNotEmpty) {
        final im = (other['image'] ?? '').toString().trim();
        otherAvatarUrl = im.isEmpty ? null : im;
      }
    }

    final selectedChatData = Map<String, dynamic>.from(chat)
      ..['displayName'] = displayName;

    // الانتقال إلى شاشة الرسائل (MessageScreen)
    await Get.to(
      () => MessageScreen(
        chat: selectedChatData,
        currentUserId: _currentUserId!,
        currentUserName: _currentUserName!,
        otherUserId: otherId,
        otherAvatarUrl: otherAvatarUrl,
      ),
    );
    if (mounted) setState(() {});
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
                                        final opened =
                                            await _ensureJoinedDepartmentGroup(
                                              (group['slug'] ?? '')
                                                  .toString()
                                                  .trim(),
                                            );
                                        if (opened != null) {
                                          await _openExistingChat(opened);
                                        }
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
                                        await _openOrCreateChatWith(emp);
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

  // ---------------- Helpers ----------------
  String _initialFromName(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    return parts.first[0].toUpperCase();
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

  /// Android: system back while a [TextField] has focus can race the IME and
  /// freeze the UI; defer [Navigator.pop] until after focus is cleared.
  Widget _wrapAndroidChatsListHardwareBack(BuildContext context, Widget child) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return child;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic _) {
        if (didPop) return;
        FocusManager.instance.primaryFocus?.unfocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      },
      child: child,
    );
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        final visibleChats = _visibleChatsOrderedForList();
        return _wrapAndroidChatsListHardwareBack(
          context,
          Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(
                60.0,
              ), // تعيين حجم الـ AppBar
              child: AppBar(
                title: Text('chat.screen_title'.tr),
                centerTitle: true,
                actions: [
                  // IconButton(
                  //   icon: const Icon(Icons.close, color: Colors.black),
                  //   onPressed: widget.onMinimize,
                  // ),
                ],
              ),
            ),
            body: Container(
              decoration: BoxDecoration(color: const Color(0xfff7f9fc)),
              // هنا كان الـ Row الذي يقسم الشاشة، الآن هو شاشة القائمة فقط
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: RefreshIndicator(
                  color: kChatUiAccent,
                  onRefresh: () async {
                    await _initUserThenLoad();
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
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
                                      hintText:
                                          AppLocaleKeys.chatSearchInChats.tr,
                                      prefixIcon: const Icon(Icons.search),
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
                                      child: const Icon(
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
                      ),
                      SliverToBoxAdapter(
                        child: ChatListFolderTabs(
                          selected: _chatListFolder,
                          onSelected: (f) {
                            setState(() => _chatListFolder = f);
                          },
                        ),
                      ),
                      if (_isLoadingGroup || _loadingChats)
                        SliverToBoxAdapter(
                          child: Padding(
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
                        ),
                      if (_loadingChats)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: SizedBox(height: Get.height * 0.5),
                        )
                      else if (_chats.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: SizedBox(
                            height: Get.height * 0.5,
                            child: Center(child: Text('chat.no_chats'.tr)),
                          ),
                        )
                      else if (visibleChats.isEmpty &&
                          _chatListSearchQuery.trim().isNotEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: SizedBox(
                            height: Get.height * 0.5,
                            child: Center(
                              child: Text(AppLocaleKeys.chatSearchNoMatches.tr),
                            ),
                          ),
                        )
                      else if (visibleChats.isEmpty && _chats.isNotEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: SizedBox(
                            height: Get.height * 0.45,
                            child: Center(
                              child: Text(AppLocaleKeys.chatFolderEmpty.tr),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final ch = visibleChats[index];
                            final isGroup = ch['isGroup'] ?? false;
                            final chatId = ch['id'] as String;

                            String displayName;
                            String initial;
                            Color avatarColor;
                            IconData? avatarIcon;
                            String? groupAssetPath;
                            Color? titleColor;
                            String? dmImageUrl;
                            String? otherIdForPresence;
                            var showPrivateOnlineDot = false;
                            String? titleSubline;

                            if (isGroup) {
                              displayName = _localizedGroupTitleFromChat(ch);
                              initial = _initialFromName(displayName);
                              avatarColor = Colors.blueGrey.shade100;
                              avatarIcon = Icons.group;
                              groupAssetPath =
                                  _departmentGroupAssetPathFromChat(ch);
                              titleColor = Colors.blue.shade700;
                              final connected = _connectedUsersCountForGroup(ch);
                              titleSubline = AppLocaleKeys.chatConnectedCount
                                  .trParams({'count': '$connected'});
                            } else {
                              final participants = List<String>.from(
                                ch['participants'] ?? [],
                              );
                              final otherId = participants.firstWhere(
                                (id) => id != _currentUserId,
                                orElse: () => 'N/A',
                              );
                              otherIdForPresence = otherId;
                              final other = _employees.firstWhere(
                                (e) => e['id'] == otherId,
                                orElse: () => {},
                              );
                              displayName = other.isNotEmpty
                                  ? other['name']
                                  : (otherId.length > 10
                                        ? AppLocaleKeys.chatUnknownUser.tr
                                        : otherId);
                              initial = _initialFromName(displayName);
                              avatarColor = Colors.grey.shade200;
                              avatarIcon = null;
                              groupAssetPath = null;
                              titleColor = Colors.black;
                              if (other.isNotEmpty) {
                                final im = (other['image'] ?? '')
                                    .toString()
                                    .trim();
                                dmImageUrl = im.isEmpty ? null : im;
                              }
                              final online = _isOnlinePresence(
                                _presenceOf(otherIdForPresence),
                              );
                              showPrivateOnlineDot = online;
                              titleSubline = _privatePresenceLabel(
                                otherIdForPresence,
                              );
                            }

                            return StreamBuilder<int>(
                              stream: _firestoreServices
                                  .unreadIncomingCountStream(
                                    chatId,
                                    _currentUserId ?? '',
                                  ),
                              builder: (context, snapshot) {
                                final unreadCount = snapshot.data ?? 0;
                                final isPinned = _pinnedChatIds.contains(
                                  chatId,
                                );
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
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    onTap: () => _openExistingChat(ch),
                                    leading: chatListLeadingWithPinBadge(
                                      pinned: isPinned,
                                      avatarChild: _avatarWithOnlineDot(
                                        showOnlineDot:
                                            !isGroup && showPrivateOnlineDot,
                                        avatar: chatLeadingAvatar(
                                          radius: 24,
                                          backgroundColor: avatarColor,
                                          initial: initial,
                                          groupIcon: avatarIcon,
                                          assetImagePath: groupAssetPath,
                                          imageUrl: dmImageUrl,
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
                                              fontWeight: unreadCount > 0
                                                  ? FontWeight.bold
                                                  : FontWeight.w400,
                                              color: titleColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2),
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
                                      highlightSubline:
                                          !isGroup && showPrivateOnlineDot,
                                      unreadCount: unreadCount,
                                    ),
                                  ),
                                );
                              },
                            );
                          }, childCount: visibleChats.length),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// **********************************************
// ********* الشاشة الجديدة 2: شاشة الرسائل *********
// **********************************************

class MessageScreen extends StatefulWidget {
  final Map<String, dynamic> chat;
  final String currentUserId;
  final String currentUserName;
  final String? otherUserId; // null للمجموعات
  final String? otherAvatarUrl;

  const MessageScreen({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.currentUserName,
    this.otherUserId,
    this.otherAvatarUrl,
  });

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen>
    with WidgetsBindingObserver, RouteAware {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  ChatImagePasteListener? _imagePasteListener;
  bool _isEmojiVisible = false;
  PendingChatAttachment? _pendingAttachment;
  ChatReplyDraft? _replyDraft;
  final ChatMessageListPanelController _chatListPanelController =
      ChatMessageListPanelController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _orderedChatMessageDocs =
      [];
  int _chatMessageListEpoch = 0;
  ChatScrollSnapshot? _persistedScrollForOpen;
  bool _scrollPrefsReady = false;
  String? _currentUserRole;

  DateTime? _presenceOf(String? employeeId) {
    final id = employeeId?.trim() ?? '';
    if (id.isEmpty || !Get.isRegistered<HomeController>()) return null;
    return Get.find<HomeController>().employeeLastSeenAt(id);
  }

  bool _isOnlinePresence(DateTime? at) {
    if (at == null) return false;
    return DateTime.now().difference(at.toLocal()) <= const Duration(minutes: 2);
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

  String _initialFromName(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    return parts.first[0].toUpperCase();
  }

  String _conversationTitleForFcm() {
    final fromMap = chatConversationTitleForPushDisplay(widget.chat);
    if (fromMap.isNotEmpty) return fromMap;
    return _displayName;
  }

  void _scrollToRepliedMessage(String messageId) {
    _chatListPanelController.scrollToMessageId(messageId);
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final PrivateChatTypingWriter _typingWriter;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messageSoundSubscription;

  late String _chatId;
  late String _displayName;
  late final Future<ChatScrollSnapshot?> _openScrollPrefsFuture;
  ChatScrollSnapshot? _lastScrollSnapshotForPersist;

  static const _kScrollDiskDebounceMs = 350;
  Timer? _scrollDiskFlushTimer;

  bool get _enableContentInsertion =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  PageRoute<dynamic>? _routeObserved;

  void _applyVisibleChatFocusToServices() {
    unawaited(
      fcm_notifications.NotificationService().dismissChatMessageNotification(
        _chatId,
      ),
    );
    ChatAudioFocus.setForeground(_chatId);
    ChatAudioFocus.registerMainLayoutChatOpen(_chatId);
    unawaited(
      FirestoreServices.syncEmployeeActiveChatId(
        widget.currentUserId,
        _chatId,
      ),
    );
  }

  void _clearVisibleChatFocusFromServices() {
    ChatAudioFocus.unregisterMainLayoutChatOpen(_chatId);
    ChatAudioFocus.clearForegroundIfEquals(_chatId);
    unawaited(
      FirestoreServices.syncEmployeeActiveChatId(
        widget.currentUserId,
        null,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is! PageRoute<dynamic>) return;
    if (_routeObserved == route) return;
    if (_routeObserved != null) {
      appRouteObserver.unsubscribe(this);
    }
    appRouteObserver.subscribe(this, route);
    _routeObserved = route;
  }

  @override
  void didPushNext() {
    _clearVisibleChatFocusFromServices();
  }

  @override
  void didPopNext() {
    if (mounted) {
      _applyVisibleChatFocusToServices();
    }
  }

  @override
  void initState() {
    super.initState();
    _typingWriter = PrivateChatTypingWriter(_firestore);
    _chatId = widget.chat['id'];
    _typingWriter.rebind(
      chatId: _chatId,
      myUserId: widget.currentUserId,
      isGroup: widget.chat['isGroup'] ?? false,
    );
    _openScrollPrefsFuture = ChatScrollPersistence.load(
      widget.currentUserId,
      _chatId,
    );
    unawaited(
      _openScrollPrefsFuture.then((snap) {
        if (!mounted) return;
        setState(() {
          _persistedScrollForOpen = snap;
          _scrollPrefsReady = true;
          _chatMessageListEpoch++;
        });
      }),
    );
    _displayName =
        widget.chat['displayName'] ?? AppLocaleKeys.chatConversationFallback.tr;
    _currentUserRole = Get.find<HomeController>().currentEmployee.value?.role;
    _messagesStream = _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(FirestoreQueryLimits.chatMessagesPage)
        .snapshots();

    _applyVisibleChatFocusToServices();
    _messageSoundSubscription = attachIncomingMessageSoundSubscription(
      stream: _messagesStream!,
      chatId: _chatId,
      currentUserId: widget.currentUserId,
    );

    _messageController.addListener(_onComposerTextChanged);
    WidgetsBinding.instance.addObserver(this);
    _imagePasteListener = ChatImagePasteListener(
      onImagePasted: _handlePastedImage,
      onPasteError: _showPasteImageFailed,
      shouldHandle: () =>
          mounted &&
          !_messageFocusNode.hasFocus &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed),
    );
  }

  void _onComposerTextChanged() {
    _typingWriter.onComposerTextChanged(_messageController.text);
  }

  Map<String, String> _participantNamesMap() {
    final names = <String, String>{};
    final parts = List<String>.from(widget.chat['participants'] ?? const []);
    if (Get.isRegistered<HomeController>()) {
      final hc = Get.find<HomeController>();
      for (final id in parts) {
        final n = hc.getEmployeeById(id)?.name;
        if (n != null && n.trim().isNotEmpty) {
          names[id] = n.trim();
        }
      }
    }
    return names;
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
        unawaited(_persistScrollSnapshotNow());
      },
    );
  }

  Future<void> _persistScrollSnapshotNow() async {
    final live = _chatListPanelController.currentScrollSnapshot;
    final snap = live ?? _lastScrollSnapshotForPersist;
    if (snap == null) return;
    await ChatScrollPersistence.saveSnapshot(
      userId: widget.currentUserId,
      chatId: _chatId,
      snapshot: snap,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _flushScrollDiskTimer();
      unawaited(_persistScrollSnapshotNow());
      unawaited(_typingWriter.clearTyping());
    }
  }

  void _onChatListScrollSnapshot(ChatScrollSnapshot snap) {
    final len = _orderedChatMessageDocs.length;
    if (len == 0 || snap.index < len) {
      _lastScrollSnapshotForPersist = snap;
      _scheduleDebouncedDiskPersist();
    }
  }

  void _onChatListDocsChanged(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    _orderedChatMessageDocs = docs;
    ChatMediaGalleryStore.update(_chatId, docs);
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
    final shiftPressed = composerShiftPressed();
    if (shiftPressed) return KeyEventResult.ignored;
    final hc = Get.find<HomeController>();
    final busy = hc.isChatUploadActiveFor(_chatId);
    if (!busy) {
      unawaited(_sendMessage());
    }
    return KeyEventResult.handled;
  }

  Future<void> _showAttachmentMenu(BuildContext anchorContext) async {
    final homeController = Get.find<HomeController>();
    if (!mounted) return;

    final action = await showTelegramStyleAttachmentMenu(
      context: context,
      anchorContext: anchorContext,
      photoLabel: AppLocaleKeys.chatAttachGallery.tr,
      fileLabel: AppLocaleKeys.chatAttachFile.tr,
      pasteImageLabel: AppLocaleKeys.chatPasteImage.tr,
      voiceLabel: AppLocaleKeys.chatAttachVoice.tr,
      cameraLabel: AppLocaleKeys.chatAttachPhoto.tr,
      showCamera: chatMobileCameraSupported(),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case ChatAttachmentMenuAction.camera:
        final shot = await homeController.pickChatCameraImageBytes();
        if (!mounted || shot == null) return;
        final pending = await stageChatMediaUpload(
          bytes: shot.bytes,
          fileName: shot.fileName,
          chatId: _chatId,
          home: homeController,
          activityWriter: _typingWriter,
        );
        if (!mounted || pending == null) return;
        setState(() => _pendingAttachment = pending);
        homeController.uploadedFilesPaths.clear();
        return;
      case ChatAttachmentMenuAction.photo:
        final v = await homeController.pickOneChatGalleryMedia();
        if (!mounted || v.isEmpty || v.first.bytes == null) return;
        final picked = v.first;
        final pending = await stageChatMediaUpload(
          bytes: picked.bytes!,
          fileName: picked.name,
          chatId: _chatId,
          home: homeController,
          activityWriter: _typingWriter,
        );
        if (!mounted || pending == null) return;
        setState(() => _pendingAttachment = pending);
        homeController.uploadedFilesPaths.clear();
        return;
      case ChatAttachmentMenuAction.file:
        final v = await homeController.pickOneChatFile();
        if (!mounted || v.isEmpty || v.first.bytes == null) return;
        final pending = await stageChatFileUpload(
          bytes: v.first.bytes!,
          fileName: v.first.name,
          chatId: _chatId,
          home: homeController,
          activityWriter: _typingWriter,
        );
        if (!mounted || pending == null) return;
        setState(() => _pendingAttachment = pending);
        homeController.uploadedFilesPaths.clear();
        return;
      case ChatAttachmentMenuAction.voice:
        await _showVoiceAttachmentSheet();
        return;
      case ChatAttachmentMenuAction.pasteImage:
        await _pasteImageFromClipboard();
        return;
    }
  }

  Future<void> _showVoiceAttachmentSheet() async {
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
                  AppLocaleKeys.chatAttachVoice.tr,
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
                    chatId: _chatId,
                    activityWriter: _typingWriter,
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

  @override
  void dispose() {
    if (_routeObserved != null) {
      appRouteObserver.unsubscribe(this);
      _routeObserved = null;
    }
    _flushScrollDiskTimer();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_persistScrollSnapshotNow());
    _imagePasteListener?.dispose();
    _messageSoundSubscription?.cancel();
    unawaited(_typingWriter.dispose());
    _clearVisibleChatFocusFromServices();
    // Do not call unfocus() here: during Android route pop it can deadlock the
    // platform text input channel; dispose() releases focus.
    _messageFocusNode.dispose();
    _messageController.removeListener(_onComposerTextChanged);
    _messageController.dispose();
    super.dispose();
  }

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
    if (mounted) {
      setState(() {
        _isEmojiVisible = false;
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

  Future<void> _handlePastedImage(Uint8List bytes, String mimeType) async {
    if (!mounted) return;
    final controller = Get.find<HomeController>();
    if (controller.isUploading.value) return;

    final fileName =
        'pasted_${DateTime.now().millisecondsSinceEpoch}.${_extFromMime(mimeType)}';
    final pending = await stageChatMediaUpload(
      bytes: bytes,
      fileName: fileName,
      chatId: _chatId,
      home: controller,
      activityWriter: _typingWriter,
    );
    if (!mounted || pending == null) return;
    setState(() => _pendingAttachment = pending);
    controller.uploadedFilesPaths.clear();
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

    unawaited(_typingWriter.clearTyping());
    final isGroup = widget.chat['isGroup'] ?? false;
    if (ChatAudioFocus.incomingTreatAsInChat(_chatId)) {
      unawaited(AudioService.instance.playActiveChatOutgoingSound());
    }
    final chatRef = _firestore.collection('chats').doc(_chatId);
    final msgRef = chatRef.collection('messages').doc();

    final payload = <String, dynamic>{
      'senderId': widget.currentUserId,
      'senderName': widget.currentUserName,
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
      actorParticipantId: widget.currentUserId,
      lastMessagePreview: lastMessagePreview,
      messageData: payload,
      participantIds: List<String>.from(widget.chat['participants'] ?? []),
    );

    final fcmConvTitle = _conversationTitleForFcm();
    if (!isGroup && widget.otherUserId != null) {
      await FirestoreServices.sendFcm(
        userId: widget.otherUserId ?? '',
        title: widget.currentUserName,
        body: lastMessagePreview,
        notificationType: 'chat_message',
        fcmDataExtras: {
          'chatId': _chatId,
          'chatTitle': widget.currentUserName,
          'chatDisplayName': fcmConvTitle,
          'senderName': widget.currentUserName,
          'isGroup': '0',
        },
      );
    } else if (isGroup) {
      final participants = List<String>.from(widget.chat['participants'] ?? []);
      for (var id in participants) {
        if (id != widget.currentUserId) {
          await FirestoreServices.sendFcm(
            userId: id,
            title: AppLocaleKeys.chatFcmInGroupTitle.trParams({
              'user': widget.currentUserName,
              'group': _displayName,
            }),
            body: lastMessagePreview,
            notificationType: 'chat_message',
            fcmDataExtras: {
              'chatId': _chatId,
              'chatTitle': fcmConvTitle,
              'chatDisplayName': fcmConvTitle,
              'senderName': widget.currentUserName,
              'isGroup': '1',
            },
          );
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
      return 'time.seconds_ago'.tr;
    } else if (diff.inMinutes < 60) {
      return AppLocaleKeys.commonMinutesAgo.trParams({
        'count': '${diff.inMinutes}',
      });
    } else if (diff.inHours < 24) {
      return AppLocaleKeys.commonHoursAgo.trParams({
        'count': '${diff.inHours}',
      });
    } else if (diff.inDays < 7) {
      return 'time.ago_days'.trParams({'count': '${diff.inDays}'});
    } else {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
  }

  /// Android: defer pop until IME/emoji UI is cleared (see [ChatsListScreen]).
  Widget _wrapAndroidMessageHardwareBack(BuildContext context, Widget child) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return child;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic _) {
        if (didPop) return;
        if (_isEmojiVisible) {
          setState(() => _isEmojiVisible = false);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = widget.chat['isGroup'] ?? false;
    final otherAvatarUrl = widget.otherAvatarUrl?.trim() ?? '';
    final privateOnlineDot = !isGroup &&
        _isOnlinePresence(_presenceOf(widget.otherUserId));
    return _wrapAndroidMessageHardwareBack(
      context,
      Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFEAE5ED),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              // الرجوع إلى شاشة قائمة المحادثات
              Get.back();
            },
          ),
          titleSpacing: 8,
          title: Row(
            children: [
              if (!isGroup && isChatImageHttpUrl(widget.otherAvatarUrl)) ...[
                _avatarWithOnlineDot(
                  showOnlineDot: privateOnlineDot,
                  avatar: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade200,
                    child: ClipOval(
                      child: Image.network(
                        otherAvatarUrl,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          _initialFromName(_displayName),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                    ChatActivitySubline(
                      chatId: _chatId,
                      isGroup: isGroup,
                      otherUserId: widget.otherUserId,
                      groupParticipantIds: isGroup
                          ? List<String>.from(
                              widget.chat['participants'] ?? const [],
                            )
                          : const [],
                      participantNames: _participantNamesMap(),
                      selfUserId: widget.currentUserId,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(color: Color(0xFFE9EDEF)),
          child: Column(
            children: [
              // 1. عرض الرسائل
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: !_scrollPrefsReady || _messagesStream == null
                      ? const Center(child: CircularProgressIndicator())
                      : ChatMessagesViewport(
                          chatId: _chatId,
                          child: ChatMessageListHost(
                          stream: _messagesStream!,
                          chatId: _chatId,
                          currentUserId: widget.currentUserId,
                          listEpoch: _chatMessageListEpoch,
                          panelController: _chatListPanelController,
                          persistedScroll: _lastScrollSnapshotForPersist ??
                              _persistedScrollForOpen,
                          usePersistedScroll:
                              _lastScrollSnapshotForPersist != null ||
                              _persistedScrollForOpen != null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          loadingWidget: const Center(
                            child: CircularProgressIndicator(),
                          ),
                          emptyWidget: Center(
                            child: Text('chat.start_first'.tr),
                          ),
                          onDocsChanged: _onChatListDocsChanged,
                          onScrollSnapshotChanged: _onChatListScrollSnapshot,
                          pinnedBannerBuilder: (context, pinnedDocs) => Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                            child: ChatPinnedMessagesBar(
                              pinnedDocs: pinnedDocs,
                              isGroup: isGroup,
                              onTapMessage: _scrollToRepliedMessage,
                            ),
                          ),
                          itemBuilder: (context, doc, index) {
                            final msg = doc.data();
                            final mid = doc.id;
                            final isMe =
                                msg['senderId'] == widget.currentUserId;
                            final senderName =
                                msg['senderName'] ?? 'chat.unknown_user'.tr;
                            final timestamp = msg['timestamp'] as Timestamp?;
                            final isRead = msg['isRead'] ?? false;

                            return Padding(
                              key: ValueKey(mid),
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              child: ChatMessageTile(
                                chatId: _chatId,
                                messageId: mid,
                                message: Map<String, dynamic>.from(msg),
                                isMe: isMe,
                                isGroup: isGroup,
                                senderName: senderName,
                                showGroupSenderName: isGroup && !isMe,
                                timestamp: timestamp,
                                formatTime: _formatTimestamp,
                                isAdmin: _currentUserRole == 'admin',
                                currentUserId: widget.currentUserId,
                                currentUserDisplayName: widget.currentUserName,
                                onReply: (draft) =>
                                    setState(() => _replyDraft = draft),
                                onReplyPreviewTap: _scrollToRepliedMessage,
                                bubbleDecoration: BoxDecoration(
                                  color: isMe
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(isMe ? 18 : 5),
                                    bottomRight: Radius.circular(isMe ? 5 : 18),
                                  ),
                                ),
                                maxWidthFactor: 0.76,
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
                ),
              ),

              ChatUploadProgressBanner(chatId: _chatId),
              if (_replyDraft != null)
                ChatReplyDraftBanner(
                  draft: _replyDraft!,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                  onCancel: () => setState(() => _replyDraft = null),
                ),
              if (_pendingAttachment != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
                  child: PendingAttachmentStrip(
                    pending: _pendingAttachment!,
                    onCancel: () => setState(() => _pendingAttachment = null),
                    onTapPreview:
                        (_pendingAttachment!.messageType == 'image' ||
                            _pendingAttachment!.messageType == 'video')
                        ? () => openChatMediaFromUrl(
                            _pendingAttachment!.attachmentUrl,
                            chatId: _chatId,
                          )
                        : null,
                  ),
                ),

              // 2. إدخال الرسالة والإيموجي
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.fromLTRB(
                      10,
                      6,
                      10,
                      _messageFocusNode.hasFocus ? 14 : 10,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: _messageFocusNode.hasFocus ? 4 : 8,
                      vertical: _messageFocusNode.hasFocus ? 6 : 4,
                    ),
                    constraints: BoxConstraints(
                      minHeight: _messageFocusNode.hasFocus ? 54 : 50,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        _messageFocusNode.hasFocus ? 26 : 24,
                      ),
                      border: Border.all(
                        color: _messageFocusNode.hasFocus
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: _messageFocusNode.hasFocus ? 12 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Obx(() {
                      final busy = Get.find<HomeController>()
                          .isChatUploadActiveFor(_chatId);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 48,
                            ),
                            icon: Icon(
                              _isEmojiVisible
                                  ? Icons.keyboard
                                  : Icons.emoji_emotions,
                              color: Colors.grey.shade700,
                              size: 26,
                            ),
                            onPressed: busy
                                ? null
                                : () {
                                    final showEmoji = !_isEmojiVisible;
                                    setState(() => _isEmojiVisible = showEmoji);
                                    if (showEmoji) {
                                      FocusScope.of(context).unfocus();
                                    } else {
                                      _messageFocusNode.requestFocus();
                                    }
                                  },
                          ),
                          Builder(
                            builder: (buttonContext) {
                              return IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 48,
                                ),
                                tooltip: AppLocaleKeys.chatAttachSheetTitle.tr,
                                icon: Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.grey.shade700,
                                  size: 28,
                                ),
                                onPressed: busy
                                    ? null
                                    : () => _showAttachmentMenu(buttonContext),
                              );
                            },
                          ),
                          Expanded(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                textSelectionTheme:
                                    const TextSelectionThemeData(
                                      cursorColor: AppColors.primary,
                                      selectionHandleColor: AppColors.primary,
                                      selectionColor: Color(0x33514091),
                                    ),
                              ),
                              child: Focus(
                                onKeyEvent: _onComposerKeyEvent,
                                child: ListenableBuilder(
                                  listenable: _messageFocusNode,
                                  builder: (context, _) => TextField(
                                  cursorColor: AppColors.primary,
                                  controller: _messageController,
                                  focusNode: _messageFocusNode,
                                  contentInsertionConfiguration:
                                      _enableContentInsertion
                                      ? ContentInsertionConfiguration(
                                          allowedMimeTypes: const <String>[
                                            'image/png',
                                            'image/jpeg',
                                            'image/webp',
                                            'image/gif',
                                          ],
                                          onContentInserted:
                                              (
                                                KeyboardInsertedContent content,
                                              ) {
                                                final data = content.data;
                                                if (data == null ||
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
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: chatComposerTextInputAction(),
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
                                        ? 17
                                        : 16,
                                    height: 1.35,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: AppLocaleKeys.chatWriteMessage.tr,
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 16,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 12,
                                    ),
                                  ),
                                  onTap: () {
                                    if (_isEmojiVisible) {
                                      setState(() => _isEmojiVisible = false);
                                    }
                                  },
                                ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: const Icon(
                              Icons.send_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                            onPressed: busy ? null : _sendMessage,
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              // عرض لوحة الإيموجي
              Offstage(
                offstage: !_isEmojiVisible,
                child: SizedBox(
                  height: 250,
                  child: EmojiPicker(
                    onEmojiSelected: (Category? category, Emoji emoji) {
                      _messageController
                        ..text += emoji.emoji
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: _messageController.text.length),
                        );
                    },
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
