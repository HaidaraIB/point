/// Pure helpers for chat tray copy (safe to unit-test without plugins).
class ChatNotificationFormat {
  ChatNotificationFormat._();

  static const String senderLineTemplate = '@sender: @text';

  /// WhatsApp/Telegram-style line: `Sender: message`.
  ///
  /// [template] uses `@sender` and `@text` placeholders (from i18n).
  static String senderLine({
    required String sender,
    required String text,
    String template = senderLineTemplate,
  }) {
    final s = sender.trim();
    final t = text.trim();
    if (t.isEmpty) return s;
    if (s.isEmpty) return t;
    return template.replaceAll('@sender', s).replaceAll('@text', t);
  }

  static int maxInt(int a, int b) => a >= b ? a : b;
}
