enum ChatAttachmentSaveLocation { gallery, downloads, userSelected }

class ChatAttachmentSaveResult {
  final bool ok;
  final ChatAttachmentSaveLocation? location;

  const ChatAttachmentSaveResult({required this.ok, this.location});

  static const fail = ChatAttachmentSaveResult(ok: false);
}
