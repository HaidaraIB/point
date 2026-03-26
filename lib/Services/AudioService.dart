import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'ChatAudioFocus.dart';
import 'audio_tab_visibility.dart';

/// Centralized web-safe notification sound using a single [AudioPlayer].
///
/// **Why `unlockAudio()` exists (web):** Browsers block audio until there has been
/// a user gesture (tap/click). Calling [play] once from that gesture "unlocks" the
/// audio context so later programmatic playback of the same asset is allowed.
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  /// Keys كما في [pubspec] (مسار كامل تحت `assets/`).
  static String get _bundleAssetKey => kIsWeb
      ? 'assets/sounds/notification_web.wav'
      : 'assets/sounds/notification_message.mp3';
  static const Duration _minPlayInterval = Duration(seconds: 1);

  final AudioPlayer _player = AudioPlayer();

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
      final rest = manifestKey.startsWith('assets/')
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
    final mime = key.toLowerCase().endsWith('.wav') ? 'audio/wav' : 'audio/mpeg';
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
        debugPrint('AudioService.initialize failed: $e\n$st');
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
        debugPrint('AudioService: failed to load source ($e)');
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
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AudioService.unlockAudio gesture play failed: $e\n$st');
      }
      // Allow a later gesture to retry unlocking.
      _unlockAttemptFinished = false;
    }
  }

  bool _shouldPlayForIncomingChat(String chatId) {
    if (isBrowserTabHidden) return true;
    if (ChatAudioFocus.foregroundChatId != chatId) return true;
    return false;
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
        debugPrint('AudioService.playNotificationSound failed: $e\n$st');
      }
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
