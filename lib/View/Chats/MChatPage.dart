import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
// يجب أن يكون هذا الملف متاحًا لديك، وإلا سيعطي خطأ
import 'package:point/Controller/HomeController.dart';
// يجب أن يكون هذا الملف متاحًا لديك، وإلا سيعطي خطأ
import 'package:point/Services/FireStoreServices.dart';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:point/View/Chats/ChatPage.dart';

// تعريف ثوابت الأدوار
const String _kRoleAdmin = 'accountholder';
const String _kRoleSupervisor = 'supervisor';

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

  // local caches
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserDept;

  List<Map<String, dynamic>> _employees = []; // all employees
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<Map<String, dynamic>> _groupParticipants = [];

  List<Map<String, dynamic>> _chats = []; // chats list for current user

  bool _loadingEmployees = true;
  bool _loadingChats = true;
  bool _isLoadingGroup = false;

  @override
  void initState() {
    super.initState();
    _initUserThenLoad();
  }

  // يتم استدعاؤها عند تغيير الشاشة إلى وضع الـ Full Screen
  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _listenChats(); // إعادة الاستماع في حالة الحاجة إلى تحديث
  // }

  Future<void> _initUserThenLoad() async {
    final homecontroller = Get.find<HomeController>();
    if (homecontroller.currentemployee.value != null) {
      _currentUserId = homecontroller.currentemployee.value?.id;
      _currentUserName =
          homecontroller.currentemployee.value?.name ??
          homecontroller.currentemployee.value?.email ??
          'Me';
      _currentUserDept = homecontroller.currentemployee.value?.department;
    } else {
      _currentUserId = 'temp_current_user';
      _currentUserName = 'Me';
      _currentUserDept = null;
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
                'dept': data['department'] ?? '',
                'role': data['role'] ?? '',
              };
            })
            .toList();
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
      final empRole = emp['role'] as String;

      final isSameDept = empDept == deptGroupName;

      final isSpecialRole =
          empRole == _kRoleAdmin || empRole == _kRoleSupervisor;

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
        'title': deptGroupName.tr,
        'participants': participantsIds,
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
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
    if (mounted) setState(() {});
  }

  // ---------------- Chats (Private & Group) ----------------
  void _listenChats() {
    if (_currentUserId == null) return;

    _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .listen((snap) {
          _chats.clear();
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
            _chats.add(chat);
          }

          _loadingChats = false;
          if (mounted) setState(() {});
        });
  }

  // ---------------- Navigation ----------------
  // لفتح محادثة فردية أو إنشاءها والانتقال لشاشة الرسائل
  Future<void> _openOrCreateChatWith(Map<String, dynamic> otherEmployee) async {
    if (_currentUserId == null) return;
    final otherUserId = otherEmployee['id'] as String;

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
        'isGroup': false,
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
    Get.to(
      () => MessageScreen(
        chat: selectedChatData,
        currentUserId: _currentUserId!,
        currentUserName: _currentUserName!,
        otherUserId: otherUserId,
      ),
    );
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
        'displayName': chatData['title'] ?? 'مجموعة القسم',
      };

      // الانتقال إلى شاشة الرسائل (MessageScreen)
      Get.to(
        () => MessageScreen(
          chat: selectedChatData,
          currentUserId: _currentUserId!,
          currentUserName: _currentUserName!,
          otherUserId: null, // لا يوجد طرف آخر محدد في المجموعة
        ),
      );
    }
  }

  // لفتح محادثة موجودة والانتقال لشاشة الرسائل
  void _openExistingChat(Map<String, dynamic> chat) async {
    String displayName;
    String? otherId;

    if (chat['isGroup'] == true) {
      displayName = chat['title'] ?? 'مجموعة غير معروفة';
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
              : (otherId.length > 10 ? 'مستخدم مجهول' : otherId);
    }

    final selectedChatData = Map<String, dynamic>.from(chat)
      ..['displayName'] = displayName;

    // الانتقال إلى شاشة الرسائل (MessageScreen)
    Get.to(
      () => MessageScreen(
        chat: selectedChatData,
        currentUserId: _currentUserId!,
        currentUserName: _currentUserName!,
        otherUserId: otherId,
      ),
    );
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
                      'اختيار موظف لبدء محادثة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم الموظف',
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
                              ? Center(child: Text('لا يوجد موظفين'))
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

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60.0), // تعيين حجم الـ AppBar
            child: AppBar(
              title: const Text('المحادثات'),
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
                                hintText: 'ابحث في المحادثات',
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
                          GestureDetector(
                            onTap: _showAddChatDialog,
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: const Color(0xff00A389),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(Icons.add, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // **عرض مجموعة القسم أولاً**
                  if (_currentUserDept != null && _currentUserDept!.isNotEmpty)
                    FutureBuilder<int>(
                      future: getUnreadCount(
                        'group_$_currentUserDept',
                        _currentUserId ?? '',
                      ),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        final groupChatData = _chats.firstWhere(
                          (c) => c['id'] == 'group_$_currentUserDept',
                          orElse: () => {},
                        );
                        if (groupChatData.isEmpty)
                          return const SizedBox.shrink(); // لو لم يتم تحميلها بعد

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
                            'مجموعة ${_currentUserDept!.tr}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          subtitle: Text(
                            groupChatData['lastMessage'] ??
                                'محادثة جماعية للقسم',
                          ),
                          trailing:
                              unreadCount > 0
                                  ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
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
                  if (_isLoadingGroup)
                    const Center(child: LinearProgressIndicator()),

                  // chats list
                  Expanded(
                    child:
                        _loadingChats
                            ? const Center(child: CircularProgressIndicator())
                            : _chats.isEmpty
                            ? const Center(
                              child: Text('لا توجد محادثات حالياً'),
                            )
                            : ListView.builder(
                              itemCount: _chats.length,
                              itemBuilder: (context, index) {
                                final ch = _chats[index];
                                final isGroup = ch['isGroup'] ?? false;
                                final chatId = ch['id'] as String;

                                // تخطي عرض مجموعة القسم مرة أخرى إذا تم عرضها بالفعل في الأعلى
                                if (isGroup &&
                                    chatId == 'group_$_currentUserDept') {
                                  return const SizedBox.shrink();
                                }

                                String displayName;
                                String initial;
                                Color avatarColor;
                                IconData? avatarIcon;
                                Color? titleColor;

                                if (isGroup) {
                                  displayName = ch['title'] ?? 'مجموعة';
                                  initial = _initialFromName(displayName);
                                  avatarColor = Colors.blueGrey.shade100;
                                  avatarIcon = Icons.group;
                                  titleColor = Colors.blue.shade700;
                                } else {
                                  // محادثة فردية
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
                                              ? 'مستخدم مجهول'
                                              : otherId);
                                  initial = _initialFromName(displayName);
                                  avatarColor = Colors.grey.shade200;
                                  avatarIcon = null;
                                  titleColor = Colors.black;
                                }

                                return FutureBuilder<int>(
                                  future: getUnreadCount(
                                    chatId,
                                    _currentUserId ?? '',
                                  ),
                                  builder: (context, snapshot) {
                                    final unreadCount = snapshot.data ?? 0;
                                    return ListTile(
                                      onTap: () => _openExistingChat(ch),
                                      leading: CircleAvatar(
                                        radius: 24,
                                        backgroundColor: avatarColor,
                                        child:
                                            avatarIcon != null
                                                ? Icon(
                                                  avatarIcon,
                                                  color: Colors.blueGrey,
                                                )
                                                : Text(
                                                  initial,
                                                  style: const TextStyle(
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
                                      subtitle: Text(
                                        ch['lastMessage'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing:
                                          unreadCount > 0
                                              ? Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
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
                              },
                            ),
                  ),
                ],
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

  const MessageScreen({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.currentUserName,
    this.otherUserId,
  });

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isEmojiVisible = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;
  late String _chatId;
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chat['id'];
    _displayName = widget.chat['displayName'] ?? 'محادثة';
    _messagesStream =
        _firestore
            .collection('chats')
            .doc(_chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .snapshots();

    _markMessagesAsRead(_chatId);
  }

  // -----------// داخل الميثود send message بتاعتك
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final isGroup = widget.chat['isGroup'] ?? false;
    final chatRef = _firestore.collection('chats').doc(_chatId);
    final msgRef = chatRef.collection('messages').doc();

    await msgRef.set({
      'senderId': widget.currentUserId,
      'senderName': widget.currentUserName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await chatRef.update({
      'lastMessage': text,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
    if (mounted)
      setState(() {
        _isEmojiVisible = false;
      }); // إخفاء الإيموجي بعد الإرسال

    // إرسال إشعار:
    if (!isGroup && widget.otherUserId != null) {
      await FirestoreServices.sendFcm(
        userId: widget.otherUserId ?? '',
        title: '${widget.currentUserName}',
        body: text,
      );
    } else if (isGroup) {
      final participants = List<String>.from(widget.chat['participants'] ?? []);
      for (var id in participants) {
        if (id != widget.currentUserId) {
          await FirestoreServices.sendFcm(
            userId: id,
            title: '${widget.currentUserName} في مجموعة ${_displayName}',
            body: text,
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
              .where('senderId', isNotEqualTo: widget.currentUserId)
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
            .where((d) => d.data()['senderId'] != widget.currentUserId)
            .toList();
        for (var doc in toMark) {
          await doc.reference.update({'isRead': true});
        }
      } else {
        rethrow;
      }
    }
    // يجب استدعاء setState في شاشة القائمة لتحديث عداد الرسائل غير المقروءة هناك
    // لكن هذا يتطلب تمرير دالة تحديث، ولأجل التبسيط نتركها لـ listener الخاص بشاشة القائمة
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'منذ ثوانٍ';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
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
        title: Text(
          _displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
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
                      return const Center(child: Text('ابدأ محادثتك الأولى!'));
                    }

                    final messages = snapshot.data!.docs;

                    return ListView.builder(
                      reverse: true, // لعرض الرسائل الأحدث في الأسفل
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index].data();
                        final isMe = msg['senderId'] == widget.currentUserId;
                        final senderName = msg['senderName'] ?? 'مجهول';
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
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: messageText(
                                    msg['text'] ?? 'رسالة فارغة',
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

            // 2. إدخال الرسالة والإيموجي
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  // زر الإيموجي
                  IconButton(
                    icon: Icon(
                      _isEmojiVisible ? Icons.keyboard : Icons.emoji_emotions,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      if (_isEmojiVisible) {
                        FocusScope.of(context).unfocus(); // إخفاء لوحة المفاتيح
                      } else {
                        FocusScope.of(
                          context,
                        ).requestFocus(FocusNode()); // إظهار لوحة المفاتيح
                      }
                      setState(() {
                        _isEmojiVisible = !_isEmojiVisible;
                      });
                    },
                  ),
                  // حقل إدخال الرسالة
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        border: InputBorder.none,
                      ),
                      onTap: () {
                        if (_isEmojiVisible) {
                          setState(() {
                            _isEmojiVisible = false;
                          });
                        }
                      },
                    ),
                  ),
                  // زر الإرسال
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xff00A389)),
                    onPressed: _sendMessage,
                  ),
                ],
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
          print('Minimize button pressed');
        },
      ),
    );
  }
}
*/
