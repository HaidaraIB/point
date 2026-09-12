import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:web/web.dart' as web;

/// Web: live webcam preview + capture (getUserMedia).
Future<Uint8List?> captureOsExpenseCamera(BuildContext context) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WebCameraDialog(),
  );
}

class _WebCameraDialog extends StatefulWidget {
  const _WebCameraDialog();

  @override
  State<_WebCameraDialog> createState() => _WebCameraDialogState();
}

class _WebCameraDialogState extends State<_WebCameraDialog> {
  late final String _viewType;
  web.HTMLVideoElement? _video;
  web.MediaStream? _stream;
  String? _error;
  var _ready = false;
  var _capturing = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'os-expense-cam-${DateTime.now().microsecondsSinceEpoch}';
    _start();
  }

  Future<void> _start() async {
    try {
      final video = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.borderRadius = '12px';

      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(video: true.toJS, audio: false.toJS),
          )
          .toDart;

      video.srcObject = stream;
      await video.play().toDart;

      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int id) => video,
      );

      if (!mounted) {
        _stopTracks(stream);
        return;
      }
      setState(() {
        _video = video;
        _stream = stream;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocaleKeys.osExpensesCameraUnavailable.tr;
      });
    }
  }

  void _stopTracks(web.MediaStream? stream) {
    if (stream == null) return;
    final tracks = stream.getTracks().toDart;
    for (final t in tracks) {
      t.stop();
    }
  }

  Future<void> _capture() async {
    final video = _video;
    if (video == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final w = video.videoWidth;
      final h = video.videoHeight;
      if (w == 0 || h == 0) return;

      final canvas = web.HTMLCanvasElement()
        ..width = w
        ..height = h;
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.drawImage(video, 0, 0);
      final dataUrl = canvas.toDataURL('image/jpeg', 0.85.toJS);
      final comma = dataUrl.indexOf(',');
      if (comma < 0) return;
      final bytes = base64Decode(dataUrl.substring(comma + 1));
      if (!mounted) return;
      _stopTracks(_stream);
      Navigator.pop(context, Uint8List.fromList(bytes));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _stopTracks(_stream);
    _video?.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocaleKeys.osExpensesCameraCapture.tr),
      content: SizedBox(
        width: 420,
        height: 320,
        child: _error != null
            ? Center(child: Text(_error!, textAlign: TextAlign.center))
            : !_ready
                ? const Center(child: CircularProgressIndicator())
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: HtmlElementView(viewType: _viewType),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _stopTracks(_stream);
            Navigator.pop(context);
          },
          child: Text(AppLocaleKeys.osCommonCancel.tr),
        ),
        if (_error == null)
          FilledButton.icon(
            onPressed: _ready && !_capturing ? _capture : null,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: Text(AppLocaleKeys.osExpensesCameraSnap.tr),
          ),
      ],
    );
  }
}
