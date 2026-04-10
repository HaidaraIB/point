import 'package:get/get.dart';

import 'package:point/Controller/HomeController.dart';

/// Tracks which chat conversation is currently in the foreground (user is viewing it).
/// Used to avoid playing an incoming-message sound when the user is already reading that chat
/// in the same browser tab.
class ChatAudioFocus {
  ChatAudioFocus._();

  static String? _foregroundChatId;

  /// [ChatPopup] registers here while expanded so routing does not rely on Rx timing.
  static final Set<String> _expandedPopupChatIds = <String>{};

  /// [ChatScreen] / [MessageScreen]: user is reading this thread in the main layout (not only a popup).
  static final Set<String> _mainLayoutOpenChatIds = <String>{};

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

  /// Call when a [ChatPopup] is expanded (not header-only).
  static void registerExpandedChatPopup(String chatId) {
    _expandedPopupChatIds.add(chatId);
  }

  /// Call when a [ChatPopup] is minimized or disposed.
  static void unregisterExpandedChatPopup(String chatId) {
    _expandedPopupChatIds.remove(chatId);
  }

  /// Call when [ChatScreen] or [MessageScreen] has an active conversation open.
  static void registerMainLayoutChatOpen(String chatId) {
    _mainLayoutOpenChatIds.add(chatId);
  }

  /// Call when leaving that conversation or disposing the screen.
  static void unregisterMainLayoutChatOpen(String chatId) {
    _mainLayoutOpenChatIds.remove(chatId);
  }

  static bool mainLayoutShowsChat(String chatId) =>
      _mainLayoutOpenChatIds.contains(chatId);

  /// Do not clear [foregroundChatId] if the split/main chat UI still shows [chatId].
  static void clearForegroundIfEqualsUnlessMainLayoutShows(String chatId) {
    if (_mainLayoutOpenChatIds.contains(chatId)) return;
    clearForegroundIfEquals(chatId);
  }

  /// Non-minimized desktop/web [ChatPopup] for [chatId] (explicit registration + [HomeController.openChats] fallback).
  static bool hasExpandedPopupFor(String chatId) {
    if (_expandedPopupChatIds.contains(chatId)) return true;
    if (!Get.isRegistered<HomeController>()) return false;
    final open = Get.find<HomeController>().openChats;
    for (var i = 0; i < open.length; i++) {
      final c = open[i];
      if (c.id == chatId && !c.minimized) return true;
    }
    return false;
  }

  /// Main chat focus **or** expanded popup **or** main [ChatScreen]/[MessageScreen] for [chatId].
  static bool incomingTreatAsInChat(String chatId) =>
      foregroundChatId == chatId ||
      hasExpandedPopupFor(chatId) ||
      _mainLayoutOpenChatIds.contains(chatId);
}
