import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:point/Utils/app_log.dart';
import 'ChatAudioFocus.dart';
import 'audio_tab_visibility.dart';

/// Centralized web-safe notification sound using a shared [AudioPlayer], plus
/// dedicated players for **in-chat** receive/send cues (different assets from
/// [playNotificationSound], which runs when the conversation is not in the foreground).
///
/// **Why `unlockAudio()` exists (web):** Browsers block audio until there has been
/// a user gesture (tap/click). Calling [play] once from that gesture "unlocks" the
/// audio context so later programmatic playback of the same asset is allowed.
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  /// Keys كما في [pubspec] (مسار كامل تحت `assets/`).
  static String get _bundleAssetKey => 'assets/sounds/notification_chat.wav';
  static String get _activeIncomingAsset => 'assets/sounds/chat_message_in.wav';
  static String get _activeOutgoingAsset => 'assets/sounds/chat_message_out.wav';
  static const Duration _minPlayInterval = Duration(seconds: 1);
  static const Duration _minActivePlayInterval = Duration(milliseconds: 300);

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _activeIncomingPlayer = AudioPlayer();
  final AudioPlayer _activeOutgoingPlayer = AudioPlayer();

  bool _activeIncomingPreloaded = false;
  bool _activeOutgoingPreloaded = false;
  DateTime? _lastActiveIncomingAt;
  DateTime? _lastActiveOutgoingAt;

  bool _preloaded = false;
  bool _audioUnlocked = false;

  /// Ensures we only run the unlock sequence once per session (first user interaction).
  bool _unlockAttemptFinished = false;

  DateTime? _lastPlayAt;

  static const Duration _setSourceTimeout = Duration(seconds: 12);

  /// يحمّل بايتات الأصل كما في الـ AssetManifest (`assets/...`).
  ///
  /// على الويب، [AssetManager.getAssetUrl] يضيف مجلد `assets/` أمام المفتاح؛ إذا
  /// كان المفتاح `assets/sounds/x` يصبح المسار `assets/assets/sounds/x` (انظر
  /// `flutter_web_sdk` …/asset_manager.dart). أحياناً يفشل [rootBundle.load] أو
  /// يعيد 404؛ نجرّب نفس المسار عبر HTTP ثم مساراً بديلاً.
  Future<ByteData> _loadAssetBytes(String manifestKey) async {
    if (kIsWeb) {
      final rest =
          manifestKey.startsWith('assets/')
              ? manifestKey.substring('assets/'.length)
              : manifestKey;
      final candidates = <Uri>[
        Uri.base.resolve('assets/assets/$rest'),
        Uri.base.resolve('assets/$rest'),
      ];
      for (final uri in candidates) {
        try {
          final r = await http.get(uri);
          if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
            return ByteData.sublistView(Uint8List.fromList(r.bodyBytes));
          }
        } catch (_) {}
      }
    }
    return rootBundle.load(manifestKey);
  }

  /// Loads the asset into the player. On web, call only after a user gesture
  /// (e.g. [unlockAudio]); awaiting [setSource] in [main] can hang until a ~30s timeout.
  ///
  /// **Web:** [audioplayers_web] يحوّل [BytesSource] إلى `data:` URI ويستخدم
  /// `mimeType ?? 'audio/mpeg'`. WAV بدون `mimeType: audio/wav` يُفسَّر كـ MP3
  /// فيفشل التشغيل (MEDIA_ELEMENT_ERROR 4).
  Future<void> _ensureSourceLoaded() async {
    if (_preloaded) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    final key = _bundleAssetKey;
    final bd = await _loadAssetBytes(key);
    final bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
    final mime =
        key.toLowerCase().endsWith('.wav') ? 'audio/wav' : 'audio/mpeg';
    await _player
        .setSource(BytesSource(bytes, mimeType: mime))
        .timeout(_setSourceTimeout);
    _preloaded = true;
  }

  /// Optional eager load (mobile/desktop). Skipped for web in [main] — see [_ensureSourceLoaded].
  ///
  /// On native platforms, autoplay rules do not apply like in browsers: after a successful
  /// preload we mark audio as unlocked so [playNotificationSound] works before any pointer event.
  Future<void> initialize() async {
    if (_preloaded) {
      if (!kIsWeb) _audioUnlocked = true;
      return;
    }
    try {
      await _ensureSourceLoaded();
      if (!kIsWeb) _audioUnlocked = true;
    } catch (e, st) {
      if (kDebugMode) {
        appDebugPrint('AudioService.initialize failed: $e\n$st');
      }
      // يُعاد المحاولة عند unlock أو عند أول تشغيل.
    }
  }

  /// Call once from the first pointer/keyboard interaction (e.g. root [Listener]).
  /// Briefly plays at near-zero volume then stops, satisfying browser autoplay policies.
  Future<void> unlockAudio() async {
    if (_unlockAttemptFinished) return;
    _unlockAttemptFinished = true;
    try {
      await _ensureSourceLoaded();
    } catch (e) {
      _unlockAttemptFinished = false;
      if (kDebugMode) {
        appDebugPrint('AudioService: failed to load source ($e)');
      }
      return;
    }

    try {
      await _player.setVolume(0.0001);
      await _player.seek(Duration.zero);
      await _player.resume();
      await _player.stop();
      await _player.setVolume(1.0);
      _audioUnlocked = true;
      // Warm in-chat WAV players so the first message after unlock plays on web.
      unawaited(_ensureActiveIncomingLoaded());
      unawaited(_ensureActiveOutgoingLoaded());
    } catch (e, st) {
      if (kDebugMode) {
        appDebugPrint('AudioService.unlockAudio gesture play failed: $e\n$st');
      }
      // Allow a later gesture to retry unlocking.
      _unlockAttemptFinished = false;
    }
  }

  bool _shouldPlayForIncomingChat(String chatId) {
    if (isBrowserTabHidden) return true;
    if (ChatAudioFocus.incomingTreatAsInChat(chatId)) return false;
    return true;
  }

  /// Plays the preloaded asset on the shared player if unlocked and throttling allows.
  /// Does not play when the user is already focused on [chatId] in a visible tab
  /// (optional behavior; tab background always allows sound).
  Future<void> playNotificationSound({required String chatId}) async {
    if (!_preloaded || !_audioUnlocked) return;
    if (!_shouldPlayForIncomingChat(chatId)) return;

    final now = DateTime.now();
    if (_lastPlayAt != null &&
        now.difference(_lastPlayAt!) < _minPlayInterval) {
      return;
    }
    _lastPlayAt = now;

    try {
      await _player.seek(Duration.zero);
      await _player.resume();
    } catch (e, st) {
      if (kDebugMode) {
        appDebugPrint('AudioService.playNotificationSound failed: $e\n$st');
      }
    }
  }

  Future<void> _ensureActiveIncomingLoaded() async {
    if (_activeIncomingPreloaded) return;
    await _activeIncomingPlayer.setReleaseMode(ReleaseMode.stop);
    final key = _activeIncomingAsset;
    final bd = await _loadAssetBytes(key);
    final bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
    final mime =
        key.toLowerCase().endsWith('.wav') ? 'audio/wav' : 'audio/mpeg';
    await _activeIncomingPlayer
        .setSource(BytesSource(bytes, mimeType: mime))
        .timeout(_setSourceTimeout);
    _activeIncomingPreloaded = true;
  }

  Future<void> _ensureActiveOutgoingLoaded() async {
    if (_activeOutgoingPreloaded) return;
    await _activeOutgoingPlayer.setReleaseMode(ReleaseMode.stop);
    final key = _activeOutgoingAsset;
    final bd = await _loadAssetBytes(key);
    final bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
    final mime =
        key.toLowerCase().endsWith('.wav') ? 'audio/wav' : 'audio/mpeg';
    await _activeOutgoingPlayer
        .setSource(BytesSource(bytes, mimeType: mime))
        .timeout(_setSourceTimeout);
    _activeOutgoingPreloaded = true;
  }

  /// Short cue while the user is **viewing** this chat (foreground) — not the push-style [playNotificationSound].
  Future<void> playActiveChatIncomingSound() async {
    if (!_audioUnlocked) return;
    try {
      await _ensureActiveIncomingLoaded();
    } catch (e, st) {
      if (kDebugMode) {
        appDebugPrint(
          'AudioService.playActiveChatIncomingSound preload: $e\n$st',
        );
      }
      return;
    }
    final now = DateTime.now();
    if (_lastActiveIncomingAt != null &&
        now.difference(_lastActiveIncomingAt!) < _minActivePlayInterval) {
      return;
    }
    _lastActiveIncomingAt = now;
    try {
      await _activeIncomingPlayer.seek(Duration.zero);
      await _activeIncomingPlayer.resume();
    } catch (e, st) {
      if (kDebugMode) {
        appDebugPrint('AudioService.playActiveChatIncomingSound: $e\n$st');
      }
    }
  }

  /// Short cue after the user sends a message while this chat is in the foreground.
  Future<void> playActiveChatOutgoingSound() async {
    if (!_audioUnlocked) return;
    try {
      await _ensureActiveOutgoingLoaded();
    } catch (e, st) {
      if (kDebugMode) {
        appDebugPrint(
          'AudioService.playActiveChatOutgoingSound preload: $e\n$st',
        );
      }
      return;
    }
    final now = DateTime.now();
    if (_lastActiveOutgoingAt != null &&
        now.difference(_lastActiveOutgoingAt!) < _minActivePlayInterval) {
      return;
    }
    _lastActiveOutgoingAt = now;
    try {
      await _activeOutgoingPlayer.seek(Duration.zero);
      await _activeOutgoingPlayer.resume();
    } catch (e, st) {
      if (kDebugMode) {
        appDebugPrint('AudioService.playActiveChatOutgoingSound: $e\n$st');
      }
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _activeIncomingPlayer.dispose();
    await _activeOutgoingPlayer.dispose();
  }
}
