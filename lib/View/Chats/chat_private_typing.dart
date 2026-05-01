import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:point/Localization/AppLocaleKeys.dart';

/// How long since the last heartbeat we still show “typing…”
const Duration kChatTypingStale = Duration(seconds: 6);

/// Writes lightweight typing heartbeats for 1:1 chats only (`chats/{id}/typing/{myUserId}`).
class PrivateChatTypingWriter {
  PrivateChatTypingWriter(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>>? _ref;
  Timer? _debounce;
  Timer? _heartbeat;

  /// Call when switching chats or leaving a private thread.
  void rebind({
    required String? chatId,
    required String myUserId,
    required bool isGroup,
  }) {
    _debounce?.cancel();
    _debounce = null;
    _stopHeartbeat();

    final DocumentReference<Map<String, dynamic>>? next =
        (!isGroup &&
            chatId != null &&
            chatId.isNotEmpty &&
            myUserId.isNotEmpty)
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
    final ref = _ref;
    if (ref == null) return;
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      _stopHeartbeat();
      unawaited(_deleteDoc(ref));
      return;
    }
    unawaited(_pulse(ref));
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_pulse(ref));
    });
    _heartbeat ??= Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pulse(ref));
    });
  }

  Future<void> clearTyping() async {
    _debounce?.cancel();
    _debounce = null;
    _stopHeartbeat();
    final ref = _ref;
    if (ref != null) {
      await _deleteDoc(ref);
    }
  }

  Future<void> dispose() => clearTyping();

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _pulse(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.set(
        <String, dynamic>{
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> _deleteDoc(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.delete();
    } catch (_) {}
  }
}

/// Telegram/WhatsApp-style strip on the side of incoming messages ([AlignmentDirectional.start]).
class PrivateChatTypingStrip extends StatefulWidget {
  const PrivateChatTypingStrip({
    super.key,
    required this.otherUserTypingRef,
  });

  final DocumentReference<Map<String, dynamic>>? otherUserTypingRef;

  @override
  State<PrivateChatTypingStrip> createState() => _PrivateChatTypingStripState();
}

class _PrivateChatTypingStripState extends State<PrivateChatTypingStrip> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  int? _lastMs;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() {});
    });
    _attach(widget.otherUserTypingRef);
  }

  @override
  void didUpdateWidget(PrivateChatTypingStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.otherUserTypingRef?.path !=
        widget.otherUserTypingRef?.path) {
      _attach(widget.otherUserTypingRef);
    }
  }

  void _attach(DocumentReference<Map<String, dynamic>>? ref) {
    _sub?.cancel();
    _lastMs = null;
    if (ref == null) {
      _sub = null;
      return;
    }
    _sub = ref.snapshots().listen(
      (snap) {
        if (!mounted) return;
        final data = snap.data();
        if (data == null) {
          setState(() => _lastMs = null);
          return;
        }
        final raw = data['updatedAtMs'];
        final ms = raw is int ? raw : (raw is num ? raw.toInt() : null);
        setState(() => _lastMs = ms);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _lastMs = null);
      },
    );
  }

  bool _isFresh(int? ms) {
    if (ms == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - ms <= kChatTypingStale.inMilliseconds;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.otherUserTypingRef == null || !_isFresh(_lastMs)) {
      return const SizedBox.shrink();
    }
    var label = AppLocaleKeys.chatTyping.tr;
    final lang = Get.locale?.languageCode.toLowerCase() ?? '';
    if (lang == 'en') {
      label = label.toLowerCase();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 12, bottom: 2),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Material(
          color: Colors.white,
          elevation: 0,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _TypingDots(),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_c.value + i * 0.2) % 1.0;
            final wave = t < 0.5 ? t * 2 : (1 - t) * 2;
            final opacity = (0.35 + 0.65 * wave).clamp(0.35, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
