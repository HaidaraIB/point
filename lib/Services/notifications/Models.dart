class StoredMessage {
  const StoredMessage({
    required this.messageId,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.senderId = '',
  });

  final String messageId;
  final String text;
  final String sender;
  final String senderId;
  final int timestamp;

  factory StoredMessage.fromMap(Map<String, dynamic> map) {
    final messageId = map['messageId']?.toString().trim() ?? '';
    final text = map['text']?.toString() ?? '';
    final sender = map['sender']?.toString() ?? '';
    final senderId =
        (map['senderId'] ?? map['sender_id'])?.toString().trim() ?? '';
    final rawTs = map['timestamp'];
    final timestamp = rawTs is int
        ? rawTs
        : int.tryParse(rawTs?.toString() ?? '') ?? 0;
    return StoredMessage(
      messageId: messageId,
      text: text,
      sender: sender,
      senderId: senderId,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'messageId': messageId,
      'text': text,
      'sender': sender,
      'senderId': senderId,
      'timestamp': timestamp,
    };
  }
}

class StoredChatBuffer {
  const StoredChatBuffer({
    required this.chatId,
    required this.messages,
    this.chatTitle = '',
    this.isGroupChat = false,
    this.lastReadAtMs = 0,
  });

  final String chatId;
  final String chatTitle;
  final List<StoredMessage> messages;
  final bool isGroupChat;

  /// Messages with [StoredMessage.timestamp] at or before this are treated as read.
  final int lastReadAtMs;

  factory StoredChatBuffer.empty(String chatId) {
    return StoredChatBuffer(chatId: chatId, messages: const <StoredMessage>[]);
  }

  factory StoredChatBuffer.fromMap(Map<String, dynamic> map) {
    final chatId = map['chatId']?.toString().trim() ?? '';
    final chatTitle = map['chatTitle']?.toString() ?? '';
    final rawGroup = map['isGroupChat'] ?? map['is_group_chat'];
    final isGroupChat = rawGroup == true ||
        rawGroup == 1 ||
        rawGroup?.toString().trim().toLowerCase() == 'true' ||
        rawGroup?.toString().trim() == '1';
    final rawLastRead = map['lastReadAtMs'] ?? map['last_read_at_ms'];
    final lastReadAtMs = rawLastRead is int
        ? rawLastRead
        : int.tryParse(rawLastRead?.toString() ?? '') ?? 0;
    final rawMessages = map['messages'];
    final messages = <StoredMessage>[];
    if (rawMessages is List) {
      for (final item in rawMessages) {
        if (item is Map) {
          messages.add(
            StoredMessage.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return StoredChatBuffer(
      chatId: chatId,
      chatTitle: chatTitle,
      isGroupChat: isGroupChat,
      lastReadAtMs: lastReadAtMs < 0 ? 0 : lastReadAtMs,
      messages: messages,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'chatId': chatId,
      'chatTitle': chatTitle,
      'isGroupChat': isGroupChat,
      'lastReadAtMs': lastReadAtMs,
      'messages': messages.map((e) => e.toMap()).toList(growable: false),
    };
  }
}
