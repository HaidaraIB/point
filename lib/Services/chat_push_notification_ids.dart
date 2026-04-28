/// Stable OS notification id per chat so [show] replaces the same tray entry.
///
/// Namespaced away from ad-hoc ids (e.g. test notifications use timestamps).
int localNotificationIdForChat(String chatId) {
  final t = chatId.trim();
  if (t.isEmpty) return 0x50000001;
  final h = t.hashCode;
  final positive = h & 0x7FFFFFFF;
  return 0x50000000 + (positive % 0x0F000000);
}
