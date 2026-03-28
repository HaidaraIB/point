import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:point/Controller/HomeController.dart';
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
  DateTime? _started;

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

  Future<void> _toggleNative() async {
    if (!_recording) {
      if (!await _recorder.hasPermission()) return;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _recording = true;
        _started = DateTime.now();
      });
    } else {
      final path = await _recorder.stop();
      final started = _started;
      setState(() {
        _recording = false;
        _started = null;
      });
      if (path == null || started == null) return;
      final sec = DateTime.now().difference(started).inSeconds;
      final bytes = await File(path).readAsBytes();
      final c = Get.find<HomeController>();
      final url = await c.uploadFiles(
        filePathOrBytes: bytes,
        fileName: 'voice.m4a',
      );
      if (url != null) {
        await widget.onUploaded(url, sec.clamp(1, 3600));
      }
    }
  }

  Future<void> _onPressed() async {
    if (kIsWeb) {
      await _pickAudioFileWebOrFallback();
      return;
    }
    await _toggleNative();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _recording ? Icons.stop_circle : Icons.mic_none,
        color: _recording ? Colors.red : null,
      ),
      onPressed: _onPressed,
    );
  }
}
