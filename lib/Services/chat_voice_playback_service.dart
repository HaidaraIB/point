import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:point/Utils/app_log.dart';

/// Shared voice player for chat bubbles and task/timeline notes.
/// Uses [just_audio] (ExoPlayer on Android) so AAC/m4a notes play fully.
class ChatVoicePlaybackService extends GetxController {
  static const List<double> playbackSpeeds = [0.5, 1.0, 1.5, 2.0];

  final AudioPlayer _player = AudioPlayer();

  final RxnString activeUrl = RxnString();
  final RxDouble playbackSpeed = 1.0.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final RxBool playing = false.obs;
  final RxInt loadCount = 0.obs;
  final Rxn<Object> playbackError = Rxn<Object>();

  String? _loadedUrl;
  int? _hintSec;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void onInit() {
    super.onInit();

    _posSub = _player.positionStream.listen((d) {
      if (activeUrl.value == null) return;
      position.value = d;
    });
    _durSub = _player.durationStream.listen((d) {
      if (d == null || d <= Duration.zero) return;
      final hint = _hintSec;
      if (hint != null && hint > 0) {
        final hintMs = hint * 1000;
        final reportedMs = d.inMilliseconds;
        if (reportedMs < (hintMs * 0.75).round() ||
            reportedMs > (hintMs * 1.35).round()) {
          return;
        }
      }
      duration.value = d;
    });
    _stateSub = _player.playerStateStream.listen((s) {
      if (activeUrl.value == null) return;
      playing.value = s.playing;
      if (s.processingState == ProcessingState.completed) {
        playing.value = false;
        position.value = Duration.zero;
        unawaited(() async {
          try {
            await _player.seek(Duration.zero);
            await _player.pause();
          } catch (_) {}
        }());
      }
    });
  }

  @override
  void onClose() {
    unawaited(_posSub?.cancel());
    unawaited(_durSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_player.dispose());
    super.onClose();
  }

  Duration effectiveDuration(int? hintSec) {
    final h = hintSec ?? _hintSec;
    if (h != null && h > 0) return Duration(seconds: h);
    if (duration.value > Duration.zero) return duration.value;
    return Duration.zero;
  }

  Future<void> toggle(String url, {int? durationHintSec}) async {
    playbackError.value = null;
    if (activeUrl.value == url) {
      if (playing.value) {
        await _player.pause();
        return;
      }
      await _ensurePlaying(url, durationHintSec);
      return;
    }
    await _switchToUrl(url, durationHintSec);
  }

  Future<void> _switchToUrl(String url, int? durationHintSec) async {
    try {
      await _player.stop();
    } catch (_) {}
    activeUrl.value = url;
    _hintSec = durationHintSec;
    _loadedUrl = null;
    position.value = Duration.zero;
    if (durationHintSec != null && durationHintSec > 0) {
      duration.value = Duration(seconds: durationHintSec);
    } else {
      duration.value = Duration.zero;
    }
    await _ensurePlaying(url, durationHintSec);
  }

  String playbackSpeedLabel([double? speed]) {
    final v = speed ?? playbackSpeed.value;
    if (v == v.roundToDouble()) return '${v.toInt()}×';
    return '${v}×';
  }

  Future<void> cyclePlaybackSpeed() async {
    final speeds = playbackSpeeds;
    final i = speeds.indexOf(playbackSpeed.value);
    playbackSpeed.value = speeds[(i < 0 ? 0 : (i + 1) % speeds.length)];
    await _applyPlaybackSpeed();
  }

  Future<void> _applyPlaybackSpeed() async {
    try {
      await _player.setSpeed(playbackSpeed.value);
    } catch (e) {
      playbackError.value = e;
    }
  }

  Future<void> _loadSource(String url) async {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(trimmed)),
        preload: true,
      );
      return;
    }
    if (!kIsWeb) {
      await _player.setFilePath(trimmed);
      return;
    }
    await _player.setUrl(trimmed);
  }

  Future<void> _ensurePlaying(String url, int? hintSec) async {
    loadCount.value++;
    try {
      if (_loadedUrl != url) {
        await _loadSource(url);
        _loadedUrl = url;
        await _applyPlaybackSpeed();
      }
      // just_audio play() completes when playback ends — do not await it,
      // or VoiceMessageRow keeps showing a spinner for the whole note.
      unawaited(
        _player.play().catchError((Object e, StackTrace st) {
          appLog('Voice playback failed: $e', error: e, stackTrace: st);
          playbackError.value = e;
          playing.value = false;
          _loadedUrl = null;
        }),
      );
    } catch (e, st) {
      appLog('Voice load failed: $e', error: e, stackTrace: st);
      playbackError.value = e;
      playing.value = false;
      _loadedUrl = null;
    } finally {
      if (loadCount.value > 0) {
        loadCount.value = loadCount.value - 1;
      }
    }
  }

  Future<void> seekToFraction(double fraction, int? hintSec) async {
    final url = activeUrl.value;
    if (url == null) return;
    final dur = effectiveDuration(hintSec);
    final ms = dur.inMilliseconds;
    if (ms <= 0) return;
    final target = Duration(milliseconds: (fraction * ms).round());
    try {
      if (_loadedUrl != url) {
        await _loadSource(url);
        _loadedUrl = url;
      }
      await _player.seek(target);
      position.value = target;
    } catch (e) {
      playbackError.value = e;
    }
  }
}
