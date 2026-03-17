import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';

class ChatController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  RxList<Map<String, dynamic>> chats = <Map<String, dynamic>>[].obs;
  RxMap<String, dynamic>? selectedChat = RxMap<String, dynamic>({});
  RxString currentUserId =
      Get.find<HomeController>().currentemployee.value!.id!.obs;

  // 🟢 تحميل المحادثات الخاصة بالمستخدم
  void loadChats() {
    try {
      _db
          .collection('chats')
          .where('members', arrayContains: currentUserId.value)
          .snapshots()
          .listen((snapshot) async {
            chats.assignAll(await Future.wait(
              snapshot.docs.map((doc) async {
                final data = doc.data();
                var otherUserId = (data['members'] as List).firstWhere(
                  (id) => id != currentUserId.value,
                );
                log('########' + otherUserId.toString());
                // var userDoc =
                //     await _db.collection('employees').doc(otherUserId).get();
                return {
                  'id': doc.id,
                  // 'name': userDoc['name'],
                  'messages': [],
                  'otherUserId': otherUserId,
                };
              }),
            ));
          });
    } catch (e) {
      log(e.toString());
    }
  }

  // 🟡 تحميل الرسائل لمحادثة معينة
  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  // 🔵 إرسال رسالة
  Future<void> sendMessage(String chatId, String text) async {
    if (text.trim().isEmpty) return;
    await _db.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUserId.value,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _db.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastTime': FieldValue.serverTimestamp(),
    });
  }

  // 🟣 إنشاء محادثة جديدة
  Future<void> startChatWith(String otherUserId) async {
    final ids = [currentUserId.value, otherUserId]..sort();
    final chatId = ids.join('_');

    final chatDoc = _db.collection('chats').doc(chatId);
    final docSnapshot = await chatDoc.get();

    if (!docSnapshot.exists) {
      await chatDoc.set({
        'members': ids,
        'lastMessage': '',
        'lastTime': FieldValue.serverTimestamp(),
      });
    }

    loadChats();
  }
}
