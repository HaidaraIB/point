import 'dart:typed_data';

typedef OnChatImagePasted =
    Future<void> Function(Uint8List bytes, String mimeType);
typedef ShouldHandleChatPaste = bool Function();
typedef OnChatImagePasteError = void Function();

class ChatImagePasteListener {
  ChatImagePasteListener({
    required OnChatImagePasted onImagePasted,
    ShouldHandleChatPaste? shouldHandle,
    OnChatImagePasteError? onPasteError,
  });

  void dispose() {}
}
