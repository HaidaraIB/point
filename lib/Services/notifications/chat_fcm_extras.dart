/// FCM `data` extras for [chat_message] so devices can aggregate and prune.
Map<String, String> chatMessageFcmExtras({
  required String chatId,
  required String chatTitle,
  required String chatDisplayName,
  required String senderName,
  required String senderId,
  required String messageId,
  required bool isGroup,
  int? timestampMs,
}) {
  return <String, String>{
    'chatId': chatId.trim(),
    'chatTitle': chatTitle,
    'chatDisplayName': chatDisplayName,
    'senderName': senderName,
    'senderId': senderId.trim(),
    'messageId': messageId.trim(),
    'timestamp': '${timestampMs ?? DateTime.now().millisecondsSinceEpoch}',
    'isGroup': isGroup ? '1' : '0',
  };
}
