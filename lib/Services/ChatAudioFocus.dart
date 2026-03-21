/// Tracks which chat conversation is currently in the foreground (user is viewing it).
/// Used to avoid playing an incoming-message sound when the user is already reading that chat
/// in the same browser tab.
class ChatAudioFocus {
  ChatAudioFocus._();

  static String? _foregroundChatId;

  static String? get foregroundChatId => _foregroundChatId;

  static void setForeground(String chatId) {
    _foregroundChatId = chatId;
  }

  static void clearForeground() {
    _foregroundChatId = null;
  }

  /// Avoid clearing focus if another surface (e.g. another popup) became active.
  static void clearForegroundIfEquals(String chatId) {
    if (_foregroundChatId == chatId) {
      _foregroundChatId = null;
    }
  }
}
