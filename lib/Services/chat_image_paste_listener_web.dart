// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
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
  }) : _onImagePasted = onImagePasted,
       _shouldHandle = shouldHandle,
       _onPasteError = onPasteError {
    _sub = html.document.onPaste.listen(_onPasteEvent);
  }

  final OnChatImagePasted _onImagePasted;
  final ShouldHandleChatPaste? _shouldHandle;
  final OnChatImagePasteError? _onPasteError;
  StreamSubscription<html.Event>? _sub;
  bool _disposed = false;

  void _onPasteEvent(html.Event event) {
    if (_disposed || event is! html.ClipboardEvent) return;
    final dt = event.clipboardData;
    final items = dt?.items;
    if (items == null) return;

    final length = items.length ?? 0;
    for (var i = 0; i < length; i++) {
      final item = items[i];
      final mime = item.type ?? '';
      if (!mime.startsWith('image/')) continue;
      final file = item.getAsFile();
      if (file == null) continue;
      if (!(_shouldHandle?.call() ?? true)) return;
      event.preventDefault();
      Future.microtask(() => _readFileAndForward(file, mime));
      break;
    }
  }

  Future<void> _readFileAndForward(html.File file, String mime) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
        return;
      }
      if (result is Uint8List) {
        completer.complete(result);
        return;
      }
      completer.completeError(StateError('Unsupported pasted image payload'));
    });
    reader.onError.listen((_) {
      completer.completeError(StateError('Failed reading pasted image'));
    });

    reader.readAsArrayBuffer(file);
    try {
      final bytes = await completer.future;
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
