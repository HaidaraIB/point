import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/View/Chats/chat_ui_helpers.dart';

/// How long since the last heartbeat we still show activity text.
const Duration kChatTypingStale = Duration(seconds: 6);

enum ChatActivityKind { typing, recording, uploading }

enum ChatUploadKind { image, video, file }

/// Parsed ephemeral activity from `chats/{id}/typing/{userId}`.
class ChatActivitySnapshot {
  final String userId;
  final ChatActivityKind kind;
  final ChatUploadKind? uploadKind;
  final int updatedAtMs;

  const ChatActivitySnapshot({
    required this.userId,
    required this.kind,
    this.uploadKind,
    required this.updatedAtMs,
  });
}

bool chatActivityIsFresh(int? updatedAtMs) {
  if (updatedAtMs == null) return false;
  final now = DateTime.now().millisecondsSinceEpoch;
  return now - updatedAtMs <= kChatTypingStale.inMilliseconds;
}

ChatActivitySnapshot? chatActivityFromDoc(String userId, Map<String, dynamic>? data) {
  if (data == null) return null;
  final raw = data['updatedAtMs'];
  final ms = raw is int ? raw : (raw is num ? raw.toInt() : null);
  if (!chatActivityIsFresh(ms)) return null;

  final kindRaw = (data['kind'] as String?)?.trim() ?? 'typing';
  ChatActivityKind kind;
  switch (kindRaw) {
    case 'recording':
      kind = ChatActivityKind.recording;
      break;
    case 'uploading':
      kind = ChatActivityKind.uploading;
      break;
    default:
      kind = ChatActivityKind.typing;
  }

  ChatUploadKind? uploadKind;
  final uploadRaw = (data['uploadKind'] as String?)?.trim();
  switch (uploadRaw) {
    case 'image':
      uploadKind = ChatUploadKind.image;
      break;
    case 'video':
      uploadKind = ChatUploadKind.video;
      break;
    case 'file':
      uploadKind = ChatUploadKind.file;
      break;
  }

  return ChatActivitySnapshot(
    userId: userId,
    kind: kind,
    uploadKind: uploadKind,
    updatedAtMs: ms!,
  );
}

String chatParticipantDisplayName(String userId, Map<String, String> nameById) {
  final fromMap = nameById[userId]?.trim();
  if (fromMap != null && fromMap.isNotEmpty) return fromMap;
  if (Get.isRegistered<HomeController>()) {
    final emp = Get.find<HomeController>().getEmployeeById(userId);
    final n = emp?.name?.trim();
    if (n != null && n.isNotEmpty) return n;
  }
  return AppLocaleKeys.chatUnknownUser.tr;
}

String chatActivityLabelForSnapshot(
  ChatActivitySnapshot activity, {
  required bool isGroup,
  required Map<String, String> participantNames,
}) {
  final name = chatParticipantDisplayName(activity.userId, participantNames);

  switch (activity.kind) {
    case ChatActivityKind.recording:
      return isGroup
          ? AppLocaleKeys.chatActivityGroupRecording.trParams({'name': name})
          : AppLocaleKeys.chatActivityRecording.tr;
    case ChatActivityKind.uploading:
      final uploadLabel = switch (activity.uploadKind) {
        ChatUploadKind.video => isGroup
            ? AppLocaleKeys.chatActivityGroupSendingVideo.trParams({'name': name})
            : AppLocaleKeys.chatActivitySendingVideo.tr,
        ChatUploadKind.file => isGroup
            ? AppLocaleKeys.chatActivityGroupSendingFile.trParams({'name': name})
            : AppLocaleKeys.chatActivitySendingFile.tr,
        _ => isGroup
            ? AppLocaleKeys.chatActivityGroupSendingPhoto.trParams({'name': name})
            : AppLocaleKeys.chatActivitySendingPhoto.tr,
      };
      return uploadLabel;
    case ChatActivityKind.typing:
      if (isGroup) {
        return AppLocaleKeys.chatActivityGroupTyping.trParams({'name': name});
      }
      var label = AppLocaleKeys.chatActivityTyping.tr;
      final lang = Get.locale?.languageCode.toLowerCase() ?? '';
      if (lang == 'en') {
        label = label.toLowerCase();
      }
      return label;
  }
}

String? chatActivityHeaderLabel({
  required bool isGroup,
  required List<ChatActivitySnapshot> activities,
  required Map<String, String> participantNames,
}) {
  if (activities.isEmpty) return null;

  final typing = activities.where((a) => a.kind == ChatActivityKind.typing).toList();
  if (typing.length >= 2) {
    typing.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    final lead = chatParticipantDisplayName(typing.first.userId, participantNames);
    return AppLocaleKeys.chatActivityGroupTypingMany.trParams({
      'name': lead,
      'count': '${typing.length - 1}',
    });
  }

  activities.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
  return chatActivityLabelForSnapshot(
    activities.first,
    isGroup: isGroup,
    participantNames: participantNames,
  );
}

/// Writes ephemeral activity heartbeats (`chats/{id}/typing/{myUserId}`).
class ChatActivityWriter {
  ChatActivityWriter(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>>? _ref;
  Timer? _debounce;
  Timer? _heartbeat;
  ChatActivityKind? _lockedKind;

  void rebind({
    required String? chatId,
    required String myUserId,
    required bool isGroup,
  }) {
    _debounce?.cancel();
    _debounce = null;
    _stopHeartbeat();
    _lockedKind = null;

    final DocumentReference<Map<String, dynamic>>? next =
        (chatId != null && chatId.isNotEmpty && myUserId.isNotEmpty)
        ? _firestore
            .collection('chats')
            .doc(chatId)
            .collection('typing')
            .doc(myUserId)
        : null;

    if (_ref?.path == next?.path) {
      _ref = next;
      return;
    }

    final old = _ref;
    _ref = next;
    if (old != null) {
      unawaited(_deleteDoc(old));
    }
  }

  void onComposerTextChanged(String text) {
    if (_lockedKind != null && _lockedKind != ChatActivityKind.typing) return;
    final ref = _ref;
    if (ref == null) return;
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      if (_lockedKind == ChatActivityKind.typing) {
        _lockedKind = null;
      }
      _stopHeartbeat();
      unawaited(_deleteDoc(ref));
      return;
    }
    _lockedKind = ChatActivityKind.typing;
    unawaited(_pulse(ref, kind: ChatActivityKind.typing));
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_pulse(ref, kind: ChatActivityKind.typing));
    });
    _heartbeat ??= Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pulse(ref, kind: ChatActivityKind.typing));
    });
  }

  void setRecording(bool active) {
    final ref = _ref;
    if (ref == null) return;
    if (!active) {
      if (_lockedKind == ChatActivityKind.recording) {
        _lockedKind = null;
        _stopHeartbeat();
        unawaited(_deleteDoc(ref));
      }
      return;
    }
    _debounce?.cancel();
    _lockedKind = ChatActivityKind.recording;
    unawaited(_pulse(ref, kind: ChatActivityKind.recording));
    _heartbeat ??= Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pulse(ref, kind: ChatActivityKind.recording));
    });
  }

  void setUploading(ChatUploadKind? kind) {
    final ref = _ref;
    if (ref == null) return;
    if (kind == null) {
      if (_lockedKind == ChatActivityKind.uploading) {
        _lockedKind = null;
        _stopHeartbeat();
        unawaited(_deleteDoc(ref));
      }
      return;
    }
    _debounce?.cancel();
    _lockedKind = ChatActivityKind.uploading;
    unawaited(_pulse(ref, kind: ChatActivityKind.uploading, uploadKind: kind));
    _heartbeat ??= Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pulse(ref, kind: ChatActivityKind.uploading, uploadKind: kind));
    });
  }

  Future<void> clearActivity() async {
    _debounce?.cancel();
    _debounce = null;
    _lockedKind = null;
    _stopHeartbeat();
    final ref = _ref;
    if (ref != null) {
      await _deleteDoc(ref);
    }
  }

  Future<void> clearTyping() => clearActivity();

  Future<void> dispose() => clearActivity();

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _pulse(
    DocumentReference<Map<String, dynamic>> ref, {
    required ChatActivityKind kind,
    ChatUploadKind? uploadKind,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'kind': kind.name,
      };
      if (kind == ChatActivityKind.uploading && uploadKind != null) {
        data['uploadKind'] = uploadKind.name;
      }
      await ref.set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _deleteDoc(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.delete();
    } catch (_) {}
  }
}

/// Back-compat alias used across chat screens.
typedef PrivateChatTypingWriter = ChatActivityWriter;

DocumentReference<Map<String, dynamic>>? chatOtherUserActivityRef({
  required FirebaseFirestore firestore,
  required String chatId,
  required String selfUserId,
  required List<String> participantIds,
  required bool isGroup,
}) {
  if (isGroup || chatId.isEmpty || selfUserId.isEmpty) return null;
  for (final id in participantIds) {
    if (id != selfUserId && id.isNotEmpty && id != 'N/A') {
      return firestore.collection('chats').doc(chatId).collection('typing').doc(id);
    }
  }
  return null;
}

CollectionReference<Map<String, dynamic>>? chatGroupActivityCollectionRef({
  required FirebaseFirestore firestore,
  required String chatId,
  required bool isGroup,
}) {
  if (!isGroup || chatId.isEmpty) return null;
  return firestore.collection('chats').doc(chatId).collection('typing');
}

/// Header subline: remote activity overrides presence (online / last seen / connected).
class ChatActivitySubline extends StatefulWidget {
  final String chatId;
  final bool isGroup;
  final String? otherUserId;
  final List<String> groupParticipantIds;
  final Map<String, String> participantNames;
  final String selfUserId;
  final bool allowEmpty;

  const ChatActivitySubline({
    super.key,
    required this.chatId,
    required this.isGroup,
    this.otherUserId,
    this.groupParticipantIds = const [],
    this.participantNames = const {},
    required this.selfUserId,
    this.allowEmpty = false,
  });

  @override
  State<ChatActivitySubline> createState() => _ChatActivitySublineState();
}

class _ChatActivitySublineState extends State<ChatActivitySubline> {
  StreamSubscription<dynamic>? _sub;
  List<ChatActivitySnapshot> _activities = const [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() {});
    });
    _attach();
  }

  @override
  void didUpdateWidget(ChatActivitySubline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId ||
        oldWidget.isGroup != widget.isGroup ||
        oldWidget.otherUserId != widget.otherUserId ||
        oldWidget.selfUserId != widget.selfUserId) {
      _attach();
    }
  }

  void _attach() {
    _sub?.cancel();
    _activities = const [];

    final firestore = FirebaseFirestore.instance;
    if (widget.isGroup) {
      final col = chatGroupActivityCollectionRef(
        firestore: firestore,
        chatId: widget.chatId,
        isGroup: true,
      );
      if (col == null) return;
      _sub = col.snapshots().listen((snap) {
        if (!mounted) return;
        final list = <ChatActivitySnapshot>[];
        for (final doc in snap.docs) {
          if (doc.id == widget.selfUserId) continue;
          final activity = chatActivityFromDoc(doc.id, doc.data());
          if (activity != null) list.add(activity);
        }
        setState(() => _activities = list);
      });
      return;
    }

    final parts = widget.otherUserId != null && widget.otherUserId!.isNotEmpty
        ? [widget.otherUserId!, widget.selfUserId]
        : widget.groupParticipantIds;
    final ref = chatOtherUserActivityRef(
      firestore: firestore,
      chatId: widget.chatId,
      selfUserId: widget.selfUserId,
      participantIds: parts,
      isGroup: false,
    );
    if (ref == null) return;
    _sub = ref.snapshots().listen((snap) {
      if (!mounted) return;
      final activity = chatActivityFromDoc(ref.id, snap.data());
      setState(() => _activities = activity == null ? const [] : [activity]);
    });
  }

  List<ChatActivitySnapshot> get _freshActivities {
    return _activities
        .where((a) => chatActivityIsFresh(a.updatedAtMs))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activityLabel = chatActivityHeaderLabel(
      isGroup: widget.isGroup,
      activities: _freshActivities,
      participantNames: widget.participantNames,
    );
    if (activityLabel != null) {
      return Text(
        activityLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF16A34A),
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return ChatPresenceSubline(
      isGroup: widget.isGroup,
      otherUserId: widget.otherUserId,
      groupParticipantIds: widget.groupParticipantIds,
      selfUserId: widget.selfUserId,
      allowEmpty: widget.allowEmpty,
    );
  }
}

/// Legacy composer typing strip — superseded by [ChatActivitySubline] in headers.
class PrivateChatTypingStrip extends StatelessWidget {
  const PrivateChatTypingStrip({super.key, required this.otherUserTypingRef});

  final DocumentReference<Map<String, dynamic>>? otherUserTypingRef;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
