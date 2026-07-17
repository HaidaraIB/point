import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:point/Services/chat_voice_cache.dart';

/// Single player for chat voice note bubbles. Survives when the message row
/// is disposed after scrolling off-screen ([ListView] / [ScrollablePositionedList]).
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
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  @override
  void onInit() {
    super.onInit();
    unawaited(_player.setReleaseMode(ReleaseMode.stop));

    _posSub = _player.onPositionChanged.listen((d) {
      if (activeUrl.value == null) return;
      position.value = d;
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (d <= Duration.zero) return;
      // Recorded voice notes pass a stopwatch hint; player metadata is often
      // wrong for fresh blobs (web WAV/webm, some AAC containers) and would
      // replace a correct 1m+ duration with a few seconds after first play.
      final hint = _hintSec;
      if (hint != null && hint > 0) {
        final hintMs = hint * 1000;
        final reportedMs = d.inMilliseconds;
        // Only adopt player duration when it roughly agrees with the hint.
        if (reportedMs < (hintMs * 0.75).round() ||
            reportedMs > (hintMs * 1.35).round()) {
          return;
        }
      }
      duration.value = d;
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      playing.value = s == PlayerState.playing;
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      playing.value = false;
      position.value = Duration.zero;
    });
  }

  @override
  void onClose() {
    unawaited(_posSub?.cancel());
    unawaited(_durSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_completeSub?.cancel());
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
    await _player.stop();
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
      await _player.setPlaybackRate(playbackSpeed.value);
    } catch (e) {
      playbackError.value = e;
    }
  }

  Future<void> _ensurePlaying(String url, int? hintSec) async {
    loadCount.value++;
    try {
      if (_loadedUrl != url) {
        final source = await ChatVoiceCache.sourceForUrl(url);
        await _player.play(source);
        _loadedUrl = url;
        await _applyPlaybackSpeed();
      } else {
        await _player.resume();
        await _applyPlaybackSpeed();
      }
    } catch (e) {
      playbackError.value = e;
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
        final source = await ChatVoiceCache.sourceForUrl(url);
        await _player.setSource(source);
        _loadedUrl = url;
      }
      await _player.seek(target);
      position.value = target;
    } catch (e) {
      playbackError.value = e;
    }
  }
}
