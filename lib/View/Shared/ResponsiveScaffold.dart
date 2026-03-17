import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/View/Chats/ChatPage.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/SideMenu.dart';

class ResponsiveScaffold extends StatelessWidget {
  // final Widget sidebar;
  final Widget body;
  final int selectedtab;
  final int? subselected;
  final String title;
  final bool? sidemenue;
  ResponsiveScaffold({
    super.key,
    required this.body,
    this.title = '',
    this.subselected,
    this.sidemenue,
    required this.selectedtab,
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
                        if (sidemenue != false)
                          SizedBox(
                            child: CustomSidebar(
                              selectedtab: selectedtab,
                              subseletedtab: subselected,
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
                                        controller
                                            .currentemployee
                                            .value
                                            ?.name ??
                                        '',
                                    role:
                                        controller
                                            .currentemployee
                                            .value
                                            ?.role ??
                                        '',
                                    avatarUrl:
                                        controller.currentemployee.value?.image ?? kDefaultAvatarUrl,
                                    notificationCount: 1,
                                  ),
                                ),
                              ),
                              Expanded(child: body),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(bottom: 20, child: ChatOverlay()),
                  ],
                ),
              );
            } else {
              // شاشة صغيرة (موبايل)
              return Scaffold(
                appBar: PreferredSize(
                  preferredSize: Size(Get.width, 180),
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
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
                            if (sidemenue != false)
                              Builder(
                                builder:
                                    (context) => Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
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

                            // Center: Title / Subtitle (constrained to avoid overflow)
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'لوحة التحكم',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Obx(
                                        () {
                                          final name = controller.currentemployee.value?.name?.trim();
                                          final greeting = name != null && name.isNotEmpty
                                              ? 'أهلاً بك، $name 👋'
                                              : 'أهلاً بك 👋';
                                          return Text(
                                            greeting,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),

                            // Other side of title and drawer: profile widget (avatar + name/role + dropdown with logout)
                            const SizedBox(width: 8),
                            Obx(
                              () => MobileAppBarProfileWidget(
                                name: controller.currentemployee.value?.name ?? '',
                                role: controller.currentemployee.value?.role ?? '',
                                avatarUrl: controller.currentemployee.value?.image ?? kDefaultAvatarUrl,
                                isEmployee: true,
                                isClient: false,
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
                    selectedtab: selectedtab,
                    subseletedtab: subselected,
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

class ChatOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chats = Get.find<HomeController>().openChats;
      if (chats.isEmpty) return const SizedBox();

      return Row(
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

class _ChatPopupState extends State<ChatPopup> {
  Offset offset = Offset.zero;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;
  late String _chatId;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chatId = widget.chat.id;
    _messagesStream =
        _firestore
            .collection('chats')
            .doc(_chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .snapshots();

    // _markMessagesAsRead(_chatId);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return AnimatedContainer(
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
              controller.toggleMinimize(widget.chat.id, !widget.chat.minimized);
              controller.clearUnread(widget.chat.id);
            },
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.chat.name,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  /// 🔔 Badge
                  if (widget.chat.unreadCount > 0)
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

                  InkWell(
                    onTap: () => controller.closeChat(widget.chat.id),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!widget.chat.minimized) ...[
            /// BODY
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
                        final isMe =
                            msg['senderId'] ==
                            controller.currentemployee.value?.id;
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
                                if (!isMe)
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

            /// INPUT
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
                  // /
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
                        // if (_isEmojiVisible) {
                        //   setState(() {
                        //     _isEmojiVisible = false;
                        //   });
                        // }
                      },
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await controller.pickoneImage().then((v) async {
                        if (v.isNotEmpty && v.first.bytes != null) {
                          await controller.uploadFiles(
                            filePathOrBytes: v.first.bytes!,
                            fileName: v.first.name,
                          );

                          _messageController.text =
                              controller.uploadedFilesPaths.last;
                          _sendMessage();
                          controller.uploadedFilesPaths.clear();
                        }
                      });
                    },
                    child: Icon(Icons.attach_file),
                  ),
                  // زر الإرسال
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xff00A389)),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final chatRef = _firestore.collection('chats').doc(_chatId);
    final msgRef = chatRef.collection('messages').doc();

    await msgRef.set({
      'senderId': Get.find<HomeController>().currentemployee.value?.id,
      'senderName': Get.find<HomeController>().currentemployee.value?.name,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await chatRef.update({
      'lastMessage': text,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
    // if (mounted)
    //   setState(() {
    //     _isEmojiVisible = false;
    //   }); // إخفاء الإيموجي بعد الإرسال

    // إرسال إشعار:
    // if (!isGroup && widget.otherUserId != null) {
    //   await FirestoreServices.sendFcm(
    //     userId: widget.otherUserId ?? '',
    //     title: '${widget.currentUserName}',
    //     body: text,
    //   );
    // } else if (isGroup) {
    //   final participants = List<String>.from(widget.chat['participants'] ?? []);
    //   for (var id in participants) {
    //     if (id != widget.currentUserId) {
    //       await FirestoreServices.sendFcm(
    //         userId: id,
    //         title: '${widget.currentUserName} في مجموعة ${_displayName}',
    //         body: text,
    //       );
    //     }
    //   }
    // }
  }
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
