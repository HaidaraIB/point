import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/View/Shared/voice_message_row.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/voice_recording_file_bytes.dart';
import 'package:point/View/Chats/chat_private_typing.dart';
import 'package:record/record.dart';
import 'package:point/Utils/app_theme_extension.dart';

enum VoiceRecorderPhase { idle, recording, paused, uploading }

enum VoiceRecorderUsage { chat, form }

/// Shared recording logic for chat composer overlays and task forms.
class VoiceRecorderController extends ChangeNotifier {
  VoiceRecorderController({
    required this.scopeId,
    required this.usage,
    this.activityWriter,
    this.onSaved,
  });

  final String scopeId;
  final VoiceRecorderUsage usage;
  final ChatActivityWriter? activityWriter;
  final Future<void> Function(String url, int durationSec)? onSaved;

  final AudioRecorder _recorder = AudioRecorder();
  VoiceRecorderPhase _phase = VoiceRecorderPhase.idle;
  bool _finishing = false;
  final Stopwatch _activeSw = Stopwatch();
  Timer? _uiTimer;
  String? _recordPath;

  VoiceRecorderPhase get phase => _phase;
  bool get isActive =>
      _phase == VoiceRecorderPhase.recording ||
      _phase == VoiceRecorderPhase.paused ||
      _phase == VoiceRecorderPhase.uploading;

  RecordConfig get _recordConfig => kIsWeb
      ? const RecordConfig(encoder: AudioEncoder.wav)
      : const RecordConfig(encoder: AudioEncoder.aacLc);

  String get _uploadFileName => kIsWeb ? 'voice.wav' : 'voice.m4a';

  String formatDuration() {
    final totalSec = _activeSw.elapsed.inSeconds;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      notifyListeners();
    });
  }

  void _stopUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = null;
  }

  Future<void> startRecording() async {
    if (isActive) return;
    if (!await _recorder.hasPermission()) {
      if (usage == VoiceRecorderUsage.form) {
        FunHelper.showSnackbar(
          AppLocaleKeys.errorTitle.tr,
          'errors.no_permission'.tr,
          snackPosition: SnackPosition.BOTTOM,
          colorText: Colors.white,
          backgroundColor: Colors.red,
          autoHideAfter: const Duration(seconds: 4),
        );
      }
      return;
    }

    try {
      if (kIsWeb) {
        await _recorder.start(_recordConfig, path: '');
      } else {
        final dir = await getTemporaryDirectory();
        _recordPath =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(_recordConfig, path: _recordPath!);
      }
      _activeSw
        ..reset()
        ..start();
      _phase = VoiceRecorderPhase.recording;
      _startUiTimer();
      activityWriter?.setRecording(true);
      notifyListeners();
    } catch (_) {
      FunHelper.showSnackbar(
        AppLocaleKeys.errorTitle.tr,
        AppLocaleKeys.chatVoiceSaveFailed.tr,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
        backgroundColor: Colors.red,
        autoHideAfter: const Duration(seconds: 4),
      );
    }
  }

  Future<void> pauseRecording() async {
    if (_phase != VoiceRecorderPhase.recording) return;
    try {
      await _recorder.pause();
      _activeSw.stop();
      _phase = VoiceRecorderPhase.paused;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> resumeRecording() async {
    if (_phase != VoiceRecorderPhase.paused) return;
    try {
      await _recorder.resume();
      _activeSw.start();
      _phase = VoiceRecorderPhase.recording;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> discardRecording() async {
    if (!isActive || _finishing) return;
    try {
      await _recorder.cancel();
    } catch (_) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    _resetSession();
  }

  void _resetSession() {
    _stopUiTimer();
    _activeSw.stop();
    _activeSw.reset();
    _recordPath = null;
    _phase = VoiceRecorderPhase.idle;
    _finishing = false;
    activityWriter?.setRecording(false);
    notifyListeners();
  }

  Future<Uint8List?> _readRecordingBytes(
    String? pathFromStop,
    String? savedPath,
  ) async {
    if (pathFromStop == null || pathFromStop.isEmpty) return null;

    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse(pathFromStop));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      } catch (_) {}
      return null;
    }

    final tried = <String>{};
    for (final p in [pathFromStop, savedPath]) {
      if (p == null || p.isEmpty || tried.contains(p)) continue;
      tried.add(p);
      final bytes = await readVoiceRecordingFileBytes(p);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }
    return null;
  }

  Future<void> saveRecording() async {
    if (_phase != VoiceRecorderPhase.recording &&
        _phase != VoiceRecorderPhase.paused) {
      return;
    }
    if (_finishing) return;
    _finishing = true;
    _phase = VoiceRecorderPhase.uploading;
    notifyListeners();

    final savedPath = _recordPath;
    String? pathFromStop;
    try {
      pathFromStop = await _recorder.stop();
    } catch (_) {
      pathFromStop = null;
    }

    _stopUiTimer();
    _activeSw.stop();
    final sec = _activeSw.elapsed.inSeconds.clamp(1, 3600);
    _activeSw.reset();
    activityWriter?.setRecording(false);

    Uint8List? bytes;
    try {
      bytes = await _readRecordingBytes(pathFromStop, savedPath);
    } catch (_) {
      bytes = null;
    }

    if (bytes == null || bytes.isEmpty) {
      _finishing = false;
      _recordPath = null;
      _phase = VoiceRecorderPhase.idle;
      notifyListeners();
      FunHelper.showSnackbar(
        AppLocaleKeys.errorTitle.tr,
        AppLocaleKeys.chatVoiceSaveFailed.tr,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
        backgroundColor: Colors.red,
        autoHideAfter: const Duration(seconds: 4),
      );
      return;
    }

    final c = Get.find<HomeController>();
    try {
      activityWriter?.setUploading(ChatUploadKind.file);
      final url = await c.uploadFiles(
        filePathOrBytes: bytes,
        fileName: _uploadFileName,
        useBlockingUploadDialog: false,
        chatScopeId: scopeId,
      );
      if (url != null) {
        await onSaved?.call(url, sec);
        c.uploadedFilesPaths.clear();
      }
    } finally {
      activityWriter?.setUploading(null);
      _finishing = false;
      _recordPath = null;
      _phase = VoiceRecorderPhase.idle;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    if (_phase == VoiceRecorderPhase.recording ||
        _phase == VoiceRecorderPhase.paused) {
      unawaited(_recorder.cancel());
    }
    unawaited(_recorder.dispose());
    super.dispose();
  }
}

class VoiceRecorderScope extends InheritedNotifier<VoiceRecorderController> {
  const VoiceRecorderScope({
    super.key,
    required VoiceRecorderController controller,
    required super.child,
  }) : super(notifier: controller);

  static VoiceRecorderController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<VoiceRecorderScope>();
    assert(scope != null, 'VoiceRecorderScope not found in context');
    return scope!.notifier!;
  }

  static VoiceRecorderController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<VoiceRecorderScope>()
        ?.notifier;
  }
}

/// Mic trigger — icon in chat composer or full-width card in forms.
class VoiceRecorderTrigger extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final bool fullWidth;

  const VoiceRecorderTrigger({
    super.key,
    this.padding,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = VoiceRecorderScope.of(context);

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        if (ctrl.isActive) return const SizedBox.shrink();

        return Obx(() {
          final busy = Get.find<HomeController>().isUploading.value ||
              Get.find<HomeController>().isChatUploadActiveFor(ctrl.scopeId);

          if (fullWidth) {
            return _FormTrigger(
              busy: busy,
              onTap: busy ? null : ctrl.startRecording,
            );
          }

          return IconButton(
            padding: padding ?? EdgeInsets.zero,
            tooltip: AppLocaleKeys.chatAttachVoice.tr,
            icon: const Icon(Icons.mic_none),
            onPressed: busy ? null : ctrl.startRecording,
          );
        });
      },
    );
  }
}

class _FormTrigger extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;

  const _FormTrigger({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.mic, color: context.appTheme.accentText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'tasks.form.voice_record_start'.tr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay strip above composer / form — delete, pause, save while recording.
class VoiceRecorderActiveStrip extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const VoiceRecorderActiveStrip({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(8, 0, 8, 6),
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = VoiceRecorderScope.of(context);

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        if (!ctrl.isActive) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final recording = ctrl.phase == VoiceRecorderPhase.recording;
        final paused = ctrl.phase == VoiceRecorderPhase.paused;
        final uploading = ctrl.phase == VoiceRecorderPhase.uploading;

        return Padding(
          padding: padding,
          child: Material(
            color: recording ? Colors.red.shade50 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: recording
                          ? Colors.red
                          : paused
                              ? Colors.orange
                              : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (uploading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      ctrl.formatDuration(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uploading
                          ? AppLocaleKeys.chatVoiceUploading.tr
                          : recording
                              ? AppLocaleKeys.chatAttachVoice.tr
                              : AppLocaleKeys.chatVoicePaused.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTheme.mutedText,
                      ),
                    ),
                  ),
                  if (!uploading) ...[
                    IconButton(
                      tooltip: AppLocaleKeys.chatVoiceDiscard.tr,
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                        size: 22,
                      ),
                      onPressed: ctrl.discardRecording,
                    ),
                    IconButton(
                      tooltip: paused
                          ? AppLocaleKeys.chatVoiceResume.tr
                          : AppLocaleKeys.chatVoicePause.tr,
                      icon: Icon(
                        paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: context.appTheme.accentText,
                        size: 24,
                      ),
                      onPressed: paused
                          ? ctrl.resumeRecording
                          : ctrl.pauseRecording,
                    ),
                    IconButton(
                      tooltip: 'common.save'.tr,
                      icon: Icon(
                        Icons.check_circle,
                        color: context.appTheme.accentText,
                        size: 24,
                      ),
                      onPressed: ctrl.saveRecording,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Saved voice preview with full playback — chat pending strip and forms.
class VoiceRecorderSavedPreview extends StatelessWidget {
  final String voiceUrl;
  final int durationSec;
  final VoidCallback onClear;
  final EdgeInsetsGeometry padding;
  final String? captionHint;

  const VoiceRecorderSavedPreview({
    super.key,
    required this.voiceUrl,
    required this.durationSec,
    required this.onClear,
    this.padding = EdgeInsets.zero,
    this.captionHint,
  });

  @override
  Widget build(BuildContext context) {
    final url = voiceUrl.trim();
    if (url.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Material(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocaleKeys.chatAttachVoice.tr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocaleKeys.chatVoiceDiscard.tr,
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: onClear,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: VoiceMessageRow(
                url: url,
                durationSec: durationSec > 0 ? durationSec : null,
                isMe: false,
                compact: false,
              ),
            ),
            if (captionHint != null && captionHint!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  captionHint!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appTheme.mutedText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
