import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/chat_voice_playback_service.dart';
import 'package:point/Utils/AppColors.dart';

String formatVoiceDuration(Duration d) {
  final total = d.inSeconds.clamp(0, 86400);
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

Duration voiceHintDuration(int? sec) {
  if (sec != null && sec > 0) return Duration(seconds: sec);
  return Duration.zero;
}

/// Voice player with seek bar and playback speed — chat bubbles and forms.
class VoiceMessageRow extends StatefulWidget {
  final String url;
  final int? durationSec;
  final bool isMe;

  /// Chat bubbles use a fixed width; forms pass [false] for full-width layout.
  final bool compact;

  const VoiceMessageRow({
    super.key,
    required this.url,
    this.durationSec,
    required this.isMe,
    this.compact = true,
  });

  @override
  State<VoiceMessageRow> createState() => _VoiceMessageRowState();
}

class _VoiceMessageRowState extends State<VoiceMessageRow> {
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final svc = Get.find<ChatVoicePlaybackService>();
      final isActive = svc.activeUrl.value == widget.url;
      final playing = isActive && svc.playing.value;
      final position = isActive ? svc.position.value : Duration.zero;
      final effectiveDur = isActive
          ? svc.effectiveDuration(widget.durationSec)
          : voiceHintDuration(widget.durationSec);
      final busy = isActive && svc.loadCount.value > 0;
      final err = isActive ? svc.playbackError.value : null;
      final speedLabel = svc.playbackSpeedLabel();

      final ms = effectiveDur.inMilliseconds;
      final canScrub = ms > 0;
      double sliderValue() {
        if (ms <= 0) return 0;
        if (_dragFraction != null) return _dragFraction!.clamp(0.0, 1.0);
        return (position.inMilliseconds / ms).clamp(0.0, 1.0);
      }

      final primary = widget.isMe
          ? Colors.white
          : Theme.of(context).colorScheme.onSurface;
      final secondary = widget.isMe
          ? Colors.white.withValues(alpha: 0.72)
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
      final track = widget.isMe
          ? Colors.white.withValues(alpha: 0.35)
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18);
      final progress = widget.isMe
          ? Colors.white.withValues(alpha: 0.92)
          : AppColors.primary;

      return Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = widget.compact
                ? 268.0
                : (constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 400.0);
            return ConstrainedBox(
              constraints: BoxConstraints(minWidth: 200, maxWidth: maxW),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: busy
                            ? Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primary,
                                  ),
                                ),
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => unawaited(
                                  svc.toggle(
                                    widget.url,
                                    durationHintSec: widget.durationSec,
                                  ),
                                ),
                                icon: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: primary,
                                  size: 34,
                                ),
                              ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 5,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                            activeTrackColor: progress,
                            inactiveTrackColor: track,
                            thumbColor: primary,
                            overlayColor: primary.withValues(alpha: 0.14),
                          ),
                          child: Slider(
                            value: sliderValue().clamp(0.0, 1.0),
                            onChanged: canScrub && isActive
                                ? (v) => setState(() => _dragFraction = v)
                                : null,
                            onChangeEnd: canScrub && isActive
                                ? (v) {
                                    setState(() => _dragFraction = null);
                                    unawaited(
                                      svc.seekToFraction(v, widget.durationSec),
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 44, end: 6),
                    child: Row(
                      children: [
                        Text(
                          formatVoiceDuration(
                            _dragFraction != null && ms > 0
                                ? Duration(
                                    milliseconds: (_dragFraction! * ms).round(),
                                  )
                                : position,
                          ),
                          style: TextStyle(fontSize: 11.5, color: secondary),
                        ),
                        const Spacer(),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => unawaited(svc.cyclePlaybackSpeed()),
                            borderRadius: BorderRadius.circular(6),
                            child: Tooltip(
                              message: AppLocaleKeys.chatVoicePlaybackSpeed.tr,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Text(
                                  speedLabel,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatVoiceDuration(effectiveDur),
                          style: TextStyle(fontSize: 11.5, color: secondary),
                        ),
                      ],
                    ),
                  ),
                  if (err != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        AppLocaleKeys.errorsServer.tr,
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isMe
                              ? Colors.orange.shade100
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}
