import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/Utils/AppNotificationInbox.dart';
import 'package:point/Services/ChatAudioFocus.dart';
import 'package:point/Services/ChatIncomingMessageSound.dart';
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/View/Chats/MChatPage.dart';
import 'package:point/View/Chats/chat_message_display.dart';
import 'package:point/View/Chats/chat_voice_record_button.dart';
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
                    Positioned(bottom: 20, child: ChatOverlay()),
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
                                    count:
                                        controller.totalUnreadMessages.value,
                                    onTap: () {
                                      Get.to(
                                        () => ChatsListScreen(
                                          onMinimize: () {},
                                        ),
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messageSoundSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _markReadSubscription;
  late String _chatId;
  final TextEditingController _messageController = TextEditingController();

  void _syncPopupSoundAndFocus() {
    _messageSoundSubscription?.cancel();
    _messageSoundSubscription = null;
    _markReadSubscription?.cancel();
    _markReadSubscription = null;
    final uid = Get.find<HomeController>().currentemployee.value?.id;
    final stream = _messagesStream;
    if (stream == null || uid == null) {
      ChatAudioFocus.clearForegroundIfEquals(_chatId);
      if (uid != null) {
        unawaited(FirestoreServices.syncEmployeeActiveChatId(uid, null));
      }
      return;
    }
    if (!widget.chat.minimized) {
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
      unawaited(
        FirestoreServices.markIncomingMessagesReadInChat(_chatId, uid),
      );
    } else {
      ChatAudioFocus.clearForegroundIfEquals(_chatId);
      unawaited(FirestoreServices.syncEmployeeActiveChatId(uid, null));
    }
  }

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

    _syncPopupSoundAndFocus();
  }

  @override
  void didUpdateWidget(ChatPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.minimized != widget.chat.minimized) {
      _syncPopupSoundAndFocus();
    }
  }

  @override
  void dispose() {
    _messageSoundSubscription?.cancel();
    _markReadSubscription?.cancel();
    ChatAudioFocus.clearForegroundIfEquals(_chatId);
    final uid = Get.find<HomeController>().currentemployee.value?.id;
    if (uid != null) {
      unawaited(FirestoreServices.syncEmployeeActiveChatId(uid, null));
    }
    _messageController.dispose();
    super.dispose();
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
                      return Center(child: Text('chat.start_first'.tr));
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
                        final senderName =
                            msg['senderName'] ?? 'chat.unknown_sender'.tr;
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
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'chat.write_message'.tr,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.image_outlined, size: 20),
                    onPressed: () async {
                      final v = await controller.pickoneImage();
                      if (v.isEmpty || v.first.bytes == null) return;
                      final url = await controller.uploadFiles(
                        filePathOrBytes: v.first.bytes!,
                        fileName: v.first.name,
                      );
                      if (url == null) return;
                      final cap = _messageController.text.trim();
                      await _sendChatPayload(
                        lastMessagePreview: cap.isNotEmpty ? cap : '📷',
                        messageType: 'image',
                        text: cap,
                        attachmentUrl: url,
                      );
                      _messageController.clear();
                      controller.uploadedFilesPaths.clear();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, size: 20),
                    onPressed: () async {
                      final v = await controller.pickOneChatFile();
                      if (v.isEmpty || v.first.bytes == null) return;
                      final url = await controller.uploadFiles(
                        filePathOrBytes: v.first.bytes!,
                        fileName: v.first.name,
                      );
                      if (url == null) return;
                      await _sendChatPayload(
                        lastMessagePreview: v.first.name,
                        messageType: 'file',
                        text: '',
                        attachmentUrl: url,
                        fileName: v.first.name,
                      );
                      controller.uploadedFilesPaths.clear();
                    },
                  ),
                  ChatVoiceRecordButton(
                    onUploaded: (url, sec) async {
                      await _sendChatPayload(
                        lastMessagePreview: '🎤',
                        messageType: 'voice',
                        text: url,
                        attachmentUrl: url,
                        durationSec: sec > 0 ? sec : null,
                      );
                    },
                  ),
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
    await _sendChatPayload(
      lastMessagePreview: text,
      messageType: 'text',
      text: text,
    );
    _messageController.clear();
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
    final me = hc.currentemployee.value;
    if (me?.id == null) return;

    final chatRef = _firestore.collection('chats').doc(_chatId);
    final msgRef = chatRef.collection('messages').doc();

    final payload = <String, dynamic>{
      'senderId': me!.id,
      'senderName': me.name ?? me.email ?? '',
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

    final chatSnap = await chatRef.get();
    final data = chatSnap.data() ?? {};
    final isGroup = data['isGroup'] == true;
    final participants = List<String>.from(data['participants'] ?? []);
    final title = data['title']?.toString() ?? widget.chat.name;

    if (!isGroup) {
      final others = participants.where((id) => id != me.id).toList();
      if (others.isNotEmpty) {
        await FirestoreServices.sendFcm(
          userId: others.first,
          title: me.name ?? me.email ?? '',
          body: lastMessagePreview,
          sendEmail: false,
          notificationType: 'chat_message',
          fcmDataExtras: {'chatId': _chatId},
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
            sendEmail: false,
            notificationType: 'chat_message',
            fcmDataExtras: {'chatId': _chatId},
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
    return 'common.minutes_ago'
        .trParams({'count': '${diff.inMinutes}'});
  } else if (diff.inHours < 24) {
    return 'common.hours_ago'.trParams({'count': '${diff.inHours}'});
  } else if (diff.inDays < 7) {
    return 'chat.days_ago'.trParams({'count': '${diff.inDays}'});
  } else {
    return DateFormat('dd/MM/yyyy').format(dt);
  }
}
