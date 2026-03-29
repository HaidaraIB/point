import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:record/record.dart';

/// تسجيل صوتي على الهاتف/سطح المكتب؛ على الويب يُفتح منتقي ملفات صوتية.
class ChatVoiceRecordButton extends StatefulWidget {
  final Future<void> Function(String url, int durationSec) onUploaded;

  const ChatVoiceRecordButton({super.key, required this.onUploaded});

  @override
  State<ChatVoiceRecordButton> createState() => _ChatVoiceRecordButtonState();
}

class _ChatVoiceRecordButtonState extends State<ChatVoiceRecordButton> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  bool _finishing = false;
  final Stopwatch _activeSw = Stopwatch();
  Timer? _uiTimer;
  String? _recordPath;

  void _startUiTimer() {
    _uiTimer?.cancel();
    // تحديث متكرر حتى تتحرك الثواني على الشاشة بسلاسة (وليس مرة كل ثانية فقط).
    _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = null;
  }

  /// دقائق:ثوانٍ — الثواني دائماً بخانتين (0:00 … 59:59).
  String _formatDuration() {
    final d = _activeSw.elapsed;
    final totalSec = d.inSeconds;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _pickAudioFileWebOrFallback() async {
    final r = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'webm'],
    );
    if (r == null || r.files.isEmpty || r.files.first.bytes == null) return;
    final f = r.files.first;
    final c = Get.find<HomeController>();
    final url = await c.uploadFiles(
      filePathOrBytes: f.bytes!,
      fileName: f.name,
    );
    if (url != null) {
      await widget.onUploaded(url, 0);
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    _recordPath =
        '${dir.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordPath!,
    );
    _activeSw.reset();
    _activeSw.start();
    _startUiTimer();
    if (mounted) {
      setState(() => _recording = true);
    }
  }

  /// بعد [stop] قد يتأخر ظهور الملف على القرص (خصوصاً Android). نمنع القراءة المزدوجة لـ [stop].
  Future<Uint8List?> _readRecordingBytes(
    String? pathFromStop,
    String? savedPath,
  ) async {
    final tried = <String>{};
    final candidates = <String>[];
    for (final p in [pathFromStop, savedPath]) {
      if (p != null && p.isNotEmpty && !tried.contains(p)) {
        tried.add(p);
        candidates.add(p);
      }
    }
    for (final p in candidates) {
      final f = File(p);
      for (var attempt = 0; attempt < 40; attempt++) {
        try {
          if (await f.exists()) {
            final len = await f.length();
            if (len > 0) {
              return await f.readAsBytes();
            }
          }
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    return null;
  }

  Future<void> _deleteRecording() async {
    if (!_recording || _finishing) return;
    try {
      await _recorder.cancel();
    } catch (_) {
      try {
        final path = await _recorder.stop();
        if (path != null) {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
      } catch (_) {}
    }
    _stopUiTimer();
    _activeSw.stop();
    _activeSw.reset();
    _recordPath = null;
    if (mounted) {
      setState(() => _recording = false);
    }
  }

  Future<void> _finishAndUpload() async {
    if (!_recording || _finishing) return;
    _finishing = true;
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

    Uint8List? bytes;
    try {
      bytes = await _readRecordingBytes(pathFromStop, savedPath);
    } finally {
      _finishing = false;
      _recordPath = null;
      if (mounted) {
        setState(() => _recording = false);
      }
    }

    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        Get.snackbar(
          AppLocaleKeys.errorTitle.tr,
          AppLocaleKeys.chatVoiceSaveFailed.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return;
    }

    final c = Get.find<HomeController>();
    final url = await c.uploadFiles(
      filePathOrBytes: bytes,
      fileName: 'voice.m4a',
    );
    if (url != null) {
      await widget.onUploaded(url, sec);
    }
  }

  Future<void> _onMicPressed() async {
    if (kIsWeb) {
      await _pickAudioFileWebOrFallback();
      return;
    }
    await _startRecording();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    if (_recording) {
      unawaited(_recorder.cancel());
    }
    unawaited(_recorder.dispose());
    super.dispose();
  }

  static ButtonStyle _compactIconButton(BuildContext context) {
    return IconButton.styleFrom(
      padding: const EdgeInsets.all(8),
      minimumSize: const Size(40, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return IconButton(
        style: _compactIconButton(context),
        icon: const Icon(Icons.audio_file_outlined),
        tooltip: AppLocaleKeys.chatAttachVoice.tr,
        onPressed: _onMicPressed,
      );
    }

    if (!_recording) {
      return IconButton(
        style: _compactIconButton(context),
        icon: const Icon(Icons.mic_none),
        tooltip: AppLocaleKeys.chatAttachVoice.tr,
        onPressed: _onMicPressed,
      );
    }

    final theme = Theme.of(context);
    // يتبع لون الأيقونات (مثلاً الأبيض في ورقة الصوت الداكنة) وإلا لون النص السطحي.
    final timerColor =
        IconTheme.of(context).color ?? theme.colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              _formatDuration(),
              style: theme.textTheme.labelLarge?.copyWith(
                fontFeatures: const [
                  FontFeature.tabularFigures(),
                ],
                fontWeight: FontWeight.w600,
                color: timerColor,
              ),
            ),
          ),
          IconButton(
            style: _compactIconButton(context),
            tooltip: 'chat.voice_discard'.tr,
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            onPressed: _deleteRecording,
          ),
          IconButton(
            style: _compactIconButton(context),
            tooltip: 'chat.send_action'.tr,
            icon: const Icon(Icons.send_rounded, color: Color(0xff00A389)),
            onPressed: _finishAndUpload,
          ),
        ],
      ),
    );
  }
}
