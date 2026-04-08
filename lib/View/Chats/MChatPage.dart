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
// يجب أن يكون هذا الملف متاحًا لديك، وإلا سيعطي خطأ
import 'package:point/Controller/HomeController.dart';
// يجب أن يكون هذا الملف متاحًا لديك، وإلا سيعطي خطأ
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/ChatIncomingMessageSound.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Services/chat_clipboard_image_reader.dart';
import 'package:point/Services/chat_image_paste_listener.dart';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/View/Chats/chat_message_display.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';
import 'package:point/View/Chats/chat_voice_record_button.dart';
import 'package:point/View/Chats/telegram_style_attachment_menu.dart';

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
  String? _currentUserDept;
  String? _currentUserRole;

  List<Map<String, dynamic>> _employees = []; // all employees
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<Map<String, dynamic>> _groupParticipants = [];

  List<Map<String, dynamic>> _chats = []; // chats list for current user

  bool _loadingEmployees = true;
  bool _loadingChats = true;
  bool _isLoadingGroup = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatsListSub;
  int _chatsEnrichGen = 0;

  @override
  void initState() {
    super.initState();
    _initUserThenLoad();
  }

  @override
  void dispose() {
    _chatsListSub?.cancel();
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
      _currentUserDept = StorageKeys.normalizeDepartment(
        homecontroller.currentEmployee.value?.department,
      );
    } else {
      _currentUserId = 'temp_current_user';
      _currentUserName = AppLocaleKeys.me.tr;
      _currentUserDept = null;
      _currentUserRole = null;
    }

    await _loadEmployees();
    await _createOrLoadDepartmentGroup();
    _listenChats();
  }

  // ---------------- Employees ----------------
  Future<void> _loadEmployees() async {
    _loadingEmployees = true;
    if (mounted) setState(() {});
    final snapshot = await _firestore.collection('employees').get();
    final all =
        snapshot.docs.where((d) => d.id != _currentUserId)
        // exclude current user from 1:1 chat list
        .map((d) {
          final data = d.data();
          return {
            'id': d.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'image': data['image'] ?? '',
            'dept': data['department'] ?? '',
            'role': data['role'] ?? '',
          };
        }).toList();

    // For employee role: allow chat target only when it is either:
    // - elevated role (admin/supervisor)
    // - same department as current user
    // This is a UX constraint; final enforcement is done in Firestore rules.
    if (_currentUserRole == 'employee') {
      final myDept = _currentUserDept;
      _employees =
          all.where((e) {
            final targetRole = e['role'];
            final targetDept = e['dept'];
            final isSpecialRole = StorageKeys.isChatElevatedRole(targetRole);
            final isSameDept =
                myDept != null && myDept.isNotEmpty
                    ? StorageKeys.matchesDepartment(targetDept, myDept)
                    : false;
            return isSpecialRole || isSameDept;
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
      _filteredEmployees =
          _employees
              .where(
                (e) => (e['name'] as String).toLowerCase().contains(qlower),
              )
              .toList();
    }
    if (mounted) setState(() {});
  }

  // ---------------- Department Group Logic ----------------
  Future<void> _createOrLoadDepartmentGroup() async {
    if (_currentUserId == null ||
        _currentUserDept == null ||
        _currentUserDept!.isEmpty) {
      return;
    }

    _isLoadingGroup = true;
    if (mounted) setState(() {});

    final deptGroupName = _currentUserDept!;
    final groupId = 'group_$deptGroupName';
    final groupRef = _firestore.collection('chats').doc(groupId);

    // 1. تحديد المشاركين في المجموعة
    final List<String> participantsIds = [];
    _groupParticipants.clear();

    participantsIds.add(_currentUserId!);

    _employees.forEach((emp) {
      final empId = emp['id'] as String;
      final empDept = emp['dept']; // تم تعديلها لتتوافق مع الكاش

      final isSameDept = StorageKeys.matchesDepartment(empDept, deptGroupName);

      final isSpecialRole = StorageKeys.isChatElevatedRole(emp['role']);

      if ((isSameDept || isSpecialRole) &&
          empId != _currentUserId &&
          !participantsIds.contains(empId)) {
        participantsIds.add(empId);
        _groupParticipants.add(emp);
      }
    });

    // 2. تحديث/إنشاء المجموعة
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
      // Keep group participants controlled by backfill; at runtime we only
      // ensure the current user exists inside the department group.
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

    _isLoadingGroup = false;
    if (mounted) setState(() {});
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

    final ids = built.map((c) => c['id'] as String).toList();
    final previews =
        await FirestoreServices.fetchLatestMessagePreviewsForChatIds(
          _firestore,
          ids,
        );
    if (!mounted || gen != _chatsEnrichGen) return;

    _chats = _mergeChatsWithPreviews(built, previews);
    _loadingChats = false;
    if (mounted) setState(() {});
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

  // لفتح مجموعة القسم والانتقال لشاشة الرسائل
  Future<void> _openDepartmentGroup(Map<String, dynamic> groupChat) async {
    if (_currentUserId == null || _currentUserDept == null) return;
    final deptGroupName = _currentUserDept!;
    final groupId = 'group_$deptGroupName';
    final groupRef = _firestore.collection('chats').doc(groupId);

    final groupDoc = await groupRef.get();
    if (groupDoc.exists) {
      final chatData = groupDoc.data() ?? {};
      final selectedChatData = {
        'id': groupDoc.id,
        'participants': List<String>.from(chatData['participants'] ?? []),
        'lastMessage': chatData['lastMessage'] ?? '',
        'isGroup': chatData['isGroup'] ?? false,
        'title': chatData['title'],
        // اسم العرض للمجموعة
        'displayName': _localizedGroupTitleFromChat({
          'id': groupDoc.id,
          'title': chatData['title'],
        }),
      };

      // الانتقال إلى شاشة الرسائل (MessageScreen)
      await Get.to(
        () => MessageScreen(
          chat: selectedChatData,
          currentUserId: _currentUserId!,
          currentUserName: _currentUserName!,
          otherUserId: null, // لا يوجد طرف آخر محدد في المجموعة
        ),
      );
      if (mounted) setState(() {});
    }
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
      displayName =
          other.isNotEmpty
              ? other['name']
              : (otherId.length > 10
                  ? AppLocaleKeys.chatUnknownUser.tr
                  : otherId);
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
                              ? Center(child: Text('chat.no_employees'.tr))
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
                                      // عند الضغط، ننتقل مباشرة لشاشة الرسائل
                                      await _openOrCreateChatWith(emp);
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

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60.0), // تعيين حجم الـ AppBar
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
                                    // هنا يمكن إضافة منطق فلترة المحادثات المحلية إذا احتجت
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
                                      color: const Color(0xff00A389),
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
                    if (_currentUserDept != null &&
                        _currentUserDept!.isNotEmpty)
                      SliverToBoxAdapter(
                        child: StreamBuilder<int>(
                          stream: _firestoreServices.unreadIncomingCountStream(
                            'group_$_currentUserDept',
                            _currentUserId ?? '',
                          ),
                          builder: (context, snapshot) {
                            final unreadCount = snapshot.data ?? 0;
                            final groupChatData = _chats.firstWhere(
                              (c) => c['id'] == 'group_$_currentUserDept',
                              orElse: () => {},
                            );
                            if (groupChatData.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final lastGroupMsg =
                                groupChatData['lastMessage']?.toString() ?? '';

                            return ListTile(
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.blueGrey.shade100,
                                child: const Icon(
                                  Icons.group,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              title: Text(
                                _localizedGroupTitleFromChat(groupChatData),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              subtitle: Text(
                                lastGroupMsg.isEmpty
                                    ? AppLocaleKeys.chatGroupConversation.tr
                                    : lastGroupMsg,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing:
                                  unreadCount > 0
                                      ? Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          unreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                      : null,
                              onTap: () => _openDepartmentGroup(groupChatData),
                            );
                          },
                        ),
                      ),
                    if (_isLoadingGroup)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: LinearProgressIndicator()),
                        ),
                      ),
                    if (_loadingChats)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: SizedBox(
                          height: Get.height * 0.5,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (_chats.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: SizedBox(
                          height: Get.height * 0.5,
                          child: Center(child: Text('chat.no_chats'.tr)),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final ch = _chats[index];
                          final isGroup = ch['isGroup'] ?? false;
                          final chatId = ch['id'] as String;

                          if (isGroup && chatId == 'group_$_currentUserDept') {
                            return const SizedBox.shrink();
                          }

                          String displayName;
                          String initial;
                          Color avatarColor;
                          IconData? avatarIcon;
                          Color? titleColor;
                          String? dmImageUrl;

                          late final String listSubtitle;
                          if (isGroup) {
                            displayName = _localizedGroupTitleFromChat(ch);
                            final lm =
                                (ch['lastMessage'] ?? '').toString().trim();
                            listSubtitle =
                                lm.isNotEmpty
                                    ? lm
                                    : AppLocaleKeys.chatGroupConversation.tr;
                            initial = _initialFromName(displayName);
                            avatarColor = Colors.blueGrey.shade100;
                            avatarIcon = Icons.group;
                            titleColor = Colors.blue.shade700;
                          } else {
                            final participants = List<String>.from(
                              ch['participants'] ?? [],
                            );
                            final otherId = participants.firstWhere(
                              (id) => id != _currentUserId,
                              orElse: () => 'N/A',
                            );
                            final other = _employees.firstWhere(
                              (e) => e['id'] == otherId,
                              orElse: () => {},
                            );
                            displayName =
                                other.isNotEmpty
                                    ? other['name']
                                    : (otherId.length > 10
                                        ? AppLocaleKeys.chatUnknownUser.tr
                                        : otherId);
                            initial = _initialFromName(displayName);
                            avatarColor = Colors.grey.shade200;
                            avatarIcon = null;
                            titleColor = Colors.black;
                            listSubtitle = ch['lastMessage'] ?? '';
                            if (other.isNotEmpty) {
                              final im =
                                  (other['image'] ?? '').toString().trim();
                              dmImageUrl = im.isEmpty ? null : im;
                            }
                          }

                          return StreamBuilder<int>(
                            stream: _firestoreServices
                                .unreadIncomingCountStream(
                                  chatId,
                                  _currentUserId ?? '',
                                ),
                            builder: (context, snapshot) {
                              final unreadCount = snapshot.data ?? 0;
                              return ListTile(
                                onTap: () => _openExistingChat(ch),
                                leading: chatLeadingAvatar(
                                  radius: 24,
                                  backgroundColor: avatarColor,
                                  initial: initial,
                                  groupIcon: avatarIcon,
                                  imageUrl: dmImageUrl,
                                ),
                                title: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                  ),
                                ),
                                subtitle: Text(
                                  listSubtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing:
                                    unreadCount > 0
                                        ? Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                        : null,
                              );
                            },
                          );
                        }, childCount: _chats.length),
                      ),
                  ],
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

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  ChatImagePasteListener? _imagePasteListener;
  bool _isEmojiVisible = false;
  String? _pendingPastedImageUrl;

  String _initialFromName(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    return parts.first[0].toUpperCase();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messageSoundSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _markReadSubscription;
  late String _chatId;
  late String _displayName;
  bool get _enableContentInsertion =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chat['id'];
    _displayName =
        widget.chat['displayName'] ?? AppLocaleKeys.chatConversationFallback.tr;
    _messagesStream =
        _firestore
            .collection('chats')
            .doc(_chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .snapshots();

    ChatAudioFocus.setForeground(_chatId);
    unawaited(
      FirestoreServices.syncEmployeeActiveChatId(widget.currentUserId, _chatId),
    );
    _messageSoundSubscription = attachIncomingMessageSoundSubscription(
      stream: _messagesStream!,
      chatId: _chatId,
      currentUserId: widget.currentUserId,
    );

    _markReadSubscription = _messagesStream!.listen((_) {
      unawaited(
        FirestoreServices.markIncomingMessagesReadInChat(
          _chatId,
          widget.currentUserId,
        ),
      );
    });

    unawaited(
      FirestoreServices.markIncomingMessagesReadInChat(
        _chatId,
        widget.currentUserId,
      ),
    );

    _messageFocusNode.addListener(_onMessageFocusChanged);
    _messageController.addListener(_onComposerTextChanged);
    _imagePasteListener = ChatImagePasteListener(
      onImagePasted: _handlePastedImage,
      onPasteError: _showPasteImageFailed,
      shouldHandle:
          () =>
              mounted &&
              !_messageFocusNode.hasFocus &&
              (WidgetsBinding.instance.lifecycleState == null ||
                  WidgetsBinding.instance.lifecycleState ==
                      AppLifecycleState.resumed),
    );
  }

  void _onComposerTextChanged() {
    if (mounted) setState(() {});
  }

  void _onMessageFocusChanged() {
    if (mounted) setState(() {});
  }

  KeyEventResult _onComposerKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isEnter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    final shiftPressed = composerShiftPressed();
    if (shiftPressed) return KeyEventResult.ignored;
    final busy = Get.find<HomeController>().isUploading.value;
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
    );
    if (!mounted || action == null) return;

    switch (action) {
      case ChatAttachmentMenuAction.photo:
        final v = await homeController.pickOneChatGalleryMedia();
        if (!mounted || v.isEmpty || v.first.bytes == null) return;
        final picked = v.first;
        final url = await homeController.uploadFiles(
          filePathOrBytes: picked.bytes!,
          fileName: picked.name,
          useBlockingUploadDialog: false,
        );
        if (url == null || !mounted) return;
        final cap = _messageController.text.trim();
        final isVid = chatAttachmentIsVideo(picked.name);
        await _sendChatPayload(
          lastMessagePreview: cap.isNotEmpty ? cap : (isVid ? '🎬' : '📷'),
          messageType: isVid ? 'video' : 'image',
          text: cap,
          attachmentUrl: url,
          fileName: isVid ? picked.name : null,
        );
        _messageController.clear();
        homeController.uploadedFilesPaths.clear();
        return;
      case ChatAttachmentMenuAction.file:
        final v = await homeController.pickOneChatFile();
        if (!mounted || v.isEmpty || v.first.bytes == null) return;
        final url = await homeController.uploadFiles(
          filePathOrBytes: v.first.bytes!,
          fileName: v.first.name,
          useBlockingUploadDialog: false,
        );
        if (url == null || !mounted) return;
        await _sendChatPayload(
          lastMessagePreview: v.first.name,
          messageType: 'file',
          text: '',
          attachmentUrl: url,
          fileName: v.first.name,
        );
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
                    onUploaded: (url, sec) async {
                      if (Navigator.of(ctx).canPop()) Navigator.pop(ctx);
                      await _sendChatPayload(
                        lastMessagePreview: '🎤',
                        messageType: 'voice',
                        text: url,
                        attachmentUrl: url,
                        durationSec: sec > 0 ? sec : null,
                      );
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
    _imagePasteListener?.dispose();
    _messageSoundSubscription?.cancel();
    _markReadSubscription?.cancel();
    ChatAudioFocus.clearForegroundIfEquals(_chatId);
    unawaited(
      FirestoreServices.syncEmployeeActiveChatId(widget.currentUserId, null),
    );
    _messageFocusNode.removeListener(_onMessageFocusChanged);
    _messageFocusNode.unfocus();
    _messageFocusNode.dispose();
    _messageController.removeListener(_onComposerTextChanged);
    _messageController.dispose();
    super.dispose();
  }

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
    if (mounted) {
      setState(() {
        _isEmojiVisible = false;
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
    setState(() => _pendingPastedImageUrl = url);
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

    final isGroup = widget.chat['isGroup'] ?? false;
    final chatRef = _firestore.collection('chats').doc(_chatId);
    final msgRef = chatRef.collection('messages').doc();

    final payload = <String, dynamic>{
      'senderId': widget.currentUserId,
      'senderName': widget.currentUserName,
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

    if (!isGroup && widget.otherUserId != null) {
      await FirestoreServices.sendFcm(
        userId: widget.otherUserId ?? '',
        title: widget.currentUserName,
        body: lastMessagePreview,
        notificationType: 'chat_message',
        fcmDataExtras: {'chatId': _chatId},
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
            fcmDataExtras: {'chatId': _chatId},
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

  @override
  Widget build(BuildContext context) {
    final isGroup = widget.chat['isGroup'] ?? false;
    return Scaffold(
      appBar: AppBar(
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
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                child: ClipOval(
                  child: Image.network(
                    widget.otherAvatarUrl!.trim(),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Text(
                          _initialFromName(_displayName),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                _displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(color: Color(0xfff7f9fc)),
        child: Column(
          children: [
            // 1. عرض الرسائل
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('chat.start_first'.tr));
                    }

                    final messages = snapshot.data!.docs;

                    return ListView.builder(
                      reverse: true, // لعرض الرسائل الأحدث في الأسفل
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index].data();
                        final isMe = msg['senderId'] == widget.currentUserId;
                        final senderName =
                            msg['senderName'] ?? 'chat.unknown_user'.tr;
                        final timestamp = msg['timestamp'] as Timestamp?;
                        final isRead = msg['isRead'] ?? false;

                        return Align(
                          alignment:
                              isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4.0,
                              horizontal: 8.0,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                              children: [
                                // اسم المرسل للمجموعات
                                if (isGroup && !isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2.0),
                                    child: Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                // فقاعة الرسالة
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isMe
                                            ? const Color(0xff00A389)
                                            : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(15),
                                      topRight: const Radius.circular(15),
                                      bottomLeft: Radius.circular(
                                        isMe ? 15 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 4 : 15,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: chatMessageBubbleContent(
                                    Map<String, dynamic>.from(msg),
                                    isMe,
                                  ),
                                  // Text(
                                  //   msg['text'] ?? 'رسالة فارغة',
                                  //   style: TextStyle(
                                  //     color: isMe ? Colors.white : Colors.black,
                                  //   ),
                                  // ),
                                ),
                                // وقت وتاريخ الإرسال
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTimestamp(timestamp),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      if (isMe)
                                        Icon(
                                          isRead ? Icons.done_all : Icons.done,
                                          size: 14,
                                          color:
                                              isRead
                                                  ? Colors.blue
                                                  : Colors.grey,
                                        ),
                                    ],
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
            ),

            const ChatUploadProgressBanner(),
            if (_pendingPastedImageUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        onTap:
                            () => openChatMediaFromUrl(_pendingPastedImageUrl!),
                        child: Image.network(
                          _pendingPastedImageUrl!,
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                                  const Icon(Icons.image_outlined, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocaleKeys.chatPasteImage.tr,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocaleKeys.commonCancel.tr,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed:
                          () => setState(() => _pendingPastedImageUrl = null),
                    ),
                  ],
                ),
              ),

            // 2. إدخال الرسالة والإيموجي
            AnimatedContainer(
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
                  color:
                      _messageFocusNode.hasFocus
                          ? const Color(0xff00A389).withValues(alpha: 0.35)
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
                final busy = Get.find<HomeController>().isUploading.value;
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
                        _isEmojiVisible ? Icons.keyboard : Icons.emoji_emotions,
                        color: Colors.grey.shade700,
                        size: 26,
                      ),
                      onPressed:
                          busy
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
                          onPressed:
                              busy
                                  ? null
                                  : () => _showAttachmentMenu(buttonContext),
                        );
                      },
                    ),
                    Expanded(
                      child: Focus(
                        onKeyEvent: _onComposerKeyEvent,
                        child: TextField(
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
                                    onContentInserted: (
                                      KeyboardInsertedContent content,
                                    ) {
                                      final data = content.data;
                                      if (data == null || data.isEmpty) {
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
                          readOnly: busy,
                          textAlignVertical: TextAlignVertical.center,
                          textDirection: textDirectionForTypedChatMessage(
                            _messageController.text,
                            Directionality.of(context),
                          ),
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontSize: _messageFocusNode.hasFocus ? 17 : 16,
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
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Color(0xff00A389),
                        size: 28,
                      ),
                      onPressed: busy ? null : _sendMessage,
                    ),
                  ],
                );
              }),
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
                  // config: const Config(
                  //   columns: 7,
                  //   emojiSizeMax: 32.0,
                  //   verticalSpacing: 0,
                  //   horizontalSpacing: 0,
                  //   initCategory: Category.RECENT,
                  //   bgColor: Color(0xFFF2F2F2),
                  //   indicatorColor: Colors.blue,
                  //   iconColor: Colors.grey,
                  //   iconColorSelected: Colors.blue,
                  //   progressIndicatorColor: Colors.blue,
                  //   showRecentsTab: true,
                  //   recentsLimit: 28,
                  //   noRecents: Text(
                  //     'لا توجد إيموجي مستخدمة حديثًا',
                  //     textAlign: TextAlign.center,
                  //   ),
                  // ... other configurations
                  // ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// **********************************************
// ********* الشاشة الرئيسية للتطبيق (مثال) *********
// **********************************************

// ملاحظة: يجب أن تقوم بتحديث نقطة دخول التطبيق لتستخدم ChatListScreen بدلاً من ChatScreen

/*
// مثال على كيفية استخدامها في ملف main أو router
void main() {
  // يجب التأكد من تهيئة Firebase و GetX Controller هنا
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Chat App',
      home: ChatsListScreen(
        onMinimize: () {
          // دالة تصغير الشاشة أو إغلاقها
          appLog('Minimize button pressed');
        },
      ),
    );
  }
}
*/
