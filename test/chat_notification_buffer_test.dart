import 'package:flutter_test/flutter_test.dart';
import 'package:point/Services/notifications/ChatStore.dart';
import 'package:point/Services/notifications/Models.dart';
import 'package:point/Services/notifications/chat_notification_format.dart';
import 'package:point/Services/firestore/firestore_chat_api.dart';

StoredMessage _msg({
  required String id,
  required int ts,
  String text = 'hi',
  String sender = 'Ada',
}) {
  return StoredMessage(
    messageId: id,
    text: text,
    sender: sender,
    senderId: 'u_$id',
    timestamp: ts,
  );
}

void main() {
  group('ChatNotificationFormat', () {
    test('prefixes sender for group lines', () {
      expect(
        ChatNotificationFormat.senderLine(sender: 'Ada', text: 'hello'),
        'Ada: hello',
      );
    });

    test('returns text when sender is empty', () {
      expect(
        ChatNotificationFormat.senderLine(sender: '  ', text: 'hello'),
        'hello',
      );
    });

    test('uses i18n template placeholders', () {
      expect(
        ChatNotificationFormat.senderLine(
          sender: 'Ada',
          text: 'hi',
          template: '@sender — @text',
        ),
        'Ada — hi',
      );
    });
  });

  group('ChatStore prune and append', () {
    final store = ChatStore.instance;

    test('pruneReadMessages drops timestamps at or before lastReadAtMs', () {
      final buffer = StoredChatBuffer(
        chatId: 'c1',
        lastReadAtMs: 0,
        messages: [
          _msg(id: 'a', ts: 100),
          _msg(id: 'b', ts: 200),
          _msg(id: 'c', ts: 300),
        ],
      );
      final pruned = ChatStore.pruneReadMessages(buffer, 200);
      expect(pruned.lastReadAtMs, 200);
      expect(pruned.messages.map((m) => m.messageId), ['c']);
    });

    test('appendMessage ignores already-read and keeps last 5 unread', () {
      final seed = StoredChatBuffer(
        chatId: 'c1',
        lastReadAtMs: 150,
        chatTitle: 'Team',
        isGroupChat: true,
        messages: [
          _msg(id: 'old', ts: 100),
          _msg(id: 'keep', ts: 200),
        ],
      );
      final next = store.appendMessage(
        buffer: seed,
        message: _msg(id: 'new', ts: 250, text: 'later'),
        lastReadAtMs: 150,
      );
      expect(next.messages.map((m) => m.messageId), ['keep', 'new']);
      expect(next.lastReadAtMs, 150);
      expect(next.isGroupChat, isTrue);
    });

    test('append of already-read message yields empty buffer', () {
      final seed = StoredChatBuffer(
        chatId: 'c1',
        lastReadAtMs: 500,
        messages: [_msg(id: 'old', ts: 100)],
      );
      final next = store.appendMessage(
        buffer: seed,
        message: _msg(id: 'stale', ts: 400),
        lastReadAtMs: 500,
      );
      expect(next.messages, isEmpty);
    });
  });

  group('FirestoreChatApi.lastReadAtMsFromChatData', () {
    test('reads millisecond int field', () {
      const uid = 'emp1';
      final data = <String, dynamic>{
        FirestoreChatApi.lastReadAtField(uid): 1700000000000,
      };
      expect(FirestoreChatApi.lastReadAtMsFromChatData(data, uid), 1700000000000);
    });

    test('returns 0 when missing', () {
      expect(
        FirestoreChatApi.lastReadAtMsFromChatData(const {}, 'emp1'),
        0,
      );
    });
  });
}
