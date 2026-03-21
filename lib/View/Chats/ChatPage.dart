import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/ChatIncomingMessageSound.dart';
import 'package:point/Services/FireStoreServices.dart';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// تعريف ثوابت الأدوار
const String _kRoleAdmin = 'accountholder';
const String _kRoleSupervisor = 'supervisor';

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
  bool _isEmojiVisible = false;
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance;

  // local caches
  String? _currentUserId;
  String? _otherUserId;
  String? _currentUserName;
  // **إضافة لتخزين بيانات الموظف الحالي**
  String? _currentUserDept;

  List<Map<String, dynamic>> _employees = []; // all employees
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<Map<String, dynamic>> _groupParticipants =
      []; // **لتخزين المشاركين في مجموعة القسم**

  List<Map<String, dynamic>> _chats = []; // chats list for current user
  Map<String, dynamic>? _selectedChat; // selected chat doc (id + data)

  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messageSoundSubscription;
  /// يمنع إلغاء اشتراك الصوت عند كل تحديث لقائمة المحادثات (كان يُرمى أول snapshot فيه الرسائل الجديدة).
  String? _messageSoundBoundChatId;

  bool _loadingEmployees = true;
  bool _loadingChats = true;
  bool _isLoadingGroup = false; // **إضافة حالة تحميل للمجموعة**

  @override
  void initState() {
    super.initState();
    _initUserThenLoad();
  }

  Future<void> _initUserThenLoad() async {
    final homecontroller = Get.find<HomeController>();
    // try to get current user from FirebaseAuth
    // final user = _auth.currentUser;
    if (homecontroller.currentemployee.value != null) {
      _currentUserId = homecontroller.currentemployee.value?.id;
      _currentUserName =
          homecontroller.currentemployee.value?.name ??
          homecontroller.currentemployee.value?.email ??
          'Me'.tr;
      // **جلب بيانات القسم والدور للمستخدم الحالي**
      _currentUserDept = homecontroller.currentemployee.value?.department;
    } else {
      // if no users at all, create a temporary id (but better to have employees collection)
      _currentUserId = 'temp_current_user';
      _currentUserName = 'Me'.tr;
      _currentUserDept = null;
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
      final empDept = emp['department'];
      final empRole = emp['role'] as String;

      // تحقق إذا كان موظف من نفس القسم (ويستثنى الموظف الحالي الذي أضفناه بالفعل)
      final isSameDept = empDept == deptGroupName;

      // تحقق إذا كان أدمن أو سوبر فايزر
      final isSpecialRole =
          empRole == 'admin' ||
          empRole == _kRoleAdmin ||
          empRole == _kRoleSupervisor;

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
        'title': deptGroupName.tr, // **اسم المجموعة**
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
      final currentParticipantsSet = participantsIds.toSet();
      final mergedParticipants =
          existingParticipants.toSet().union(currentParticipantsSet).toList();

      if (mergedParticipants.length != existingParticipants.length) {
        await groupRef.update({
          'participants': mergedParticipants,
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
      ChatAudioFocus.clearForeground();
      return;
    }
    final chatId = sel['id'] as String;
    ChatAudioFocus.setForeground(chatId);
    if (_messageSoundSubscription != null && _messageSoundBoundChatId == chatId) {
      return;
    }
    _messageSoundSubscription?.cancel();
    _messageSoundSubscription = null;
    _messageSoundBoundChatId = chatId;
    _messageSoundSubscription = attachIncomingMessageSoundSubscription(
      stream: stream,
      chatId: chatId,
      currentUserId: uid,
    );
  }

  // **---------------- Chats (Private & Group) ----------------**
  void _listenChats() {
    if (_currentUserId == null) return;

    _chatsSubscription?.cancel();

    _selectedChat = Get.find<HomeController>().selectedChat;
    _chatsSubscription = _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .listen((snap) {
          // تجنّب setState بعد الـ dispose (مهم عند إرسال رسالة ثم إغلاق الشاشة بسرعة)
          if (!mounted || _chatsSubscription == null) return;
          _chats.clear();
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
            _chats.add(chat);
          }

          _loadingChats = false;
          // if currently selected chat is removed, clear selection
          if (_selectedChat != null &&
              !_chats.any((c) => c['id'] == _selectedChat!['id'])) {
            _selectedChat = null;
            _messagesStream = null;
          }
          if (!mounted || _chatsSubscription == null) return;
          setState(() {});
          _syncMessageSoundListener();
        });
  }

  @override
  void dispose() {
    final sub = _chatsSubscription;
    _chatsSubscription = null; // أي callback قادم من الـ stream سيرى null ولن يستدعي setState
    sub?.cancel();
    _messageSoundSubscription?.cancel();
    _messageSoundBoundChatId = null;
    ChatAudioFocus.clearForeground();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }


  String _getSelectedChatNameSync() {
    if (_selectedChat == null) return '';

    // إذا كانت مجموعة، نستخدم العنوان (Title)
    if (_selectedChat!['isGroup'] == true) {
      return _selectedChat!['title'] ?? AppLocaleKeys.chatDepartmentGroup.tr;
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

  // ---------------- Create or open chat ----------------
  Future<void> _openOrCreateChatWith(String otherUserId) async {
    if (_currentUserId == null) return;

    final ids = [_currentUserId!, otherUserId]..sort();
    final chatId = ids.join('_');

    final chatRef = _firestore.collection('chats').doc(chatId);

    final snapshot = await chatRef.get();

    if (!snapshot.exists) {
      // create chat doc
      await chatRef.set({
        'participants': ids,
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isGroup': false, // **محادثة فردية**
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

    // set messages stream
    _messagesStream =
        chatRef
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .snapshots();

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

      _messagesStream =
          groupRef
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .snapshots();
      _otherUserId = null; // لا يوجد طرف آخر محدد في المجموعة
      setState(() {});
      _syncMessageSoundListener();
    }
  }

  // -----------// داخل الميثود send message بتاعتك
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_selectedChat == null) return;

    final chatId = _selectedChat!['id'];

    final isGroup = _selectedChat!['isGroup'] ?? false;
    final chatRef = _firestore.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();
    Get.find<HomeController>().openChat(
      OpenChatModel(
        id: chatId,
        name: _getSelectedChatNameSync(),
        avatar: 'avatar',
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

    await msgRef.set({
      'senderId': _currentUserId,
      'senderName': _currentUserName, // **إضافة اسم المرسل للمجموعة**
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await chatRef.update({
      'lastMessage': text,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    _messageController.clear();

    // إرسال إشعار: إذا كانت محادثة فردية نرسل للـ _otherUserId
    // إذا كانت مجموعة يجب أن يتم إرسال الإشعار لجميع المشاركين باستثناء المرسل
    if (!isGroup && otherId.isNotEmpty) {
      await FirestoreServices.sendFcm(
        userId: otherId,
        title: '$_currentUserName',
        body: text,
        // token: token,
      );
    } else if (isGroup) {
      final participants = List<String>.from(
        _selectedChat!['participants'] ?? [],
      );
      for (var id in participants) {
        if (id != _currentUserId) {
          // يمكن هنا إرسال الإشعار لكل مشارك بشكل فردي (إذا كنت تخزن الـ FCM token للموظفين)
          await FirestoreServices.sendFcm(
            userId: id,
            title: 'chat.fcm_in_group_title'.trParams({
              'user': _currentUserName ?? '',
              'group': '${_selectedChat!['title']}',
            }),
            body: text,
            // token: token,
          );
        }
      }
    }
  }

  Future<void> _markMessagesAsRead(String chatId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    try {
      final unreadMessages =
          await chatRef
              .collection('messages')
              .where('isRead', isEqualTo: false)
              .where('senderId', isNotEqualTo: _currentUserId)
              .get();

      for (var doc in unreadMessages.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      if (e.toString().contains('failed-precondition') ||
          e.toString().contains('index')) {
        final unreadSnapshot =
            await chatRef
                .collection('messages')
                .where('isRead', isEqualTo: false)
                .get();
        final toMark = unreadSnapshot.docs
            .where((d) => d.data()['senderId'] != _currentUserId)
            .toList();
        for (var doc in toMark) {
          await doc.reference.update({'isRead': true});
        }
      } else {
        rethrow;
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
      return AppLocaleKeys.commonMinutesAgo.trParams({'count': '${diff.inMinutes}'});
    } else if (diff.inHours < 24) {
      return AppLocaleKeys.commonHoursAgo.trParams({'count': '${diff.inHours}'});
    } else if (diff.inDays < 7) {
      return 'chat.days_ago'.trParams({'count': '${diff.inDays}'});
    } else {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
  }

  // **مُحسّن لإحصاء الرسائل غير المقروءة في المجموعات والمحادثات الفردية**
  Future<int> getUnreadCount(String chatId, String currentUserId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    try {
      final countSnapshot =
          await chatRef
              .collection('messages')
              .where('isRead', isEqualTo: false)
              .where('senderId', isNotEqualTo: currentUserId)
              .count()
              .get();
      return countSnapshot.count ?? 0;
    } catch (e) {
      if (e.toString().contains('failed-precondition') ||
          e.toString().contains('index')) {
        final snapshot =
            await chatRef
                .collection('messages')
                .where('isRead', isEqualTo: false)
                .get();
        return snapshot.docs
            .where((d) => d.data()['senderId'] != currentUserId)
            .length;
      }
      rethrow;
    }
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
                              ? Center(child: Text(AppLocaleKeys.chatNoEmployees.tr))
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
                                GestureDetector(
                                  onTap: _showAddChatDialog,
                                  child: Container(
                                    width: 45,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: Color(0xff00A389),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(Icons.add, color: Colors.white),
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
                            subtitle: Text(AppLocaleKeys.chatGroupConversation.tr),
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
                                        displayName = ch['title'] ?? AppLocaleKeys.chatDepartmentGroup.tr;
                                        subtitle =
                                            '${'chat.group_prefix'.tr} ${ch['lastMessage'] ?? ''}';
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
                                        log(_otherUserId.toString());
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
                                          final ref = _firestore
                                              .collection('chats')
                                              .doc(chatId);
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
                                          _messagesStream =
                                              ref
                                                  .collection('messages')
                                                  .orderBy(
                                                    'timestamp',
                                                    descending: true,
                                                  )
                                                  .snapshots();
                                          log(_otherUserId.toString());

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
                                                          (_, __, ___) =>
                                                              Text(
                                                                initial,
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .black,
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
                                        trailing: FutureBuilder(
                                          future: getUnreadCount(
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
                                            CircleAvatar(
                                              radius: 28,
                                              backgroundColor:
                                                  Colors.grey.shade200,
                                              child: Text(
                                                _initialFromName(
                                                  _getSelectedChatNameSync(),
                                                ),
                                              ),
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
                                              : AppLocaleKeys.chatPrivateType.tr,
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
                                                              AppLocaleKeys.chatNoMessages.tr,
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
                                                                AppLocaleKeys.chatSenderFallback.tr;

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
                                                                    messageText(
                                                                      d['text'] ??
                                                                          '',
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
                                            child: Row(
                                              children: [
                                                // Emoji button
                                                IconButton(
                                                  icon: Icon(
                                                    Icons
                                                        .sentiment_satisfied_alt_outlined,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _isEmojiVisible =
                                                          !_isEmojiVisible;
                                                      FocusScope.of(
                                                        context,
                                                      ).unfocus();
                                                    });
                                                  },
                                                ),
                                                InkWell(
                                                  onTap: () async {
                                                    await controller.pickoneImage().then((
                                                      v,
                                                    ) async {
                                                      if (v.isNotEmpty) {
                                                        await controller
                                                            .uploadFiles(
                                                              filePathOrBytes:
                                                                  v
                                                                      .first
                                                                      .bytes!,
                                                              fileName:
                                                                  v.first.name,
                                                            );

                                                        _messageController
                                                            .text = controller
                                                                .uploadedFilesPaths
                                                                .last;
                                                        _sendMessage();
                                                        controller
                                                            .uploadedFilesPaths
                                                            .clear();
                                                      }
                                                    });
                                                  },
                                                  child: Icon(
                                                    Icons.attach_file,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: TextField(
                                                    controller:
                                                        _messageController,
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          AppLocaleKeys.chatWriteMessage.tr,
                                                      filled: true,
                                                      fillColor:
                                                          Colors.grey.shade100,
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
                                                const SizedBox(width: 8),

                                                GestureDetector(
                                                  onTap: _sendMessage,
                                                  child: Container(
                                                    width: 45,
                                                    height: 45,
                                                    decoration: BoxDecoration(
                                                      color: Color(0xff465FFF),
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

final urlRegex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
Widget messageText(String text, bool isme) {
  final matches = urlRegex.allMatches(text);

  if (matches.isEmpty) {
    // رسالة عادية
    return Text(
      text,
      style: TextStyle(fontSize: 15, color: isme ? Colors.white : Colors.black),
    );
  }

  // رسالة فيها لينك
  return RichText(
    text: TextSpan(
      children: buildMessageSpans(text),
      style: TextStyle(fontSize: 15, color: Colors.black),
    ),
  );
}

bool isImageUrl(String url) {
  return url.toLowerCase().endsWith('.png') ||
      url.toLowerCase().endsWith('.jpg') ||
      url.toLowerCase().endsWith('.jpeg') ||
      url.toLowerCase().endsWith('.gif') ||
      url.toLowerCase().endsWith('.webp');
}

List<InlineSpan> buildMessageSpans(String text) {
  final spans = <InlineSpan>[];
  int lastIndex = 0;

  for (final match in urlRegex.allMatches(text)) {
    // نص قبل الرابط
    if (match.start > lastIndex) {
      spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
    }

    final url = match.group(0)!;

    if (isImageUrl(url)) {
      // 👇 لو الرابط صورة
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Image.network(
                  url,
                  width: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, w, p) {
                    if (p == null) return w;
                    return SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder:
                      (_, __, ___) => Icon(Icons.broken_image, size: 40),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // 👇 رابط عادي
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer:
              TapGestureRecognizer()
                ..onTap = () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
        ),
      );
    }

    lastIndex = match.end;
  }

  // النص بعد آخر عنصر
  if (lastIndex < text.length) {
    spans.add(TextSpan(text: text.substring(lastIndex)));
  }

  return spans;
}
