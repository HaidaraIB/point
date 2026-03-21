import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/EmployeeModel.dart';


/// نموذج بيانات الرسالة
class ChatMessage {
  final String senderId;
  final String content;
  final DateTime timestamp;
  final bool isGroup;

  ChatMessage({
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.isGroup,
  });

  factory ChatMessage.fromFirestore(Map<String, dynamic> data) {
    return ChatMessage(
      senderId: data['senderId'] as String,
      content: data['content'] as String,
      // التعامل مع قيمة null إذا لم يتم تعيين التوقيت بعد الإرسال
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isGroup: data['isGroup'] as bool? ?? false,
    );
  }
}

// ----------------------------------------------------------------------
// 2. متحكم الشات (ChatController)
// ----------------------------------------------------------------------

/// **ملاحظة هامة:** يجب أن تقوم بتهيئة بيانات الموظف الحالي (`currentUser`)
/// بطريقة صحيحة في تطبيقك، غالبًا عبر `Get.find<HomeController>().employee.value`.
/// هنا استخدمنا متغير افتراضي.
// ----------------------------------------------------------------------
EmployeeModel getFakeCurrentUser() {
  // هذا الموظف الافتراضي يجب استبداله بالموظف الفعلي المسجل دخوله
  return Get.find<HomeController>().currentemployee.value ??
      EmployeeModel(
        name: 'name',
        email: 'email',
        role: 'cat1',
        status: 'status',
        createdAt: DateTime.now(),
      ); // أو department آخر
}

class ChatController extends GetxController {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final EmployeeModel currentUser = getFakeCurrentUser();

  RxList<EmployeeModel> allEmployees = <EmployeeModel>[].obs;
  RxList<String> departmentGroups = <String>[].obs;

  Rx<EmployeeModel?> currentOpenChatUser = Rx<EmployeeModel?>(null);
  Rx<String?> currentOpenChatGroup = Rx<String?>(null);
  RxList<ChatMessage> currentChatMessages = <ChatMessage>[].obs;

  StreamSubscription? chatSubscription;

  @override
  void onInit() {
    super.onInit();
    fetchAllEmployeesAndGroups();
  }

  @override
  void onClose() {
    chatSubscription?.cancel();
    super.onClose();
  }

  String getP2PRoomId(String user1Id, String user2Id) {
    List<String> ids = [user1Id, user2Id];
    ids.sort();
    return ids.join('_');
  }

  Future<void> fetchAllEmployeesAndGroups() async {
    try {
      final snapshot = await firestore.collection('employees').get();

      allEmployees.assignAll(
          snapshot.docs
              .map(
                (doc) => EmployeeModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .where((e) => e.id != currentUser.id)
              .toList());

      final allDepartments =
          allEmployees.map((e) => e.department).where((d) => d != null).toSet();

      // منطق المجموعات: المسؤول والمشرف يرى جميع الأقسام
      if (currentUser.role == 'admin' ||
          currentUser.role == 'supervisor' ||
          currentUser.role == 'accountholder') {
        departmentGroups.assignAll(allDepartments.cast<String>().toList());
      }
      // الموظف العادي يرى قسمه فقط
      else if (currentUser.department != null) {
        departmentGroups.assignAll([currentUser.department!]);
      } else {
        departmentGroups.clear();
      }
    } catch (e) {
      print('Error fetching employees/groups from Firestore: $e');
    }
  }

  void openChat(EmployeeModel? user, String? groupName) {
    chatSubscription?.cancel();
    chatSubscription = null;

    currentOpenChatUser.value = user;
    currentOpenChatGroup.value = groupName;
    currentChatMessages.clear();

    String chatRoomId;

    if (user != null) {
      chatRoomId = getP2PRoomId(currentUser.id!, user.id!);
    } else if (groupName != null) {
      chatRoomId = groupName; // اسم القسم هو ID الغرفة الجماعية
    } else {
      return;
    }

    chatSubscription = firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            currentChatMessages.assignAll(
                snapshot.docs
                    .map((doc) => ChatMessage.fromFirestore(doc.data()))
                    .toList());
          },
          onError: (error) {
            print("Error listening to chat messages: $error");
          },
        );
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final String? recipientId = currentOpenChatUser.value?.id;
    final String? groupName = currentOpenChatGroup.value;

    String chatRoomId;
    bool isGroupChat;

    if (recipientId != null) {
      chatRoomId = getP2PRoomId(currentUser.id!, recipientId);
      isGroupChat = false;
    } else if (groupName != null) {
      chatRoomId = groupName;
      isGroupChat = true;
    } else {
      return;
    }

    final messageData = {
      'senderId': currentUser.id,
      'content': content.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'isGroup': isGroupChat,
    };

    try {
      await firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);
    } catch (e) {
      print('Error sending message to Firebase: $e');
    }
  }

  void closeChat() {
    chatSubscription?.cancel();
    chatSubscription = null;
    currentOpenChatUser.value = null;
    currentOpenChatGroup.value = null;
    currentChatMessages.clear();
  }
}

// ----------------------------------------------------------------------
// 3. واجهة المستخدم (FloatingChatSystem)
// ----------------------------------------------------------------------

/// الـ Widget الرئيسي لنظام الشات العائم. يجب وضعه في الـ Stack الرئيسي
/// لصفحة الويب الخاصة بك.
class FloatingChatSystem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (Get.context != null && Get.isRegistered<ChatController>() == false) {
      Get.put(ChatController());
    }

    return GetBuilder<ChatController>(
      builder: (controller) {
        return Stack(
          children: [
            // 1. قائمة الشات الجانبية (Sidebar)
            Positioned(right: 0, top: 0, bottom: 0, child: ChatSidebar()),

            // 2. نافذة الشات العائمة (Pop-up Window)
            Obx(() {
              if (controller.currentOpenChatUser.value != null ||
                  controller.currentOpenChatGroup.value != null) {
                return Positioned(
                  bottom: 20,
                  right: 320, // موضع الـ Pop-up بجانب الـ Sidebar
                  child: ChatPopUpWindow(controller),
                );
              }
              return Container();
            }),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------
// A. ويدجيت قائمة المحادثات (Sidebar)
class ChatSidebar extends StatelessWidget {
  final ChatController controller = Get.find<ChatController>();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      color: Colors.white,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)],
      ),
      child: Column(
        children: [
          _buildHeader('newchat.sidebar_chats'.tr),
          Expanded(
            child: ListView(
              children: [
                _buildListHeader('newchat.sidebar_dept_groups'.tr),
                Obx(
                  () => Column(
                    children:
                        controller.departmentGroups.map((groupName) {
                          return ListTile(
                            title: Text(
                              'newchat.group_title'.trParams({
                                'name': groupName,
                              }),
                            ),
                            leading: Icon(Icons.group, color: Colors.orange),
                            onTap: () => controller.openChat(null, groupName),
                          );
                        }).toList(),
                  ),
                ),
                Divider(),
                _buildListHeader('newchat.sidebar_employees'.tr),
                Obx(
                  () => Column(
                    children:
                        controller.allEmployees.map((employee) {
                          return ListTile(
                            title: Text(
                              employee.name ?? 'employee.fallback_name'.tr,
                            ),
                            subtitle: Text(
                              employee.department ??
                                  'newchat.no_department'.tr,
                            ),
                            leading: CircleAvatar(
                              backgroundImage:
                                  employee.image != null
                                      ? NetworkImage(employee.image!)
                                      : null,
                              child:
                                  employee.image == null
                                      ? Icon(Icons.person)
                                      : null,
                            ),
                            onTap: () => controller.openChat(employee, null),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.blue.shade50,
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildListHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }
}

// -----------------------------------------------------
// B. ويدجيت نافذة الشات العائمة (Pop-up Window)
class ChatPopUpWindow extends StatefulWidget {
  final ChatController controller;

  ChatPopUpWindow(this.controller);

  @override
  State<ChatPopUpWindow> createState() => _ChatPopUpWindowState();
}

class _ChatPopUpWindowState extends State<ChatPopUpWindow> {
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    String title =
        widget.controller.currentOpenChatUser.value?.name ??
        (widget.controller.currentOpenChatGroup.value != null
            ? 'newchat.group_title'.trParams({
                'name':
                    widget.controller.currentOpenChatGroup.value ?? '',
              })
            : 'chat.conversation_fallback'.tr);

    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      child: Column(
        children: [
          _buildChatHeader(title),
          Expanded(
            child: Obx(
              () => ListView.builder(
                reverse: true,
                itemCount: widget.controller.currentChatMessages.length,
                itemBuilder: (context, index) {
                  final message = widget.controller.currentChatMessages[index];
                  final isMe =
                      message.senderId == widget.controller.currentUser.id;
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 220),
                      padding: EdgeInsets.all(10),
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue.shade400 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatHeader(String title) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              // زر الإغلاق (Close)
              InkWell(
                onTap: widget.controller.closeChat,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'chat.write_message'.tr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 15),
              ),
              onSubmitted: (text) {
                if (text.isNotEmpty) {
                  widget.controller.sendMessage(text);
                  _messageController.clear();
                }
              },
            ),
          ),
          SizedBox(width: 5),
          IconButton(
            icon: Icon(Icons.send, color: Colors.blue.shade600),
            onPressed: () {
              final text = _messageController.text;
              if (text.isNotEmpty) {
                widget.controller.sendMessage(text);
                _messageController.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 4. مثال على كيفية استخدام النظام في صفحة رئيسية (Main Page Example)
// ----------------------------------------------------------------------

/// **ملاحظة:** ضع الـ Widget `FloatingChatSystem()` كعنصر أخير داخل الـ `Stack`
/// في الصفحة الرئيسية للموقع.
// /*
class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('newchat.web_home'.tr)),
      body: Stack(
        children: [
          // 1. محتوى الصفحة الرئيسية يظهر هنا.
          Container(
            padding: EdgeInsets.only(
              right: 300,
            ), // هام: لترك مساحة للشات Sidebar
            child: Center(
              child: Text(
                'newchat.demo_body'.tr,
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),

          // 2. نظام الشات العائم (يجب أن يكون العنصر الأخير ليكون فوق الجميع)
          FloatingChatSystem(),
        ],
      ),
    );
  }
}

// */
