import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:point/Services/notifications/Models.dart';
import 'package:point/Utils/app_log.dart';

class ChatStore {
  ChatStore._();

  static final ChatStore instance = ChatStore._();
  static const String _boxName = 'chat_notification_buffers_v1';
  static const int maxMessagesPerChat = 5;

  static bool _hiveReady = false;
  Box<dynamic>? _box;

  Future<void> init() async {
    if (_box?.isOpen == true) return;
    await _ensureHiveReady();
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Future<StoredChatBuffer> loadBuffer(String chatId) async {
    final normalized = chatId.trim();
    if (normalized.isEmpty) return StoredChatBuffer.empty('');

    try {
      await init();
      final raw = _box?.get(normalized);
      if (raw is Map) {
        final parsed = StoredChatBuffer.fromMap(Map<String, dynamic>.from(raw));
        if (parsed.chatId.isEmpty || parsed.chatId != normalized) {
          throw const FormatException('invalid chat buffer shape');
        }
        return _normalizeBuffer(parsed);
      }
    } catch (e, st) {
      appLog('ChatStore.loadBuffer failed chat_id=$normalized: $e\n$st');
      await _safeDeleteCorruptBuffer(normalized);
    }

    return StoredChatBuffer.empty(normalized);
  }

  Future<void> saveBuffer(StoredChatBuffer buffer) async {
    final normalized = _normalizeBuffer(buffer);
    if (normalized.chatId.isEmpty) return;
    try {
      await init();
      await _box?.put(normalized.chatId, normalized.toMap());
    } catch (e, st) {
      appLog('ChatStore.saveBuffer failed chat_id=${normalized.chatId}: $e\n$st');
    }
  }

  Future<void> clearChat(String chatId) async {
    final normalized = chatId.trim();
    if (normalized.isEmpty) return;
    try {
      await init();
      await _box?.delete(normalized);
    } catch (e, st) {
      appLog('ChatStore.clearChat failed chat_id=$normalized: $e\n$st');
    }
  }

  StoredChatBuffer appendMessage({
    required StoredChatBuffer buffer,
    required StoredMessage message,
    String? chatTitle,
    bool? isGroupChat,
  }) {
    final chatId = buffer.chatId.trim();
    if (chatId.isEmpty) return buffer;

    final seen = <String>{};
    final merged = <StoredMessage>[
      ...buffer.messages,
      message,
    ].where((item) {
      final id = item.messageId.trim();
      if (id.isEmpty || seen.contains(id)) return false;
      seen.add(id);
      return true;
    }).toList(growable: true);

    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (merged.length > maxMessagesPerChat) {
      merged.removeRange(0, merged.length - maxMessagesPerChat);
    }

    final nextTitle = (chatTitle ?? '').trim().isNotEmpty
        ? chatTitle!.trim()
        : buffer.chatTitle;
    final nextGroup = isGroupChat ?? buffer.isGroupChat;
    return StoredChatBuffer(
      chatId: chatId,
      chatTitle: nextTitle,
      isGroupChat: nextGroup,
      messages: merged,
    );
  }

  StoredChatBuffer _normalizeBuffer(StoredChatBuffer buffer) {
    final chatId = buffer.chatId.trim();
    final seen = <String>{};
    final valid = <StoredMessage>[];
    for (final m in buffer.messages) {
      final id = m.messageId.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      valid.add(
        StoredMessage(
          messageId: id,
          text: m.text,
          sender: m.sender.trim(),
          timestamp: m.timestamp,
        ),
      );
    }
    valid.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (valid.length > maxMessagesPerChat) {
      valid.removeRange(0, valid.length - maxMessagesPerChat);
    }
    return StoredChatBuffer(
      chatId: chatId,
      chatTitle: buffer.chatTitle,
      isGroupChat: buffer.isGroupChat,
      messages: valid,
    );
  }

  Future<void> _safeDeleteCorruptBuffer(String chatId) async {
    try {
      await init();
      await _box?.delete(chatId);
    } catch (_) {}
  }

  Future<void> _ensureHiveReady() async {
    if (_hiveReady) return;
    final Directory dir = await getApplicationSupportDirectory();
    Hive.init(dir.path);
    _hiveReady = true;
  }
}
