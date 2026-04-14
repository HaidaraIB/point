import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

typedef OnChatImagePasted =
    Future<void> Function(Uint8List bytes, String mimeType);
typedef ShouldHandleChatPaste = bool Function();
typedef OnChatImagePasteError = void Function();

class ChatImagePasteListener {
  ChatImagePasteListener({
    required OnChatImagePasted onImagePasted,
    ShouldHandleChatPaste? shouldHandle,
    OnChatImagePasteError? onPasteError,
  }) : _onImagePasted = onImagePasted,
       _shouldHandle = shouldHandle,
       _onPasteError = onPasteError {
    final Element? root =
        window.document.documentElement ?? window.document.body;
    if (root != null) {
      _sub = root.onPaste.listen(_onPasteEvent);
    }
  }

  final OnChatImagePasted _onImagePasted;
  final ShouldHandleChatPaste? _shouldHandle;
  final OnChatImagePasteError? _onPasteError;
  StreamSubscription<ClipboardEvent>? _sub;
  bool _disposed = false;

  void _onPasteEvent(ClipboardEvent event) {
    if (_disposed) return;
    final dt = event.clipboardData;
    if (dt == null) return;
    final items = dt.items;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final mime = item.type;
      if (!mime.startsWith('image/')) continue;
      final file = item.getAsFile();
      if (file == null) continue;
      if (!(_shouldHandle?.call() ?? true)) return;
      event.preventDefault();
      Future.microtask(() => _readFileAndForward(file, mime));
      break;
    }
  }

  Future<void> _readFileAndForward(File file, String mime) async {
    try {
      final buffer = await file.arrayBuffer().toDart;
      final bytes = Uint8List.view(buffer.toDart);
      if (_disposed) return;
      if (bytes.isEmpty) {
        _onPasteError?.call();
        return;
      }
      await _onImagePasted(bytes, mime);
    } catch (_) {
      if (_disposed) return;
      _onPasteError?.call();
    }
  }

  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _sub = null;
  }
}
